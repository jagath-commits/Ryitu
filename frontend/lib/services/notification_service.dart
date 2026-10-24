import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/community_page.dart';
import 'package:dmk_project/notification_post_page.dart';
import 'package:dmk_project/services/notification_badge_manager.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  debugPrint("Handling background FCM message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String channelId = 'ritpen_notifications';
  static const String channelName = 'Ritpen Notifications';
  static const String channelDescription =
      'Notifications for stories, comments, and updates';

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    if (navigatorKey != null) {
      _navigatorKey = navigatorKey;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request notification permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('User notification permission status: ${settings.authorizationStatus}');

      // Set foreground notification presentation options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Create Android Notification Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Initialize local notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data = jsonDecode(response.payload!);
              if (data is Map<String, dynamic>) {
                _navigateToTarget(data);
              }
            } catch (e) {
              debugPrint('Error parsing notification payload: $e');
            }
          }
        },
      );

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message received: ${message.data}');
        NotificationBadgeManager.instance.notifyNewNotificationReceived();
        final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: android?.smallIcon ?? '@drawable/ic_notification',
                color: const Color(0xFF0729E8),
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: jsonEncode(message.data),
          );
        }
      });

      // App opened from background via notification click
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM App opened from background: ${message.data}');
        _navigateToTarget(message.data);
      });

      // App opened from terminated state via notification click
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM App opened from terminated state: ${initialMessage.data}');
        _navigateToTarget(initialMessage.data);
      }

      // Sync FCM token
      await syncFcmToken();

      // Listen for token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _sendTokenToServer(newToken);
      });
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  }

  Future<String?> getFcmToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> syncFcmToken([String? explicitUserId]) async {
    try {
      final token = await getFcmToken();
      if (token == null || token.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);

      final userId = explicitUserId ?? prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        await _sendTokenToServer(token, userId);
      }
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }

  Future<void> _sendTokenToServer(String token, [String? userId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetUserId = userId ?? prefs.getString('user_id');
      if (targetUserId == null || targetUserId.isEmpty) return;

      final authToken = prefs.getString('token') ?? '';
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/auth/save-fcm-token');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'user_id': targetUserId,
          'fcm_token': token,
        }),
      );

      debugPrint('FCM Token save status: ${response.statusCode}');
    } catch (e) {
      debugPrint('Failed to send FCM token to backend: $e');
    }
  }

  void _navigateToTarget(Map<String, dynamic> data) {
    final postId = (data['postId'] ?? data['post_id'] ?? data['id'])?.toString();
    final communityId = (data['communityId'] ?? data['community_id'])?.toString();

    if (postId != null && postId.isNotEmpty) {
      _navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (_) => NotificationPostPage(postId: postId),
        ),
      );
    } else if (communityId != null && communityId.isNotEmpty) {
      _navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CommunityPage(communityId: communityId),
        ),
      );
    }
  }
}

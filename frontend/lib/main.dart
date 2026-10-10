import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_links/app_links.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/home.dart';
import 'package:dmk_project/password_login.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dmk_project/notification_post_page.dart';
import 'package:dmk_project/community_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  const initSettings = InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  runApp(MyApp(token: token));
}

class MyApp extends StatefulWidget {
  final String? token;

  const MyApp({super.key, required this.token});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();

    FirebaseMessaging.instance.getToken().then((token) {
      print("FCM TOKEN: $token");
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      print("FULL DATA = ${message.data}");
      final postId = message.data['postId'];
      print("POST ID = $postId");

      if (postId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => NotificationPostPage(postId: postId),
          ),
        );
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final postId = message.data['postId'];

        if (postId != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => NotificationPostPage(postId: postId),
            ),
          );
        }
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Notification Received");

      flutterLocalNotificationsPlugin.show(
        0,
        message.notification?.title ?? '',
        message.notification?.body ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'Default Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _initDeepLinks());
  }

  Future<void> _initDeepLinks() async {
    try {
      _appLinks = AppLinks();
      final initialUri = await _appLinks!.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }

      _sub = _appLinks!.uriLinkStream.listen((uri) {
        _handleDeepLink(uri);
      });
    } catch (e) {
      debugPrint('Deep links skipped: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('🔗 Processing deep link: $uri');
    final String scheme = uri.scheme.toLowerCase();
    final String host = uri.host.toLowerCase();
    final List<String> segments = uri.pathSegments;

    String? targetType;
    String? targetId;

    if (scheme == 'ryitu') {
      if (host == 'community' || segments.contains('community')) {
        targetType = 'community';
        if (segments.isNotEmpty && segments.last != 'community') {
          targetId = segments.last;
        } else if (host != 'community' && host.isNotEmpty) {
          targetId = host;
        } else if (uri.path.isNotEmpty) {
          targetId = uri.path.replaceAll('/', '');
        }
      } else if (host == 'post' || segments.contains('post')) {
        targetType = 'post';
        if (segments.isNotEmpty && segments.last != 'post') {
          targetId = segments.last;
        } else if (host != 'post' && host.isNotEmpty) {
          targetId = host;
        } else if (uri.path.isNotEmpty) {
          targetId = uri.path.replaceAll('/', '');
        }
      }
    } else {
      // HTTP / HTTPS (e.g. /share/community/:id or /share/post/:id)
      if (segments.contains('community')) {
        targetType = 'community';
        final idx = segments.indexOf('community');
        if (idx + 1 < segments.length) {
          targetId = segments[idx + 1];
        }
      } else if (segments.contains('post')) {
        targetType = 'post';
        final idx = segments.indexOf('post');
        if (idx + 1 < segments.length) {
          targetId = segments[idx + 1];
        }
      }
    }

    if (targetType == null || targetId == null || targetId.isEmpty) return;

    if (targetType == 'community') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CommunityPage(communityId: targetId!),
        ),
      );
    } else if (targetType == 'post') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => NotificationPostPage(postId: targetId!),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.token != null
        ? const MainShell()
        : const PasswordLoginPage();

    if (Platform.isIOS) {
      return CupertinoApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        home: home,
      );
    }

    return MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}

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

  // Prevent silent blank screen in release APK by capturing framework errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter framework error: ${details.exceptionAsString()}');
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      // Edge-to-edge: nav bar is transparent, app draws behind it
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Edge-to-edge mode: app draws behind system nav bar, nav buttons hidden/gesture-only
  // SafeArea in each screen handles keeping content above the gesture area
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Safely retrieve cached token
  String? token;
  try {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
  } catch (e) {
    debugPrint('SharedPreferences init error: $e');
  }

  // 🚀 CRITICAL FIX: Run app IMMEDIATELY so UI mounts without waiting for native/permission delays!
  runApp(MyApp(token: token));

  // 🚀 Initialize Firebase & notification services asynchronously in background
  _initServicesAsync();
}

Future<void> _initServicesAsync() async {
  try {
    await Firebase.initializeApp();
    debugPrint("Firebase initialized successfully");

    // Local notifications initialization
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
      const initSettings = InitializationSettings(android: androidSettings);
      await flutterLocalNotificationsPlugin.initialize(initSettings);
    } catch (e) {
      debugPrint("Local notifications init skipped: $e");
    }

    // Notification permission request (safe and non-blocking after UI is rendered)
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint("FCM requestPermission skipped: $e");
    }
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
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

    _setupFirebaseMessaging();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initDeepLinks());
  }

  void _setupFirebaseMessaging() {
    try {
      FirebaseMessaging.instance.getToken().then((token) {
        debugPrint("FCM TOKEN: $token");
      }).catchError((e) {
        debugPrint("FCM getToken error: $e");
      });
    } catch (e) {
      debugPrint("FCM token exception: $e");
    }

    try {
      FirebaseMessaging.onMessageOpenedApp.listen((message) async {
        debugPrint("FULL DATA = ${message.data}");
        final postId = message.data['postId'];
        debugPrint("POST ID = $postId");

        if (postId != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => NotificationPostPage(postId: postId),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint("onMessageOpenedApp error: $e");
    }

    try {
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
      }).catchError((e) {
        debugPrint("getInitialMessage error: $e");
      });
    } catch (e) {
      debugPrint("getInitialMessage exception: $e");
    }

    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("Notification Received");

        try {
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
        } catch (e) {
          debugPrint("Error showing local notification: $e");
        }
      });
    } catch (e) {
      debugPrint("onMessage error: $e");
    }
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
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Material(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.brand, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to display content',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        };
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}

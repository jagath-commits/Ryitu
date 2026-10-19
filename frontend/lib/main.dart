import 'dart:async';
import 'dart:io' show Platform;
import 'package:app_links/app_links.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/home.dart';
import 'package:dmk_project/password_login.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dmk_project/notification_post_page.dart';
import 'package:dmk_project/community_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

    if (scheme == 'Ritpen') {
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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dmk_project/api_config.dart';

/// Real-time In-App Notification & Unread Badge Manager
/// Handles automatic periodic background polling, lifecycle observation (app resume),
/// foreground FCM event triggers, and instantaneous badge synchronization across the app.
class NotificationBadgeManager with WidgetsBindingObserver {
  static final NotificationBadgeManager instance = NotificationBadgeManager._();
  NotificationBadgeManager._();

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> refreshTick = ValueNotifier<int>(0);

  Timer? _pollTimer;
  String? _userId;
  String? _authToken;
  bool _isInitialized = false;
  bool _isFetching = false;

  void init({String? userId, String? authToken}) {
    if (userId != null && userId.isNotEmpty) {
      _userId = userId;
    }
    if (authToken != null && authToken.isNotEmpty) {
      _authToken = authToken;
    }

    if (!_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addObserver(this);
    }

    startPolling();
    refreshUnreadCount();
  }

  void updateCredentials({String? userId, String? authToken}) {
    if (userId != null && userId.isNotEmpty) {
      _userId = userId;
    }
    if (authToken != null && authToken.isNotEmpty) {
      _authToken = authToken;
    }
    refreshUnreadCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User returned to app: immediately re-sync unread notifications
      debugPrint('[NotificationBadgeManager] App resumed -> syncing notifications');
      refreshUnreadCount();
      triggerRefresh();
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 10)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      refreshUnreadCount();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refreshUnreadCount() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      if (_userId == null || _userId!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _userId = prefs.getString('user_id');
        _authToken ??= prefs.getString('token');
      }

      final effectiveUid = _userId ?? 'USR00000001';
      final uri = Uri.parse(
          '${ApiConfig.apiBaseUrl}/notifications/unread-count?userId=$effectiveUid');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken!.isNotEmpty)
          'Authorization': 'Bearer $_authToken',
      };

      final res = await http.get(uri, headers: headers).timeout(
            const Duration(seconds: 6),
            onTimeout: () => http.Response('{}', 408),
          );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final count = (decoded['data']['unreadCount'] as num?)?.toInt() ?? 0;
          if (unreadCountNotifier.value != count) {
            unreadCountNotifier.value = count;
          }
        }
      }
    } catch (e) {
      // Silent error: do not disrupt UI
    } finally {
      _isFetching = false;
    }
  }

  /// Triggered when an FCM notification arrives in foreground or user performs an action
  void notifyNewNotificationReceived() {
    refreshUnreadCount();
    triggerRefresh();
  }

  /// Signals notifications page to refresh without full screen re-load
  void triggerRefresh() {
    refreshTick.value++;
  }

  void setUnreadCount(int count) {
    unreadCountNotifier.value = count < 0 ? 0 : count;
  }

  void decrementUnreadCount([int amount = 1]) {
    final newCount = unreadCountNotifier.value - amount;
    unreadCountNotifier.value = newCount < 0 ? 0 : newCount;
  }

  void markAllRead() {
    unreadCountNotifier.value = 0;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopPolling();
    _isInitialized = false;
  }
}

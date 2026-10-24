import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:dmk_project/api_config.dart';

/// Central reactive manager for post likes across HomePage, CommunityPage, and ProfilePage.
/// Exactly mimics SavedPostsManager to guarantee instant reactive cross-page synchronization.
class LikedPostsManager extends ChangeNotifier {
  static final LikedPostsManager instance = LikedPostsManager._internal();
  LikedPostsManager._internal();

  final Set<String> _likedPostIds = {};
  final Map<String, int> _supportCounts = {};
  final Set<String> _deletedPostIds = {};
  bool _initialized = false;

  Set<String> get likedPostIds => _likedPostIds;
  Set<String> get deletedPostIds => _deletedPostIds;

  bool isLiked(String postId) {
    if (postId.isEmpty) return false;
    return _likedPostIds.contains(postId);
  }

  int? getSupportCount(String postId) {
    if (postId.isEmpty) return null;
    return _supportCounts[postId];
  }

  void syncPost(String postId, {bool? isLiked, int? supportCount}) {
    if (postId.isEmpty) return;
    bool changed = false;
    if (isLiked != null) {
      if (isLiked && !_likedPostIds.contains(postId)) {
        _likedPostIds.add(postId);
        changed = true;
      } else if (!isLiked && _likedPostIds.contains(postId)) {
        _likedPostIds.remove(postId);
        changed = true;
      }
    }
    if (supportCount != null && _supportCounts[postId] != supportCount) {
      _supportCounts[postId] = supportCount;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void notifyPostDeleted(String postId) {
    if (postId.isEmpty) return;
    _deletedPostIds.add(postId);
    _likedPostIds.remove(postId);
    _supportCounts.remove(postId);
    notifyListeners();
  }

  Future<void> init(String? userId) async {
    if (!_initialized) {
      _initialized = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('cached_liked_posts') ?? [];
        _likedPostIds.addAll(cached);
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cached_liked_posts', _likedPostIds.toList());
    } catch (_) {}
  }

  Future<bool> toggleLike({
    required String postId,
    required String userId,
    String? token,
    int? currentCount,
  }) async {
    if (postId.isEmpty || postId == 'null') return false;

    final wasLiked = _likedPostIds.contains(postId);
    final nowLiked = !wasLiked;

    // 1. INSTANT LOCAL REACTIVE UPDATE (0ms) across all listening pages
    if (nowLiked) {
      _likedPostIds.add(postId);
      if (currentCount != null) {
        _supportCounts[postId] = currentCount + 1;
      }
    } else {
      _likedPostIds.remove(postId);
      if (currentCount != null) {
        _supportCounts[postId] = (currentCount - 1).clamp(0, 999999);
      }
    }

    notifyListeners();
    _persist();

    // 2. BACKGROUND SERVER SYNC
    try {
      final effectiveToken = token ?? "";
      final response = await http.post(
        Uri.parse("${ApiConfig.apiBaseUrl}/posts/toggleSupport/$postId"),
        headers: {
          if (effectiveToken.isNotEmpty) "Authorization": "Bearer $effectiveToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"userId": userId}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is Map) {
          final serverCount = int.tryParse(decoded['data']['support_count']?.toString() ?? '');
          final serverSupported = decoded['data']['isSupported'] == true;

          if (serverSupported) {
            _likedPostIds.add(postId);
          } else {
            _likedPostIds.remove(postId);
          }
          if (serverCount != null) {
            _supportCounts[postId] = serverCount;
          }

          notifyListeners();
          _persist();
          return serverSupported;
        }
      } else {
        // Revert on error
        if (wasLiked) {
          _likedPostIds.add(postId);
        } else {
          _likedPostIds.remove(postId);
        }
        if (currentCount != null) {
          _supportCounts[postId] = currentCount;
        }
        notifyListeners();
        _persist();
      }
    } catch (_) {
      // Revert on failure
      if (wasLiked) {
        _likedPostIds.add(postId);
      } else {
        _likedPostIds.remove(postId);
      }
      if (currentCount != null) {
        _supportCounts[postId] = currentCount;
      }
      notifyListeners();
      _persist();
    }

    return nowLiked;
  }
}

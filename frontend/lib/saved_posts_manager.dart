import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:dmk_project/api_config.dart';

class SavedPostsManager extends ChangeNotifier {
  static final SavedPostsManager instance = SavedPostsManager._internal();
  SavedPostsManager._internal();

  final Set<String> _savedPostIds = {};
  final List<Map<String, dynamic>> _savedPosts = [];
  bool _initialized = false;

  Set<String> get savedPostIds => _savedPostIds;
  List<Map<String, dynamic>> get savedPosts => List.unmodifiable(_savedPosts);

  bool isSaved(String postId) {
    if (postId.isEmpty) return false;
    return _savedPostIds.contains(postId);
  }

  void notifyPostDeleted(String postId) {
    if (postId.isEmpty) return;
    _savedPostIds.remove(postId);
    _savedPosts.removeWhere(
      (p) => (p['post_id'] ?? p['_id'])?.toString() == postId,
    );
    notifyListeners();
    _persist();
  }

  Future<void> init(String? userId) async {
    if (!_initialized) {
      _initialized = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getStringList('cached_saved_posts') ?? [];
        _savedPostIds.addAll(cached);
      } catch (_) {}
      notifyListeners();
    }
    if (userId != null && userId.isNotEmpty) {
      await fetchSavedPosts(userId);
    }
  }

  Future<void> fetchSavedPosts(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await http.get(
        Uri.parse('${ApiConfig.apiBaseUrl}/posts/savedposts/$userId'),
        headers: {if (token.isNotEmpty) "Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List? list;
        if (decoded is Map && decoded['data'] is List) {
          list = decoded['data'];
        } else if (decoded is List) {
          list = decoded;
        }
        if (list != null) {
          _savedPosts.clear();
          for (var item in list) {
            final m = Map<String, dynamic>.from(item as Map);
            m['isSaved'] = true;
            _savedPosts.add(m);
            final pid = m['post_id']?.toString();
            if (pid != null && pid.isNotEmpty) {
              _savedPostIds.add(pid);
            }
            final mid = m['_id']?.toString();
            if (mid != null && mid.isNotEmpty) {
              _savedPostIds.add(mid);
            }
          }
          await _persist();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<bool> toggleSave({
    required String postId,
    required String userId,
    String? token,
    Map<String, dynamic>? postData,
  }) async {
    if (postId.isEmpty || postId == 'null') return false;

    final altId = (postData?['post_id'] ?? postData?['_id'])?.toString();
    final wasSaved = _savedPostIds.contains(postId) ||
        (altId != null && altId.isNotEmpty && _savedPostIds.contains(altId));
    final nowSaved = !wasSaved;

    // 1. INSTANT LOCAL REACTIVE UPDATE (0ms)
    if (nowSaved) {
      _savedPostIds.add(postId);
      if (altId != null && altId.isNotEmpty) {
        _savedPostIds.add(altId);
      }
      if (postData != null) {
        final existingIdx = _savedPosts.indexWhere(
          (p) =>
              (p['post_id'] ?? p['_id'])?.toString() == postId ||
              (altId != null &&
                  (p['post_id'] ?? p['_id'])?.toString() == altId),
        );
        if (existingIdx == -1) {
          final copy = Map<String, dynamic>.from(postData);
          copy['isSaved'] = true;
          _savedPosts.insert(0, copy);
        }
      }
    } else {
      _savedPostIds.remove(postId);
      if (altId != null) _savedPostIds.remove(altId);
      _savedPosts.removeWhere(
        (p) =>
            (p['post_id'] ?? p['_id'])?.toString() == postId ||
            (altId != null && (p['post_id'] ?? p['_id'])?.toString() == altId),
      );
    }

    notifyListeners();
    _persist();

    // 2. BACKGROUND SERVER SYNC
    try {
      final effectiveToken = token ?? "";
      final response = await http.post(
        Uri.parse("${ApiConfig.apiBaseUrl}/posts/toggleSave/$postId"),
        headers: {
          if (effectiveToken.isNotEmpty) "Authorization": "Bearer $effectiveToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"userId": userId}),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        bool? serverSaved;
        if (decoded is Map) {
          if (decoded['isSaved'] != null) {
            serverSaved = decoded['isSaved'] == true;
          } else if (decoded['data'] is Map && decoded['data']['isSaved'] != null) {
            serverSaved = decoded['data']['isSaved'] == true;
          }
        }
        if (serverSaved != null && serverSaved != nowSaved) {
          if (serverSaved) {
            _savedPostIds.add(postId);
            if (altId != null && altId.isNotEmpty) _savedPostIds.add(altId);
          } else {
            _savedPostIds.remove(postId);
            if (altId != null) _savedPostIds.remove(altId);
            _savedPosts.removeWhere(
              (p) =>
                  (p['post_id'] ?? p['_id'])?.toString() == postId ||
                  (altId != null &&
                      (p['post_id'] ?? p['_id'])?.toString() == altId),
            );
          }
          notifyListeners();
          _persist();
          return serverSaved;
        }
        return nowSaved;
      } else {
        _revert(postId, wasSaved, postData);
      }
    } catch (_) {
      _revert(postId, wasSaved, postData);
    }
    return wasSaved;
  }

  void _revert(String postId, bool wasSaved, Map<String, dynamic>? postData) {
    final altId = (postData?['post_id'] ?? postData?['_id'])?.toString();
    if (wasSaved) {
      _savedPostIds.add(postId);
      if (altId != null && altId.isNotEmpty) _savedPostIds.add(altId);
      if (postData != null) {
        final existingIdx = _savedPosts.indexWhere(
          (p) =>
              (p['post_id'] ?? p['_id'])?.toString() == postId ||
              (altId != null &&
                  (p['post_id'] ?? p['_id'])?.toString() == altId),
        );
        if (existingIdx == -1) {
          _savedPosts.insert(0, Map<String, dynamic>.from(postData));
        }
      }
    } else {
      _savedPostIds.remove(postId);
      if (altId != null) _savedPostIds.remove(altId);
      _savedPosts.removeWhere(
        (p) =>
            (p['post_id'] ?? p['_id'])?.toString() == postId ||
            (altId != null && (p['post_id'] ?? p['_id'])?.toString() == altId),
      );
    }
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cached_saved_posts', _savedPostIds.toList());
    } catch (_) {}
  }
}

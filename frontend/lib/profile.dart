import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/home.dart';
import 'package:dmk_project/saved_posts_manager.dart';
import 'package:dmk_project/password_login.dart';
import 'package:dmk_project/profile1.dart';
import 'package:dmk_project/write.dart' deferred as write;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  final bool isPublicView;
  final String? initialPostId;

  const ProfilePage({
    super.key,
    required this.userId,
    this.isPublicView = false,
    this.initialPostId,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  static final _baseUrl = ApiConfig.apiBaseUrl;

  late TabController _tabController;

  String _username = '';
  String? _profileImageUrl;
  String? _profileImagePath;
  bool _avatarError = false;

  List<Map<String, dynamic>> _myPosts = [];
  List<Map<String, dynamic>> _drafts = [];
  List<Map<String, dynamic>> get _savedPosts => SavedPostsManager.instance.savedPosts;

  Set<String> _likedPosts = {};

  bool _loadingProfile = true;
  bool _loadingPosts = true;
  bool _loadingDrafts = true;
  bool _loadingSaved = false;

  @override
  void initState() {
    super.initState();
    SavedPostsManager.instance.addListener(_onSavedChanged);
    SavedPostsManager.instance.init(widget.userId);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadAll();
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SavedPostsManager.instance.removeListener(_onSavedChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProfile(),
      _loadInteractions(),
      _fetchMyPosts(),
      _fetchDrafts(),
      _fetchSavedPosts(),
    ]);
  }

  Future<void> _loadInteractions() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _likedPosts = (prefs.getStringList('cached_liked_posts') ?? []).toSet();
    });
  }

  Future<void> _saveInteractionsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cached_liked_posts', _likedPosts.toList());
  }

  String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    path = path.trim();
    if (path.startsWith('http')) {
      return path;
    }
    path = path.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    path = path
        .replaceAll('Uploads', 'uploads')
        .replaceAll('Profile_images', 'profile_images');
    if (!path.contains('/')) {
      if (path.contains('cover')) {
        path = 'uploads/covers/$path';
      } else {
        path = 'uploads/profile_images/$path';
      }
    } else if (!path.startsWith('uploads/')) {
      if (path.startsWith('covers/')) {
        path = 'uploads/$path';
      } else if (path.startsWith('profile_images/')) {
        path = 'uploads/$path';
      }
    }
    return '${ApiConfig.baseUrl}/$path';
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _avatarError = false;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";

    final localUser = prefs.getString('username') ?? '';
    if (localUser.isNotEmpty &&
        localUser != widget.userId &&
        !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(localUser)) {
      _username = localUser;
    }
    _profileImageUrl = prefs.getString('profile_image_url');
    _profileImagePath = prefs.getString('profile_image_path');

    final targetId = widget.userId.isNotEmpty
        ? widget.userId
        : (prefs.getString("user_id") ?? "");

    if (targetId.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/profile/profile/$targetId'),
          headers: {"Authorization": "Bearer $token"},
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final data = decoded is Map && decoded['data'] is Map
              ? decoded['data'] as Map
              : decoded;
          if (data is Map) {
            final fetched = (data['username'] ?? data['Username'] ?? data['name'])?.toString().trim() ?? '';
            if (fetched.isNotEmpty &&
                fetched != targetId &&
                !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(fetched)) {
              _username = fetched;
              await prefs.setString('username', _username);
            }
            final image =
                (data['profile_image'] ??
                        data['ProfileImage'] ??
                        data['profileImage'])
                    ?.toString();
            if (image != null && image.isNotEmpty) {
              _profileImageUrl = _fullUrl(image);
              _profileImagePath = null;
              await prefs.setString('profile_image_url', _profileImageUrl!);
            }
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _loadingProfile = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchList(String endpoint) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetId = widget.userId.isNotEmpty
          ? widget.userId
          : (prefs.getString("user_id") ?? "");
      if (targetId.isEmpty) return [];
      final token = prefs.getString("token") ?? "";
      final response = await http.get(
        Uri.parse('$_baseUrl/posts/$endpoint/$targetId'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List) {
        return List<Map<String, dynamic>>.from(
          (decoded['data'] as List).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
      }
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (_) {}
    return [];
  }

  Future<void> _fetchMyPosts() async {
    setState(() => _loadingPosts = true);
    final posts = await _fetchList('userposts');
    if (mounted) {
      setState(() {
        _myPosts = posts;
        _loadingPosts = false;
      });
    }
  }

  Future<void> _fetchDrafts() async {
    setState(() => _loadingDrafts = true);
    var drafts = await _fetchList('getdraftposts');
    if (drafts.isEmpty) {
      drafts = await _fetchList('draftposts');
    }
    if (mounted) {
      setState(() {
        _drafts = drafts;
        _loadingDrafts = false;
      });
    }
  }

  Future<void> _fetchSavedPosts() async {
    final targetId = widget.userId.isNotEmpty
        ? widget.userId
        : ((await SharedPreferences.getInstance()).getString("user_id") ?? "");
    if (targetId.isNotEmpty) {
      if (_savedPosts.isEmpty) setState(() => _loadingSaved = true);
      await SavedPostsManager.instance.fetchSavedPosts(targetId);
      if (mounted) {
        setState(() => _loadingSaved = false);
      }
    }
  }

  ImageProvider? _avatarProvider() {
    if (_avatarError) return null;
    if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
      final file = File(_profileImagePath!);
      if (file.existsSync()) return FileImage(file);
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(_profileImageUrl!);
    }
    return null;
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PasswordLoginPage()),
      (route) => false,
    );
  }

  Future<void> _showLogoutConfirmation() async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _logout();
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final targetId = widget.userId.isNotEmpty
        ? widget.userId
        : (prefs.getString("user_id") ?? "");
    if (targetId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(userId: targetId)),
    );
    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      final localUser = prefs.getString('username') ?? '';
      if (localUser.isNotEmpty &&
          localUser != widget.userId &&
          !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(localUser)) {
        setState(() {
          _username = localUser;
          _profileImageUrl = prefs.getString('profile_image_url');
        });
      }
      _loadAll();
    }
  }

  Future<void> _openDraft(Map<String, dynamic> draft) async {
    await write.loadLibrary();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => write.WritePage(
          category: draft['category_id']?.toString() ?? '4',
          draftId: draft['draft_id']?.toString() ?? draft['id']?.toString(),
          draftContent: draft['content'] is String
              ? draft['content'] as String
              : (draft['content'] != null ? jsonEncode(draft['content']) : null),
          draftCover: (draft['cover_image'] ?? draft['cover_img'] ?? draft['coverImage'])?.toString(),
        ),
      ),
    );
    if (mounted) _fetchDrafts();
  }

  Future<void> _toggleLike(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final targetId = widget.userId.isNotEmpty
        ? widget.userId
        : (prefs.getString("user_id") ?? "");
    if (token.isEmpty && targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to like stories")),
      );
      return;
    }

    final isLiked = _likedPosts.contains(postId);
    setState(() {
      if (isLiked) {
        _likedPosts.remove(postId);
      } else {
        _likedPosts.add(postId);
      }

      for (var p in _myPosts) {
        if (p['post_id']?.toString() == postId) {
          int count = int.tryParse(p['support_count']?.toString() ?? '0') ?? 0;
          p['support_count'] = isLiked
              ? (count - 1).clamp(0, 999999)
              : (count + 1);
          break;
        }
      }
      for (var p in _savedPosts) {
        if (p['post_id']?.toString() == postId) {
          int count = int.tryParse(p['support_count']?.toString() ?? '0') ?? 0;
          p['support_count'] = isLiked
              ? (count - 1).clamp(0, 999999)
              : (count + 1);
          break;
        }
      }
    });

    await _saveInteractionsLocal();

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.apiBaseUrl}/posts/toggleSupport/$postId"),
        headers: {
          if (token.isNotEmpty) "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"userId": targetId}),
      );
      if (response.statusCode == 200) {
        try {
          final resData = jsonDecode(response.body);
          final serverCount = resData['support_count'] ?? resData['supports_count'];
          if (serverCount != null) {
            setState(() {
              for (var p in _myPosts) {
                if (p['post_id']?.toString() == postId) {
                  p['support_count'] = serverCount;
                  break;
                }
              }
              for (var p in _savedPosts) {
                if (p['post_id']?.toString() == postId) {
                  p['support_count'] = serverCount;
                  break;
                }
              }
            });
          }
        } catch (_) {}
      } else {
        // Revert
        setState(() {
          if (isLiked) {
            _likedPosts.add(postId);
          } else {
            _likedPosts.remove(postId);
          }
          for (var p in _myPosts) {
            if (p['post_id']?.toString() == postId) {
              int count =
                  int.tryParse(p['support_count']?.toString() ?? '0') ?? 0;
              p['support_count'] = isLiked
                  ? (count + 1)
                  : (count - 1).clamp(0, 999999);
              break;
            }
          }
          for (var p in _savedPosts) {
            if (p['post_id']?.toString() == postId) {
              int count =
                  int.tryParse(p['support_count']?.toString() ?? '0') ?? 0;
              p['support_count'] = isLiked
                  ? (count + 1)
                  : (count - 1).clamp(0, 999999);
              break;
            }
          }
        });
        await _saveInteractionsLocal();
      }
    } catch (_) {
      // Revert
      setState(() {
        if (isLiked) {
          _likedPosts.add(postId);
        } else {
          _likedPosts.remove(postId);
        }
        for (var p in _myPosts) {
          if (p['post_id']?.toString() == postId) {
            int count =
                int.tryParse(p['support_count']?.toString() ?? '0') ?? 0;
            p['support_count'] = isLiked
                ? (count + 1)
                : (count - 1).clamp(0, 999999);
            break;
          }
        }
        for (var p in _savedPosts) {
          if (p['post_id']?.toString() == postId) {
            int count =
                int.tryParse(p['support_count']?.toString() ?? '0') ?? 0;
            p['support_count'] = isLiked
                ? (count + 1)
                : (count - 1).clamp(0, 999999);
            break;
          }
        }
      });
      await _saveInteractionsLocal();
    }
  }

  Future<void> _toggleSave(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final targetId = widget.userId.isNotEmpty
        ? widget.userId
        : (prefs.getString("user_id") ?? "");
    if (token.isEmpty && targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to bookmark stories")),
      );
      return;
    }

    final postObj = _savedPosts.firstWhere(
      (p) => (p['post_id'] ?? p['_id'])?.toString() == postId,
      orElse: () => _myPosts.firstWhere(
        (p) => (p['post_id'] ?? p['_id'])?.toString() == postId,
        orElse: () => <String, dynamic>{},
      ),
    );

    await SavedPostsManager.instance.toggleSave(
      postId: postId,
      userId: targetId,
      token: token,
      postData: postObj.isNotEmpty ? postObj : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUserIdLike = _username.isEmpty ||
        _username == widget.userId ||
        RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(_username);
    final displayName = !isUserIdLike ? _username : 'Ryitu User';

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _loadAll,
        child: NestedScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(child: _buildProfileHeader(displayName)),
            SliverToBoxAdapter(child: _buildSegmentedTabs()),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPostsTab(
                _myPosts,
                _loadingPosts,
                icon: Icons.article_outlined,
                title: 'No posts yet',
                subtitle: 'Stories you publish will appear here',
                onDelete: _deletePost,
              ),
              _buildDraftsTab(),
              _buildPostsTab(
                _savedPosts,
                _loadingSaved,
                icon: Icons.bookmark_border_rounded,
                title: 'Nothing saved',
                subtitle: 'Bookmark stories to read them later',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String displayName) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 44, 20, 20),
        child: Column(
          children: [
            Row(
              children: [
                if (!widget.isPublicView)
                  IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                    tooltip: 'Logout',
                    onPressed: _showLogoutConfirmation,
                  ),
                const Spacer(),
                if (!widget.isPublicView)
                  Material(
                    color: AppColors.brand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _openEditProfile,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: AppColors.brand,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final avatar = _avatarProvider();
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.25),
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.08),
                    backgroundImage: avatar,
                    onBackgroundImageError: avatar != null
                        ? (exception, stackTrace) {
                            if (mounted) {
                              setState(() => _avatarError = true);
                            }
                          }
                        : null,
                    child: avatar == null
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brand,
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            _buildSimpleCounts(),
            if (_loadingProfile)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCounts() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _countText(_loadingPosts ? '—' : '${_myPosts.length}', 'Posts'),
        _countDivider(),
        _countText(_loadingDrafts ? '—' : '${_drafts.length}', 'Drafts'),
        _countDivider(),
        _countText(_loadingSaved ? '—' : '${_savedPosts.length}', 'Saved'),
      ],
    );
  }

  Widget _countText(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countDivider() {
    return Container(width: 1, height: 28, color: Colors.grey.shade300);
  }

  Widget _buildSegmentedTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _segmentTab(0, Icons.article_outlined, 'My Posts'),
            _segmentTab(1, Icons.drafts_outlined, 'Drafts'),
            _segmentTab(2, Icons.bookmark_outline_rounded, 'Saved'),
          ],
        ),
      ),
    );
  }

  Widget _segmentTab(int index, IconData icon, String label) {
    final selected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: AppColors.brand),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsTab(
    List<Map<String, dynamic>> posts,
    bool isLoading, {
    required IconData icon,
    required String title,
    required String subtitle,
    void Function(String)? onDelete,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (posts.isEmpty) {
      return _buildEmptyState(icon: icon, title: title, subtitle: subtitle);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final postId = (post['post_id'] ?? post['_id'])?.toString() ?? '';
        return PostContainer(
          post: post,
          isLiked: _likedPosts.contains(postId),
          isSaved: SavedPostsManager.instance.isSaved(postId),
          onLike: () => _toggleLike(postId),
          onSave: () => _toggleSave(postId),
          onDelete: onDelete != null ? () => onDelete(postId) : null,
          currentUserId: widget.userId,
          currentUsername: _username,
        );
      },
    );
  }

  Future<void> _deletePost(String postId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Post"),
        content: const Text("Are you sure you want to delete this story?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    if (token.isEmpty) return;

    try {
      final response = await http.delete(
        Uri.parse("${ApiConfig.apiBaseUrl}/posts/$postId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story deleted successfully")),
        );
        _fetchMyPosts();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to delete story")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _deleteDraft(String draftId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Draft"),
        content: const Text("Are you sure you want to delete this draft?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    if (token.isEmpty) return;

    try {
      final response = await http.delete(
        Uri.parse("${ApiConfig.apiBaseUrl}/draft/$draftId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Draft deleted successfully")),
        );
        _fetchDrafts();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to delete draft")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildDraftsTab() {
    if (_loadingDrafts) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (_drafts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.drafts_outlined,
        title: 'No drafts yet',
        subtitle: 'Start writing and save as draft to continue later',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final draft = _drafts[index];
        final draftId = draft['draft_id']?.toString() ?? '';

        final enrichedDraft = Map<String, dynamic>.from(draft);
        enrichedDraft['username'] = _username;
        enrichedDraft['profile_image'] = _profileImageUrl;

        return PostContainer(
          post: enrichedDraft,
          isLiked: false,
          isSaved: false,
          onLike: () {},
          onSave: () {},
          isDraft: true,
          onDelete: () => _deleteDraft(draftId),
          onTap: () => _openDraft(draft),
        );
      },
    );
  }
}

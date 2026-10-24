import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_bottom_nav.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/profile.dart';
import 'package:dmk_project/saved_posts_manager.dart';
import 'package:dmk_project/liked_posts_manager.dart';
import 'package:dmk_project/hashtag.dart' show HashtagPostsPage;
import 'package:dmk_project/legal_pages.dart';
import 'package:dmk_project/community_page.dart';
import 'package:dmk_project/notifications_page.dart';
import 'package:dmk_project/services/notification_badge_manager.dart';
import 'package:dmk_project/services/notification_service.dart';
import 'package:dmk_project/services/app_update_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dmk_project/reading_page.dart';

// ==========================================
// MAIN SHELL (TAB COORDINATOR)
// ==========================================
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  String? _userId;
  bool _isLoading = true;
  DateTime? _lastBackPressTime;
  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();
  final GlobalKey<ProfilePageState> _profileKey = GlobalKey<ProfilePageState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 1);
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userId = prefs.getString("user_id");
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppUpdateService().checkUpdate(context);
        }
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.brand,
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If on Profile page, navigate back to Home page without exiting app
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // 2. We are on Home page (_currentIndex == 0)
        final homeState = _homeKey.currentState;
        final now = DateTime.now();

        // If scrolled down on Home page: scroll to top, auto-refresh feed
        if (homeState != null && homeState.isScrolledDown) {
          await homeState.scrollToTopAndRefresh();
          _lastBackPressTime = DateTime.now();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // If already at top or on the first back click:
        final bool canExit = _lastBackPressTime != null &&
            now.difference(_lastBackPressTime!) <= const Duration(seconds: 2);

        if (!canExit) {
          _lastBackPressTime = now;
          if (homeState != null) {
            await homeState.scrollToTopAndRefresh();
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Double back click within 2 seconds: exit app
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomePage(key: _homeKey),
            ProfilePage(
              key: _profileKey,
              userId: _userId ?? '',
              isPublicView: false,
              onBackToHome: () {
                if (mounted) {
                  setState(() => _currentIndex = 0);
                }
              },
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNavBar(
          activeIndex: _currentIndex,
          onTabSelected: (index) {
            setState(() => _currentIndex = index);
            if (index == 1) {
              _profileKey.currentState?.reloadProfileData();
            }
          },
        ),
      ),
    );
  }
}

// ==========================================
// HOME PAGE (STORY FEED)
// ==========================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _posts = [];
  Set<String> _likedPosts = {};
  Set<String> _savedPosts = {};
  bool _isLoading = true;
  String? _userId;
  String? _currentUsername;

  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  final int _limit = 10;
  bool _hasNextPage = true;
  bool _isLoadMoreRunning = false;

  Future<void> _fetchUnreadNotificationCount() async {
    await NotificationBadgeManager.instance.refreshUnreadCount();
  }

  bool get isScrolledDown =>
      _scrollController.hasClients && _scrollController.offset > 50;

  Future<void> scrollToTopAndRefresh() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    await _fetchFeed();
    _fetchUnreadNotificationCount();
  }

  @override
  void initState() {
    super.initState();
    SavedPostsManager.instance.addListener(_onSavedChanged);
    LikedPostsManager.instance.addListener(_onInteractionsChanged);
    _scrollController.addListener(_loadMore);
    _loadUserAndFeed();
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  void _onInteractionsChanged() {
    if (!mounted) return;
    if (LikedPostsManager.instance.deletedPostIds.isNotEmpty) {
      _posts.removeWhere((p) {
        final pid = (p['post_id'] ?? p['_id'])?.toString() ?? '';
        return LikedPostsManager.instance.deletedPostIds.contains(pid);
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    SavedPostsManager.instance.removeListener(_onSavedChanged);
    LikedPostsManager.instance.removeListener(_onInteractionsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndFeed() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString("user_id");
    _currentUsername = (prefs.getString("username") ??
            prefs.getString("user_name") ??
            prefs.getString("name") ??
            "")
        .trim();
    SavedPostsManager.instance.init(_userId);
    LikedPostsManager.instance.init(_userId);
    NotificationBadgeManager.instance.init(
      userId: _userId,
      authToken: prefs.getString("token"),
    );
    if (_userId != null && _userId!.isNotEmpty) {
      NotificationService().syncFcmToken(_userId);
    }
    await _fetchFeed();
    await _fetchUserInteractions();
    _fetchUnreadNotificationCount();
  }

  void _sanitizePosts(List<Map<String, dynamic>> postList) {
    if (_userId == null || _userId!.isEmpty) return;
    final fallbackUser = _currentUsername ?? '';
    if (fallbackUser.isEmpty) return;
    for (var p in postList) {
      final pUserId = p['user_id']?.toString() ?? '';
      if (pUserId == _userId) {
        final uname = p['username']?.toString() ?? '';
        if (uname.isEmpty ||
            uname.toLowerCase() == 'anonymous' ||
            RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(uname)) {
          p['username'] = fallbackUser;
        }
      }
    }
  }

  Future<void> _fetchFeed() async {
    setState(() {
      _isLoading = true;
      _page = 1;
      _hasNextPage = true;
    });
    try {
      final userParam = (_userId != null && _userId!.isNotEmpty) ? "&userId=$_userId" : "";
      http.Response? response;
      try {
        response = await http.get(
          Uri.parse("${ApiConfig.apiBaseUrl}/posts?page=$_page&limit=$_limit$userParam"),
        ).timeout(const Duration(seconds: 12));
      } catch (err) {
        // If local backend fails (timeout, socket exception, host unreachable), auto-fallback to live backend
        if (ApiConfig.activeBaseUrl != ApiConfig.liveBaseUrl) {
          debugPrint('Local backend failed ($err). Auto-falling back to live backend: ${ApiConfig.liveBaseUrl}');
          ApiConfig.activeBaseUrl = ApiConfig.liveBaseUrl;
          response = await http.get(
            Uri.parse("${ApiConfig.apiBaseUrl}/posts?page=$_page&limit=$_limit$userParam"),
          ).timeout(const Duration(seconds: 25));
        } else {
          rethrow;
        }
      }
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] is List) {
          _posts = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
          _sanitizePosts(_posts);
          for (var p in _posts) {
            final pid = (p['post_id'] ?? p['_id'])?.toString() ?? '';
            if (pid.isNotEmpty) {
              if (p['isSaved'] == true) {
                _savedPosts.add(pid);
                SavedPostsManager.instance.savedPostIds.add(pid);
              }
              final isSup = (p['isSupported'] == true || p['isLiked'] == true);
              final sc = int.tryParse(p['support_count']?.toString() ?? '');
              LikedPostsManager.instance.syncPost(pid, isLiked: isSup, supportCount: sc);
              if (isSup) _likedPosts.add(pid);
              if (p['comment_count'] != null) {
                CommentsSheetContent.commentCounts[pid] = int.tryParse(p['comment_count'].toString()) ?? 0;
              }
            }
          }
          await _saveInteractionsLocal();
        }
        if (decoded is Map && decoded['pagination'] is Map) {
          final pagination = decoded['pagination'];
          final totalPages = int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
          if (_page >= totalPages) {
            _hasNextPage = false;
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_hasNextPage &&
        !_isLoading &&
        !_isLoadMoreRunning &&
        _scrollController.position.extentAfter < 300) {
      setState(() => _isLoadMoreRunning = true);
      _page += 1;
      try {
        final userParam = (_userId != null && _userId!.isNotEmpty) ? "&userId=$_userId" : "";
        final response = await http.get(
          Uri.parse("${ApiConfig.apiBaseUrl}/posts?page=$_page&limit=$_limit$userParam"),
        ).timeout(const Duration(seconds: 25));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['data'] is List) {
            final List newPosts = decoded['data'];
            if (newPosts.isNotEmpty) {
              final mappedNew = List<Map<String, dynamic>>.from(
                newPosts.map((e) => Map<String, dynamic>.from(e as Map)),
              );
              _sanitizePosts(mappedNew);
              for (var p in mappedNew) {
                final pid = (p['post_id'] ?? p['_id'])?.toString() ?? '';
                if (pid.isNotEmpty) {
                  if (p['isSaved'] == true) {
                    _savedPosts.add(pid);
                    SavedPostsManager.instance.savedPostIds.add(pid);
                  }
                  final isSup = (p['isSupported'] == true || p['isLiked'] == true);
                  final sc = int.tryParse(p['support_count']?.toString() ?? '');
                  LikedPostsManager.instance.syncPost(pid, isLiked: isSup, supportCount: sc);
                  if (isSup) _likedPosts.add(pid);
                  if (p['comment_count'] != null) {
                    CommentsSheetContent.commentCounts[pid] = int.tryParse(p['comment_count'].toString()) ?? 0;
                  }
                }
              }
              setState(() {
                _posts.addAll(mappedNew);
              });
              await _saveInteractionsLocal();
            } else {
              setState(() => _hasNextPage = false);
            }
          }
          if (decoded is Map && decoded['pagination'] is Map) {
            final pagination = decoded['pagination'];
            final totalPages = int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
            if (_page >= totalPages) {
              setState(() => _hasNextPage = false);
            }
          }
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _isLoadMoreRunning = false);
      }
    }
  }

  Future<void> _fetchUserInteractions() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPosts = (prefs.getStringList('cached_saved_posts') ?? []).toSet();
      _likedPosts = (prefs.getStringList('cached_liked_posts') ?? []).toSet();
    });
  }

  Future<void> _saveInteractionsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cached_saved_posts', _savedPosts.toList());
    await prefs.setStringList('cached_liked_posts', _likedPosts.toList());
  }

  Future<void> _toggleLike(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final effectiveUserId = _userId ?? prefs.getString("user_id") ?? "";
    if (token.isEmpty && effectiveUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to like stories")),
      );
      return;
    }

    final post = _posts.firstWhere(
      (p) => (p['post_id'] ?? p['_id'])?.toString() == postId,
      orElse: () => <String, dynamic>{},
    );
    final count = LikedPostsManager.instance.getSupportCount(postId) ??
        int.tryParse(post['support_count']?.toString() ?? '0') ?? 0;

    await LikedPostsManager.instance.toggleLike(
      postId: postId,
      userId: effectiveUserId,
      token: token,
      currentCount: count,
    );
  }

  Future<void> _toggleSave(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final effectiveUserId = _userId ?? prefs.getString("user_id") ?? "";
    if (token.isEmpty && effectiveUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to bookmark stories")),
      );
      return;
    }

    final postObj = _posts.firstWhere(
      (p) => (p['post_id'] ?? p['_id'])?.toString() == postId,
      orElse: () => <String, dynamic>{},
    );

    await SavedPostsManager.instance.toggleSave(
      postId: postId,
      userId: effectiveUserId,
      token: token,
      postData: postObj.isNotEmpty ? postObj : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/ryitu_logo_round.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "Ritpen",
              style: GoogleFonts.outfit(
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_rounded, color: AppColors.brand, size: 26),
            tooltip: 'Communities (கம்யூனிட்டி)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CommunitiesListPage()),
              );
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: NotificationBadgeManager.instance.unreadCountNotifier,
            builder: (context, unreadCount, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1A1A1A), size: 26),
                    tooltip: 'Notifications',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsPage()),
                      );
                      _fetchUnreadNotificationCount();
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'communities') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommunitiesListPage()),
                );
              } else if (value == 'privacy') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                );
              } else if (value == 'terms') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsConditionsPage()),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'communities',
                child: Row(
                  children: [
                    Icon(Icons.groups_rounded, size: 20, color: AppColors.brand),
                    SizedBox(width: 10),
                    Text(
                      'Communities',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'privacy',
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, size: 20, color: AppColors.brand),
                    SizedBox(width: 10),
                    Text(
                      'Privacy Policy',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'terms',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 20, color: AppColors.brand),
                    SizedBox(width: 10),
                    Text(
                      'Terms & Conditions',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : _posts.isEmpty
              ? RefreshIndicator(
                  color: AppColors.brand,
                  onRefresh: _fetchFeed,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                      appEmptyState(
                        icon: Icons.auto_stories_outlined,
                        title: 'கதைகள் இல்லை',
                        subtitle: 'புதிய கதைகள் வரும்போது இங்கே தெரியும்',
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _fetchFeed,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('மீண்டும் புதுப்பி'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brand,
                            side: const BorderSide(color: AppColors.brand),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.brand,
                  onRefresh: _fetchFeed,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _posts.length + (_isLoadMoreRunning ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _posts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.brand,
                            ),
                          ),
                        );
                      }
                      final post = _posts[index];
                      final postId = (post['post_id'] ?? post['_id'])?.toString() ?? '';

                      return PostContainer(
                        key: ValueKey('home_post_${postId}_${post['cover_image'] ?? post['cover_img'] ?? ''}'),
                        post: post,
                        isLiked: LikedPostsManager.instance.isLiked(postId),
                        isSaved: SavedPostsManager.instance.isSaved(postId),
                        onLike: () => _toggleLike(postId),
                        onSave: () => _toggleSave(postId),
                        currentCategory: 'Ritpen',
                        currentUserId: _userId,
                        currentUsername: _currentUsername,
                      );
                    },
                  ),
                ),
    );
  }
}

// ==========================================
// POST CONTAINER (STORY CARD)
// ==========================================
typedef PostCard = PostContainer;

class PostContainer extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool isDraft;
  final String currentCategory;
  final bool isCommunityView;
  final String? currentUserId;
  final String? currentUsername;

  const PostContainer({
    super.key,
    required this.post,
    this.isLiked = false,
    this.isSaved = false,
    this.onLike,
    this.onSave,
    this.onDelete,
    this.onTap,
    this.isDraft = false,
    this.currentCategory = "All",
    this.isCommunityView = false,
    this.currentUserId,
    this.currentUsername,
  });

  String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return "";
    path = path.trim();

    if (path.startsWith("http")) {
      if (path.contains("localhost") || path.contains("127.0.0.1")) {
        try {
          final uri = Uri.parse(path);
          final baseUri = Uri.parse(ApiConfig.baseUrl);
          return uri.replace(scheme: baseUri.scheme, host: baseUri.host, port: baseUri.port).toString();
        } catch (_) {
          return path;
        }
      }
      return path;
    }

    path = path.replaceAll("\\", "/").replaceAll(RegExp(r'^/+'), "");

    if (!path.contains("/")) {
      if (path.contains("profile_image") || path.contains("profile")) {
        path = "uploads/profile_images/$path";
      } else if (path.contains("cover")) {
        path = "uploads/covers/$path";
      } else if (path.contains("page_img")) {
        path = "uploads/page_images/$path";
      } else {
        path = "uploads/covers/$path";
      }
    } else if (!path.startsWith("uploads/")) {
      if (path.startsWith("covers/")) {
        path = "uploads/$path";
      } else if (path.startsWith("profile_images/")) {
        path = "uploads/$path";
      } else if (path.startsWith("page_images/")) {
        path = "uploads/$path";
      }
    }

    return "${ApiConfig.baseUrl}/$path";
  }

  List<dynamic> _extractPages(dynamic rawContent) {
    if (rawContent == null) return [];
    if (rawContent is List) return rawContent;
    // Already a decoded Map (e.g. {titleStyle: {...}, pages: [...]})
    if (rawContent is Map) {
      if (rawContent.containsKey('pages')) return rawContent['pages'] ?? [];
      return [];
    }
    if (rawContent is String) {
      try {
        final decoded = jsonDecode(rawContent);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded.containsKey('pages')) {
          return decoded['pages'] ?? [];
        }
      } catch (_) {}
    }
    return [];
  }


  String _formatTime(dynamic rawDate) {
    if (rawDate == null) return "";
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return "Just now";
      if (diff.inHours < 1) return "${diff.inMinutes}m ago";
      if (diff.inDays < 1) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return "${diff.inDays}d ago";
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return rawDate.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF0729E8);
    final postId = (post['post_id'] ?? post['_id'] ?? post['draft_id'])?.toString() ?? "";
    String username = post['username']?.toString() ?? "";
    if (username.isEmpty || username.toLowerCase() == "anonymous" || RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(username)) {
      final fallbackName = post['name']?.toString() ?? post['author']?.toString() ?? post['user_name']?.toString() ?? '';
      if (fallbackName.isNotEmpty && fallbackName.toLowerCase() != "anonymous" && !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(fallbackName)) {
        username = fallbackName;
      } else if (currentUserId != null && currentUserId!.isNotEmpty && post['user_id']?.toString() == currentUserId && currentUsername != null && currentUsername!.isNotEmpty) {
        username = currentUsername!;
      } else {
        username = "Ritpen User";
      }
    }
    final profileImage = _fullUrl(post['profile_image']?.toString());
    final title = post['title']?.toString() ?? "Untitled Story";
    final caption = post['caption']?.toString() ?? "";
    final supportCount = LikedPostsManager.instance.getSupportCount(postId) ??
        int.tryParse(post['support_count']?.toString() ?? '0') ??
        0;
    final hashtagsStr = post['hashtags']?.toString() ?? "";
    final viewsCount = int.tryParse(post['views']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: _buildNoolagamLayout(
        context,
        brandColor,
        postId,
        username,
        profileImage,
        title,
        caption,
        supportCount,
        hashtagsStr,
        viewsCount,
      ),
    );
  }

  void _openReader(
    BuildContext context,
    String postId,
    String username,
    String profileImage,
    String title,
    String? commId,
  ) async {
    if (onTap != null) {
      onTap!();
      return;
    }

    if (postId.isNotEmpty && !isDraft) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final List<String> viewedList = prefs.getStringList('viewed_posts') ?? [];
        if (!viewedList.contains(postId)) {
          viewedList.add(postId);
          await prefs.setStringList('viewed_posts', viewedList);
          http.post(Uri.parse("${ApiConfig.apiBaseUrl}/posts/view/$postId")).catchError((_) => http.Response("", 500));
          try {
            post['views'] = (int.tryParse(post['views']?.toString() ?? '0') ?? 0) + 1;
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    final pdfUrl = (post['pdf_url'] ?? post['pdfUrl'] ?? post['pdf'])?.toString();
    if (pdfUrl != null && pdfUrl.isNotEmpty && (pdfUrl.toLowerCase().endsWith('.pdf') || post['is_pdf'] == true)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingPage(
            bookId: postId,
            bookTitle: title,
            author: username,
            pdfUrl: _fullUrl(pdfUrl),
            communityId: commId,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenPostViewer(
            pages: _extractPages(post['content']),
            username: username,
            profileImage: profileImage,
            postId: postId,
            postTitle: title,
          ),
        ),
      );
    }
  }

  Widget _buildNoolagamLayout(
    BuildContext context,
    Color brandColor,
    String postId,
    String username,
    String profileImage,
    String title,
    String caption,
    int supportCount,
    String hashtagsStr,
    int viewsCount,
  ) {
    final coverRaw = (post['cover_img'] ?? post['cover_image'] ?? post['coverImage'])?.toString();
    final hasCover = coverRaw != null && coverRaw.isNotEmpty;
    final commId = (post['communityId'] ?? post['community_id'])?.toString();
    final commName = (post['communityName'] ?? post['community_name'])?.toString();
    final isCommPost = (post['isCommunityPost'] == true) || (commId != null && commId.isNotEmpty && commId != 'null');
    final createdAtRaw = post['createdAt'] ?? post['created_at'];

    // Parse titleStyle embedded in content JSON (saved at publish time)
    double titleFontSize = 19;
    Color titleColor = const Color(0xFF111827);
    String? titleFontFamily;
    try {
      final rawContent = post['content'];
      dynamic decodedContent;
      if (rawContent is String) {
        decodedContent = jsonDecode(rawContent.trim());
      } else {
        decodedContent = rawContent;
      }
      if (decodedContent is Map && decodedContent['titleStyle'] is Map) {
        final ts = decodedContent['titleStyle'] as Map;
        if (ts['fontSize'] != null) {
          titleFontSize = (ts['fontSize'] as num).toDouble().clamp(12.0, 36.0);
        }
        if (ts['color'] != null) {
          final c = Color((ts['color'] as num).toInt());
          // Don't use white on the card (white background) — keep dark fallback
          if (c != Colors.white && c.computeLuminance() > 0.05) {
            titleColor = c;
          }
        }
        if (ts['fontFamily'] != null) {
          titleFontFamily = ts['fontFamily'].toString();
        }
      }
    } catch (_) {}



    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header: User Profile on left, Views badge pill on right
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: brandColor.withOpacity(0.1),
              backgroundImage: profileImage.isNotEmpty
                  ? CachedNetworkImageProvider(profileImage)
                  : null,
              onBackgroundImageError: profileImage.isNotEmpty
                  ? (exception, stackTrace) {}
                  : null,
              child: profileImage.isEmpty
                  ? Text(
                      username.isNotEmpty ? username[0].toUpperCase() : "U",
                      style: GoogleFonts.outfit(
                        color: brandColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: const Color(0xFF1F2937),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Highlighted community badge below username
                  if (isCommPost)
                    InkWell(
                      onTap: () {
                        if (!isCommunityView && commId != null && commId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommunityPage(
                                communityId: commId,
                                communityName: commName,
                              ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: brandColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: brandColor.withOpacity(0.25), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_rounded, size: 13, color: brandColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                commName != null && commName.isNotEmpty
                                    ? commName
                                    : 'Community',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: brandColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (post['Constituency'] != null && post['Constituency'].toString().trim().isNotEmpty)
                    Text(
                      post['Constituency'].toString().trim(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'General',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (isCommPost && post['Constituency'] != null && post['Constituency'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      post['Constituency'].toString().trim(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Views Badge Pill on the top right (book icon + views count)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_rounded, color: Color(0xFF991B1B), size: 14),
                  const SizedBox(width: 5),
                  Text(
                    "$viewsCount",
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),

        const SizedBox(height: 14),

        // Vertical Framed Post Image Centerpiece — full width, taller portrait
        GestureDetector(
          onTap: () => _openReader(context, postId, username, profileImage, title, commId),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 9 / 14, // Taller portrait (like a book cover)
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image or gradient fallback — SVG & raster both supported
                  hasCover
                      ? Builder(builder: (bCtx) {
                          final coverUrl = _fullUrl(coverRaw);
                          final isSvg = coverUrl.toLowerCase().endsWith('.svg') ||
                              (coverRaw ?? '').toLowerCase().endsWith('.svg');
                          if (isSvg) {
                            return SvgPicture.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              placeholderBuilder: (_) => Container(
                                color: brandColor.withOpacity(0.08),
                                child: Center(child: CircularProgressIndicator(color: brandColor)),
                              ),
                            );
                          }
                          return CachedNetworkImage(
                            key: ValueKey('cover_${postId}_$coverUrl'),
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 800,
                            fadeInDuration: const Duration(milliseconds: 150),
                            fadeOutDuration: const Duration(milliseconds: 150),
                            placeholder: (context, url) => Container(
                              color: brandColor.withOpacity(0.06),
                              child: Center(
                                child: CircularProgressIndicator(color: brandColor),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [brandColor, const Color(0xFF041CA1)],
                                ),
                              ),
                              child: Center(
                                child: Icon(Icons.auto_stories_outlined, size: 64,
                                    color: Colors.white.withOpacity(0.8)),
                              ),
                            ),
                          );
                        })
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                brandColor,
                                const Color(0xFF041CA1),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 64),
                              const SizedBox(height: 20),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                  // Dark gradient overlay at bottom for readability
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Page count badge overlay on portrait cover
                  Builder(builder: (bCtx) {
                    final rawCount = post['pageCount'] ?? post['page_count'] ?? post['totalPages'] ?? '';
                    final pageCount = int.tryParse(rawCount.toString());
                    if (pageCount == null || pageCount <= 0) return const SizedBox.shrink();
                    return Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded, color: Colors.white, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              '$pageCount Pages',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Centered Bold Title (custom font/color from cover editor)
        GestureDetector(
          onTap: () => _openReader(context, postId, username, profileImage, title, commId),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w900,
                fontFamily: titleFontFamily,
                height: 1.35,
              ),
            ),
          ),
        ),

        // Action Buttons Row (Like, Comment, Share, Bookmark)
        if (!isDraft) ...[
          const SizedBox(height: 8),
          const Divider(height: 20, thickness: 0.8, color: Color(0xFFEEEEEE)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Like button
                  Builder(builder: (context) {
                    final effectiveLiked = LikedPostsManager.instance.isLiked(postId);
                    final effectiveCount = LikedPostsManager.instance.getSupportCount(postId) ?? supportCount;
                    return GestureDetector(
                      onTap: onLike,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              effectiveLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                              color: effectiveLiked ? Colors.red : AppColors.textSecondary,
                              size: 22,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "$effectiveCount",
                              style: TextStyle(
                                color: effectiveLiked ? Colors.red : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 16),
                  // Comment button
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => CommentsSheetContent(
                          postId: postId,
                          brandColor: brandColor,
                          onCommentChanged: () {
                            if (context.mounted) {
                              (context as Element).markNeedsBuild();
                            }
                          },
                        ),
                      ).then((_) {
                        if (context.mounted) {
                          (context as Element).markNeedsBuild();
                        }
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "${CommentsSheetContent.getCommentCount(postId, fallback: int.tryParse(post['comment_count']?.toString() ?? '0') ?? 0)}",
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Share button
                  GestureDetector(
                    onTap: () {
                      final shareUrl = "${ApiConfig.baseUrl}/share/post/$postId";
                      final deepLink = "Ritpen://post/$postId";
                      Share.share("Check out this story on Ritpen: '$title'\n\nRead here: $shareUrl\nOpen in App: $deepLink");
                    },
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.share_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              // Save / Bookmark button on right
              GestureDetector(
                onTap: onSave,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isSaved ? brandColor : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Caption, Hashtags & Post Timestamp BELOW the Action Buttons
        if (caption.isNotEmpty || hashtagsStr.isNotEmpty || createdAtRaw != null) ...[
          const SizedBox(height: 8),
          if (caption.isNotEmpty) ...[
            Text(
              caption,
              style: const TextStyle(
                color: Color(0xFF2C2C2C),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (hashtagsStr.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: hashtagsStr
                  .split(RegExp(r'\s+'))
                  .where((t) => t.isNotEmpty)
                  .map((tag) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HashtagPostsPage(tag: tag),
                      ),
                    );
                  },
                  child: Text(
                    tag.startsWith('#') ? tag : '#$tag',
                    style: TextStyle(
                      color: brandColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
          ],
          if (createdAtRaw != null) ...[
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  _formatTime(createdAtRaw),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

}

// ==========================================
// EXPANDABLE POST IMAGE (ZOOM SUPPORT)
// ==========================================
class ExpandablePostImage extends StatelessWidget {
  final String imageUrl;

  const ExpandablePostImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(color: Color(0xFF0729E8))),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error_outline_rounded),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// FULL SCREEN POST VIEWER (BOOK READER)
// ==========================================
class FullScreenPostViewer extends StatefulWidget {
  final List<dynamic> pages;
  final String username;
  final String profileImage;
  final String postId;
  final String postTitle;

  const FullScreenPostViewer({
    super.key,
    required this.pages,
    required this.username,
    required this.profileImage,
    required this.postId,
    required this.postTitle,
  });

  @override
  State<FullScreenPostViewer> createState() => _FullScreenPostViewerState();
}

class _FullScreenPostViewerState extends State<FullScreenPostViewer> {
  int _currentPage = 0;
  final PageController _pageController = PageController();
  double _fontSize = 18.0;
  String _appearance = "Sepia"; // Options: "Light", "Sepia", "Dark"
  String? _selectedFontFamily; // null = use original fonts from writing page
  int? _selectedFontColor; // null = use original colors from writing page

  static const List<String> _fontFamilies = [
    "Roboto",
    "Lora",
    "Playfair Display",
    "Mukta Malar",
    "Hind Madurai",
    "Pavanam",
    "Arima",
    "Kavivanar",
    "Catamaran",
    "Baloo 2",
    "Tiro Tamil",
    "Inter",
    "Merienda",
    "Lobster",
  ];

  static const List<int> _fontColors = [
    0xFF000000, // Black
    0xFFF44336, // Red
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFF9C27B0, // Purple
    0xFFFF9800, // Orange
    0xFF009668, // Teal
    0xFF795548, // Brown
    0xFF0729E8, // Brand Blue
  ];

  late List<dynamic> _pages;

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.pages);
    _loadLastReadPage();
    _fetchFullContentIfNeeded();
  }

  Future<void> _fetchFullContentIfNeeded() async {
    if (widget.postId.isEmpty) return;
    try {
      final res = await http.get(Uri.parse('${ApiConfig.apiBaseUrl}/posts/${widget.postId}')).timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['data'] is Map) {
          final postData = decoded['data'];
          final rawContent = postData['content'];
          List<dynamic> fullPages = [];
          if (rawContent is List) {
            fullPages = rawContent;
          } else if (rawContent is Map && rawContent.containsKey('pages')) {
            fullPages = rawContent['pages'] ?? [];
          } else if (rawContent is String) {
            try {
              final d = jsonDecode(rawContent);
              if (d is List) fullPages = d;
              if (d is Map && d.containsKey('pages')) fullPages = d['pages'] ?? [];
            } catch (_) {}
          }
          if (fullPages.length > _pages.length && mounted) {
            setState(() {
              _pages = fullPages;
            });
            _loadLastReadPage();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLastReadPage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPage = prefs.getInt("last_read_page_${widget.postId}") ?? 0;
    if (savedPage > 0 && savedPage < _pages.length) {
      setState(() {
        _currentPage = savedPage;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(savedPage);
        }
      });
    }
  }

  Future<void> _saveLastReadPage(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("last_read_page_${widget.postId}", index);
  }

  Color _parseColor(dynamic val) {
    if (val == null) return Colors.black;
    try {
      return Color(int.parse(val.toString()));
    } catch (_) {
      return Colors.black;
    }
  }

  TextStyle _resolveTextStyle({
    required dynamic block,
    required dynamic page,
    required Color defaultTextColor,
  }) {
    // 1. Font Family: use selected override if any, or block font, or page font, or fallback to Roboto
    final fontFam = _selectedFontFamily ??
        (block is Map ? block['fontFamily']?.toString() : null) ??
        (page is Map ? page['fontFamily']?.toString() : null) ??
        'Roboto';

    // 2. Font Color: use selected override if any, or block color, or page color, or defaultTextColor
    Color color;
    if (_selectedFontColor != null) {
      color = Color(_selectedFontColor!);
    } else {
      final rawBlockColor = (block is Map ? block['fontColor'] : null);
      final rawPageColor = (page is Map ? page['fontColor'] : null);
      final rawCol = rawBlockColor ?? rawPageColor;
      if (rawCol != null) {
        final parsed = _parseColor(rawCol);
        if (_appearance == "Dark" && parsed.computeLuminance() < 0.15) {
          color = defaultTextColor;
        } else {
          color = parsed;
        }
      } else {
        color = defaultTextColor;
      }
    }

    // 3. Font Size:
    final bool isHeadline = (block is Map && block['isHeadline'] == true);
    double size = _fontSize;
    if (isHeadline) {
      size = _fontSize + 8;
    } else if (block is Map && block['fontSize'] != null) {
      final double blkSize = (block['fontSize'] as num).toDouble();
      size = (blkSize / 22.0) * _fontSize;
    }

    // 4. Line Spacing & Letter Spacing:
    double height = 1.6;
    if (block is Map && block['lineSpacing'] != null) {
      height = (block['lineSpacing'] as num).toDouble();
    } else if (page is Map && page['lineSpacing'] != null) {
      height = (page['lineSpacing'] as num).toDouble();
    }

    double letterSpacing = 0.0;
    if (block is Map && block['letterSpacing'] != null) {
      letterSpacing = (block['letterSpacing'] as num).toDouble();
    } else if (page is Map && page['letterSpacing'] != null) {
      letterSpacing = (page['letterSpacing'] as num).toDouble();
    }

    final base = TextStyle(
      fontSize: size,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: isHeadline ? FontWeight.w900 : FontWeight.w400,
    );

    try {
      return GoogleFonts.getFont(fontFam, textStyle: base);
    } catch (_) {
      return base.copyWith(fontFamily: fontFam);
    }
  }

  TextAlign _resolveTextAlign(dynamic block, dynamic page) {
    int? idx;
    if (block is Map && block['textAlign'] != null) {
      idx = int.tryParse(block['textAlign'].toString());
    } else if (page is Map && page['textAlign'] != null) {
      idx = int.tryParse(page['textAlign'].toString());
    }
    if (idx != null && idx >= 0 && idx < TextAlign.values.length) {
      return TextAlign.values[idx];
    }
    // Default: justify all content text for clean reading experience
    return TextAlign.justify;
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "READING DISPLAYS",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black38,
                            letterSpacing: 1.2,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _fontSize = 18.0;
                              _appearance = "Sepia";
                              _selectedFontFamily = null;
                              _selectedFontColor = null;
                            });
                            setSheetState(() {});
                          },
                          child: const Text(
                            "RESET",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0729E8),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Font Size Section
                    const Text(
                      "FONT SIZE",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black38,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Minus Button
                        IconButton(
                          onPressed: () {
                            if (_fontSize > 12.0) {
                              setState(() {
                                _fontSize -= 2.0;
                              });
                              setSheetState(() {});
                            }
                          },
                          iconSize: 20,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F4F7),
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: const Icon(Icons.remove, color: Colors.black87),
                        ),
                        const SizedBox(width: 28),
                        // Size Display
                        Text(
                          "${_fontSize.toInt()} px",
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'serif',
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 28),
                        // Plus Button
                        IconButton(
                          onPressed: () {
                            if (_fontSize < 36.0) {
                              setState(() {
                                _fontSize += 2.0;
                              });
                              setSheetState(() {});
                            }
                          },
                          iconSize: 20,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF2F4F7),
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: const Icon(Icons.add, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Font Style Section (எழுத்துரு)
                    const Text(
                      "FONT STYLE (எழுத்துரு)",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black38,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // "Original" option (uses fonts assigned in writing page)
                          _buildFontChip(
                            label: "Original",
                            isSelected: _selectedFontFamily == null,
                            fontName: null,
                            onTap: () {
                              setState(() {
                                _selectedFontFamily = null;
                              });
                              setSheetState(() {});
                            },
                          ),
                          ..._fontFamilies.map((font) {
                            return _buildFontChip(
                              label: font,
                              isSelected: _selectedFontFamily == font,
                              fontName: font,
                              onTap: () {
                                setState(() {
                                  _selectedFontFamily = font;
                                });
                                setSheetState(() {});
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Text Color Section (வண்ணம்)
                    const Text(
                      "TEXT COLOR (வண்ணம்)",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black38,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // "Original" color option
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFontColor = null;
                              });
                              setSheetState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _selectedFontColor == null
                                    ? const Color(0xFF0729E8).withOpacity(0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _selectedFontColor == null
                                      ? const Color(0xFF0729E8)
                                      : Colors.grey.shade300,
                                  width: _selectedFontColor == null ? 1.8 : 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Original",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedFontColor == null
                                      ? const Color(0xFF0729E8)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          ..._fontColors.map((colorVal) {
                            final isSel = _selectedFontColor == colorVal;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFontColor = colorVal;
                                });
                                setSheetState(() {});
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: Color(colorVal),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? const Color(0xFF0729E8) : Colors.grey.shade300,
                                    width: isSel ? 3.0 : 1.0,
                                  ),
                                  boxShadow: isSel
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF0729E8).withOpacity(0.35),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSel
                                    ? const Center(
                                        child: Icon(
                                          Icons.check,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Appearance Section
                    const Text(
                      "APPEARANCE",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black38,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAppearanceCard(
                          label: "Light",
                          isSelected: _appearance == "Light",
                          cardColor: Colors.white,
                          borderColor: Colors.grey.shade300,
                          checkColor: Colors.black87,
                          onTap: () {
                            setState(() {
                              _appearance = "Light";
                            });
                            setSheetState(() {});
                          },
                        ),
                        _buildAppearanceCard(
                          label: "Sepia",
                          isSelected: _appearance == "Sepia",
                          cardColor: const Color(0xFFFDFBF7),
                          borderColor: const Color(0xFF0729E8),
                          checkColor: const Color(0xFF0729E8),
                          onTap: () {
                            setState(() {
                              _appearance = "Sepia";
                            });
                            setSheetState(() {});
                          },
                        ),
                        _buildAppearanceCard(
                          label: "Dark",
                          isSelected: _appearance == "Dark",
                          cardColor: const Color(0xFF2C2C2C),
                          borderColor: Colors.transparent,
                          checkColor: Colors.white,
                          onTap: () {
                            setState(() {
                              _appearance = "Dark";
                            });
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFontChip({
    required String label,
    required bool isSelected,
    required String? fontName,
    required VoidCallback onTap,
  }) {
    TextStyle fontLabelStyle = TextStyle(
      fontSize: 12,
      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
      color: isSelected ? const Color(0xFF0729E8) : Colors.black87,
    );
    if (fontName != null) {
      try {
        fontLabelStyle = GoogleFonts.getFont(fontName, textStyle: fontLabelStyle);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0729E8).withOpacity(0.08)
              : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0729E8) : Colors.transparent,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(label, style: fontLabelStyle),
      ),
    );
  }

  Widget _buildAppearanceCard({
    required String label,
    required bool isSelected,
    required Color cardColor,
    required Color borderColor,
    required Color checkColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 48,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? borderColor : Colors.grey.shade300,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Icon(Icons.check, color: checkColor, size: 20),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showPageGridBottomSheet(BuildContext context) {
    const brandColor = Color(0xFF0729E8);
    
    Color sheetBg;
    Color sheetTextColor;
    Color gridItemBg;
    Color gridItemTextColor;

    switch (_appearance) {
      case "Light":
        sheetBg = Colors.white;
        sheetTextColor = const Color(0xFF1E1E1E);
        gridItemBg = const Color(0xFFF2F4F7);
        gridItemTextColor = const Color(0xFF1E1E1E);
        break;
      case "Dark":
        sheetBg = const Color(0xFF1E1E1E);
        sheetTextColor = const Color(0xFFE0E0E0);
        gridItemBg = const Color(0xFF2C2C2C);
        gridItemTextColor = const Color(0xFFE0E0E0);
        break;
      case "Sepia":
      default:
        sheetBg = const Color(0xFFFDFBF7);
        sheetTextColor = const Color(0xFF2C2C2C);
        gridItemBg = const Color(0xFFE5DDD3);
        gridItemTextColor = const Color(0xFF2C2C2C);
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: sheetTextColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Header
                Text(
                  "Table of Contents",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'serif',
                    color: sheetTextColor,
                  ),
                ),
                const SizedBox(height: 20),
                // Grid of Pages
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _currentPage;
                      return GestureDetector(
                        onTap: () {
                          _pageController.jumpToPage(index);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? brandColor : gridItemBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "${index + 1}",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : gridItemTextColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _pages.length;

    Color scaffoldBg;
    Color cardBg;
    Color textColor;
    Color appBarTextColor;
    Color shadowColor;
    double shadowOpacity;
    Color spineShadowColor;
    Color pageNumColor;

    switch (_appearance) {
      case "Light":
        scaffoldBg = const Color(0xFFF2F4F7);
        cardBg = Colors.white;
        textColor = const Color(0xFF1E1E1E);
        appBarTextColor = const Color(0xFF2C2C2C);
        shadowColor = Colors.black;
        shadowOpacity = 0.05;
        spineShadowColor = Colors.black.withOpacity(0.08);
        pageNumColor = Colors.grey.shade400;
        break;
      case "Dark":
        scaffoldBg = const Color(0xFF121212);
        cardBg = const Color(0xFF1E1E1E);
        textColor = const Color(0xFFE0E0E0);
        appBarTextColor = Colors.white;
        shadowColor = Colors.black;
        shadowOpacity = 0.3;
        spineShadowColor = Colors.black.withOpacity(0.2);
        pageNumColor = Colors.grey.shade600;
        break;
      case "Sepia":
      default:
        scaffoldBg = const Color(0xFFE5DDD3);
        cardBg = const Color(0xFFFDFBF7);
        textColor = const Color(0xFF2C2C2C);
        appBarTextColor = const Color(0xFF2C2C2C);
        shadowColor = Colors.black;
        shadowOpacity = 0.06;
        spineShadowColor = Colors.black.withOpacity(0.1);
        pageNumColor = Colors.grey.shade400;
        break;
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              "Reading",
              style: TextStyle(
                color: appBarTextColor,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            if (totalPages > 0)
              GestureDetector(
                onTap: () => _showPageGridBottomSheet(context),
                child: Text(
                  "Page ${_currentPage + 1} of $totalPages",
                  style: const TextStyle(
                    color: Color(0xFF0729E8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: appBarTextColor, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Text(
              "A",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                fontFamily: 'serif',
                color: appBarTextColor,
              ),
            ),
            onPressed: () => _showSettingsBottomSheet(context),
          ),
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: appBarTextColor, size: 24),
            onPressed: () {
              final shareUrl = "${ApiConfig.baseUrl}/share/post/${widget.postId}";
              final deepLink = "Ritpen://post/${widget.postId}";
              Share.share("Check out this story on Ritpen: '${widget.postTitle}'\n\nRead here: $shareUrl\nOpen in App: $deepLink");
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: totalPages == 0
          ? Center(
              child: Text(
                "This story has no pages.",
                style: TextStyle(color: textColor, fontSize: 16),
              ),
            )
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: totalPages,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    _saveLastReadPage(index);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];

                    return Container(
                      margin: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(context).bottom),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor.withOpacity(shadowOpacity),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Left spine shadow for realistic book page look
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      spineShadowColor.withOpacity(0.8),
                                      spineShadowColor.withOpacity(0.3),
                                      Colors.transparent
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ),
                            // Content
                            SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(45, 40, 35, 60),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...(page['blocks'] as List? ?? []).map<Widget>((block) {
                                    if (block['type'] == "text") {
                                      final textStyle = _resolveTextStyle(
                                        block: block,
                                        page: page,
                                        defaultTextColor: textColor,
                                      );
                                      final textAlign = _resolveTextAlign(block, page);

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            block['text'] ?? "",
                                            textAlign: textAlign,
                                            style: textStyle,
                                          ),
                                        ),
                                      );
                                    }
                                    if (block['type'] == "image" && block['image'] != null && block['image'].toString().isNotEmpty) {
                                      final imgPath = block['image'].toString();
                                      final fullImgUrl = imgPath.startsWith("http")
                                          ? imgPath
                                          : "${ApiConfig.baseUrl}/uploads/page_images/$imgPath";

                                      return ExpandablePostImage(imageUrl: fullImgUrl);
                                    }
                                    return const SizedBox();
                                  }),
                                ],
                              ),
                            ),
                            // Page bottom indicator
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  "— Page ${index + 1} —",
                                  style: TextStyle(
                                    color: pageNumColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

// ==========================================
// COMMENTS BOTTOM SHEET WIDGET
// ==========================================
class CommentsSheetContent extends StatefulWidget {
  final String postId;
  final Color brandColor;
  final VoidCallback? onCommentChanged;

  static final Map<String, int> commentCounts = {};
  static Map<String, int> get commentCountsCache => commentCounts;

  const CommentsSheetContent({
    super.key,
    required this.postId,
    required this.brandColor,
    this.onCommentChanged,
  });

  static int getCommentCount(String postId, {int fallback = 0}) {
    return commentCounts[postId] ?? fallback;
  }

  static void setCommentCount(String postId, int count) {
    commentCounts[postId] = count;
  }

  @override
  State<CommentsSheetContent> createState() => _CommentsSheetContentState();
}

class _CommentsSheetContentState extends State<CommentsSheetContent> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _replyingToComment;

  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  String? _userId;
  String? _authToken;
  String _currentUsername = "";
  String? _currentUserAvatar;

  static String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    path = path.trim();
    if (path.startsWith('http')) return path;
    path = path.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    return "${ApiConfig.baseUrl}/$path";
  }

  static String _getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return "U";
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  static String _formatCommentTime(dynamic rawDate, [String? fallback]) {
    if (rawDate == null) return fallback ?? "";
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return "Just now";
      if (diff.inHours < 1) return "${diff.inMinutes}m ago";
      if (diff.inDays < 1) return "${diff.inHours}h ago";
      if (diff.inDays < 7) return "${diff.inDays}d ago";
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return fallback ?? rawDate.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserAndComments();
  }

  Future<void> _loadUserAndComments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString("user_id");
      _authToken = prefs.getString("token");
      _currentUsername = (prefs.getString("username") ??
              prefs.getString("user_name") ??
              prefs.getString("name") ??
              "")
          .trim();
      _currentUserAvatar = prefs.getString("profile_image") ??
          prefs.getString("profile_image_url") ??
          prefs.getString("profileImage");
    } catch (_) {}

    await _fetchComments();
  }

  Future<void> _fetchComments() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final queryParam = (_userId != null && _userId!.isNotEmpty) ? "?userId=$_userId" : "";
      final uri = Uri.parse("${ApiConfig.apiBaseUrl}/posts/${widget.postId}/comments$queryParam");
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List? rawList;
        int totalCount = 0;
        if (decoded is Map) {
          if (decoded['comments'] is List) {
            rawList = decoded['comments'];
            totalCount = (decoded['count'] as num?)?.toInt() ?? (rawList?.length ?? 0);
          } else if (decoded['data'] is Map && decoded['data']['comments'] is List) {
            rawList = decoded['data']['comments'];
            totalCount = (decoded['data']['count'] as num?)?.toInt() ?? (rawList?.length ?? 0);
          } else if (decoded['data'] is List) {
            rawList = decoded['data'];
            totalCount = rawList?.length ?? 0;
          }
        } else if (decoded is List) {
          rawList = decoded;
          totalCount = decoded.length;
        }

        if (rawList != null) {
          final loaded = List<Map<String, dynamic>>.from(
            rawList.map((c) => Map<String, dynamic>.from(c as Map)),
          );
          CommentsSheetContent.setCommentCount(widget.postId, totalCount);
          if (mounted) {
            setState(() {
              _comments = loaded;
              _isLoading = false;
            });
            widget.onCommentChanged?.call();
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final parentId = _replyingToComment != null ? _replyingToComment!['_id']?.toString() : null;
    final myName = _currentUsername.isNotEmpty ? _currentUsername : "Ritpen User";

    final tempComment = <String, dynamic>{
      "_id": "temp_${DateTime.now().millisecondsSinceEpoch}",
      "user_id": _userId ?? "",
      "userId": _userId ?? "",
      "username": myName,
      "profile_image": _currentUserAvatar ?? "",
      "createdAt": DateTime.now().toIso8601String(),
      "text": text,
      "isLiked": false,
      "likes_count": 0,
      "replies": <Map<String, dynamic>>[],
    };

    setState(() {
      if (_replyingToComment != null) {
        if (_replyingToComment!['replies'] == null) {
          _replyingToComment!['replies'] = <Map<String, dynamic>>[];
        }
        (_replyingToComment!['replies'] as List).add(tempComment);
        _replyingToComment = null;
      } else {
        _comments.insert(0, tempComment);
      }
      _commentController.clear();
      final current = CommentsSheetContent.getCommentCount(widget.postId);
      CommentsSheetContent.setCommentCount(widget.postId, current + 1);
    });

    widget.onCommentChanged?.call();

    if (parentId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    try {
        final Map<String, dynamic> payload = {
          "text": text,
          "message": text,
          "comment": text,
          "userId": _userId ?? "",
          "username": myName,
          "profileImage": _currentUserAvatar ?? "",
        };
        if (parentId != null) {
          payload["parentCommentId"] = parentId;
        }
        final res = await http.post(
          Uri.parse("${ApiConfig.apiBaseUrl}/posts/${widget.postId}/comments"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);
        Map<String, dynamic>? savedComment;
        if (data is Map) {
          if (data['comment'] is Map) {
            savedComment = Map<String, dynamic>.from(data['comment']);
          } else if (data['data'] is Map) {
            savedComment = Map<String, dynamic>.from(data['data']);
          }
        }
        if (savedComment != null && mounted) {
          setState(() {
            tempComment['_id'] = savedComment!['_id'] ?? savedComment['id'];
          });
        }
        _fetchComments();
      }
    } catch (_) {}
  }

  Future<void> _toggleCommentLike(Map<String, dynamic> comment) async {
    final commentId = comment['_id']?.toString() ?? "";
    final currentLiked = comment['isLiked'] == true;
    final currentCount = (comment['likes_count'] as num?)?.toInt() ?? 0;

    setState(() {
      comment['isLiked'] = !currentLiked;
      comment['likes_count'] = currentLiked ? (currentCount - 1).clamp(0, 999999) : (currentCount + 1);
    });

    if (commentId.isEmpty || commentId.startsWith("temp_")) return;

    try {
      await http.post(
        Uri.parse("${ApiConfig.apiBaseUrl}/posts/comments/$commentId/toggleLike"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": _userId ?? "",
        }),
      );
    } catch (_) {}
  }

  void _confirmDeleteComment(Map<String, dynamic> comment, {Map<String, dynamic>? parentComment}) {
    final commentUserId = (comment['user_id'] ?? comment['userId'])?.toString();
    final commentUsername = (comment['username'] ?? '').toString().trim();

    final isTemp = (comment['_id'] ?? comment['id'])?.toString().startsWith('temp_') == true;
    final isMyComment = isTemp ||
        (_userId != null && _userId!.isNotEmpty && commentUserId == _userId) ||
        (_currentUsername.isNotEmpty &&
            commentUsername.isNotEmpty &&
            commentUsername.toLowerCase() == _currentUsername.toLowerCase());

    if (!isMyComment) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
                title: const Text(
                  'Delete Comment',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteComment(comment, parentComment: parentComment);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteComment(Map<String, dynamic> comment, {Map<String, dynamic>? parentComment}) async {
    final commentId = (comment['_id'] ?? comment['id'] ?? comment['comment_id'])?.toString();
    if (commentId == null) return;

    // Optimistically remove from state
    setState(() {
      if (parentComment != null) {
        final replies = parentComment['replies'] as List?;
        replies?.removeWhere((r) => (r['_id'] ?? r['id'] ?? r['comment_id'])?.toString() == commentId);
      } else {
        _comments.removeWhere((c) => (c['_id'] ?? c['id'] ?? c['comment_id'])?.toString() == commentId);
      }
    });

    final currentCount = CommentsSheetContent.getCommentCount(widget.postId);
    if (currentCount > 0) {
      CommentsSheetContent.setCommentCount(widget.postId, currentCount - 1);
    }
    widget.onCommentChanged?.call();

    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/posts/comments/$commentId');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken!.isNotEmpty) 'Authorization': 'Bearer $_authToken',
      };
      await http.delete(uri, headers: headers);
    } catch (e) {
      debugPrint('[Delete comment error]: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comments = _comments;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle & Title
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48),
                      Text(
                        "Comments (${CommentsSheetContent.getCommentCount(widget.postId)})",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Comments List or Loader
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: widget.brandColor),
                    )
                  : comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: widget.brandColor.withOpacity(0.4),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No comments yet",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Be the first to share your thoughts!",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: comments.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 24,
                            color: Color(0xFFF2F4F7),
                          ),
                          itemBuilder: (context, index) {
                            final item = comments[index];
                            final bool commentLiked = item['isLiked'] == true;
                            final int likesCount = (item['likes_count'] as num?)?.toInt() ?? 0;
                            final List<dynamic> replies = item['replies'] ?? [];
                            final String itemAvatar = item['profile_image']?.toString() ?? '';
                            final String itemName = item['username']?.toString() ?? 'Anonymous';

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () => _confirmDeleteComment(item),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: widget.brandColor.withOpacity(0.1),
                                        backgroundImage: itemAvatar.isNotEmpty
                                            ? CachedNetworkImageProvider(_fullUrl(itemAvatar))
                                            : null,
                                        child: itemAvatar.isEmpty
                                            ? Text(
                                                _getInitials(itemName),
                                                style: TextStyle(
                                                  color: widget.brandColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  itemName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _formatCommentTime(item['createdAt'], item['timeAgo']),
                                                  style: const TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (item['text'] ?? item['message'] ?? item['comment'] ?? '').toString(),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textPrimary,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            // Reply button
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _replyingToComment = item;
                                                });
                                              },
                                              child: Text(
                                                "Reply",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: widget.brandColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _toggleCommentLike(item),
                                        behavior: HitTestBehavior.opaque,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                commentLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                                                color: commentLiked ? widget.brandColor : AppColors.textSecondary,
                                                size: 16,
                                              ),
                                              if (likesCount > 0) ...[
                                                const SizedBox(width: 3),
                                                Text(
                                                  "$likesCount",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: commentLiked ? widget.brandColor : AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Nested Replies Indented
                                  if (replies.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 36),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: replies.length,
                                        separatorBuilder: (context, rIndex) => const SizedBox(height: 12),
                                        itemBuilder: (context, rIndex) {
                                          final reply = Map<String, dynamic>.from(replies[rIndex] as Map);
                                          final bool replyLiked = reply['isLiked'] == true;
                                          final int replyLikesCount = (reply['likes_count'] as num?)?.toInt() ?? 0;
                                          final String replyAvatar = reply['profile_image']?.toString() ?? '';
                                          final String replyName = reply['username']?.toString() ?? 'Anonymous';

                                          return GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onLongPress: () => _confirmDeleteComment(reply, parentComment: item),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor: widget.brandColor.withOpacity(0.1),
                                                  backgroundImage: replyAvatar.isNotEmpty
                                                      ? CachedNetworkImageProvider(_fullUrl(replyAvatar))
                                                      : null,
                                                  child: replyAvatar.isEmpty
                                                      ? Text(
                                                          _getInitials(replyName),
                                                          style: TextStyle(
                                                            color: widget.brandColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 9,
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.center,
                                                        children: [
                                                          Text(
                                                            replyName,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 11,
                                                              color: AppColors.textPrimary,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            _formatCommentTime(reply['createdAt'], reply['timeAgo']),
                                                            style: const TextStyle(
                                                              color: AppColors.textSecondary,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        (reply['text'] ?? reply['message'] ?? reply['comment'] ?? '').toString(),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AppColors.textPrimary,
                                                          height: 1.3,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () => _toggleCommentLike(reply),
                                                  behavior: HitTestBehavior.opaque,
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          replyLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                                                          color: replyLiked ? widget.brandColor : AppColors.textSecondary,
                                                          size: 13,
                                                        ),
                                                        if (replyLikesCount > 0) ...[
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            "$replyLikesCount",
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: replyLiked ? widget.brandColor : AppColors.textSecondary,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Replying To Banner
            if (_replyingToComment != null)
              Container(
                color: widget.brandColor.withOpacity(0.05),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Replying to @${_replyingToComment!['username']}",
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.brandColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyingToComment = null;
                        });
                      },
                      child: const Icon(
                        Icons.cancel_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom Sticky Text Input Bar
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: widget.brandColor.withOpacity(0.1),
                      backgroundImage: (_currentUserAvatar != null && _currentUserAvatar!.isNotEmpty)
                          ? CachedNetworkImageProvider(_fullUrl(_currentUserAvatar))
                          : null,
                      child: (_currentUserAvatar == null || _currentUserAvatar!.isEmpty)
                          ? Text(
                              _getInitials(_currentUsername),
                              style: TextStyle(
                                color: widget.brandColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE4E7EC),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: "Add a comment...",
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          onSubmitted: (_) => _addComment(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _addComment,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.brandColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: widget.brandColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

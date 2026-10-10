import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/home.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dmk_project/saved_posts_manager.dart';

class HashtagPage extends StatefulWidget {
  const HashtagPage({super.key});

  @override
  State<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends State<HashtagPage> {
  List<Map<String, dynamic>> hashtags = [];
  String searchText = "";
  bool isLoading = true;
  final TextEditingController _controller = TextEditingController();

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  @override
  void initState() {
    super.initState();
    fetchHashtags();
  }

  Future<void> fetchHashtags() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.apiBaseUrl}/posts/hashtags/trending"),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          setState(() {
            hashtags = List<Map<String, dynamic>>.from(
              (decoded['data'] as List).map((e) => {
                "hashtag": e["tag"],
                "count": e["count"],
              })
            );
          });
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = hashtags
        .where(
          (i) => i["hashtag"].toString().toLowerCase().contains(
            searchText.toLowerCase(),
          ),
        )
        .toList();

    return Scaffold(
      appBar: appBar('Explore'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: appSearchField(
              controller: _controller,
              hint: 'Search hashtags...',
              onChanged: (v) => setState(() => searchText = v),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? appEmptyState(
                        icon: Icons.tag_rounded,
                        title: 'No hashtags yet',
                        subtitle: 'Trending tags will show up here',
                      )
                    : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: filtered.map((item) {
                          return GestureDetector(
                            onTap: () {
                              final route = Platform.isIOS
                                  ? CupertinoPageRoute(
                                      builder: (_) => HashtagPostsPage(
                                        tag: item["hashtag"],
                                      ),
                                    )
                                  : MaterialPageRoute(
                                      builder: (_) => HashtagPostsPage(
                                        tag: item["hashtag"],
                                      ),
                                    );
                              Navigator.push(context, route);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: appCardDecoration(radius: AppRadius.md),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.tag_rounded,
                                      color: AppColors.brand,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item["hashtag"],
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1A1A1A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${item["count"]} stories published",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.grey.shade300,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
          ),
        ],
      ),
      // ✅ Bottom nav removed — handled by MainShell (IndexedStack)
    );
  }

  // ✅ _buildBottomNavigationBar and _build3DNavItem removed
  // — navigation is now handled by MainShell (IndexedStack)
}


class HashtagPostsPage extends StatefulWidget {
  final String tag;
  final String? category;

  const HashtagPostsPage({super.key, required this.tag, this.category});

  @override
  State<HashtagPostsPage> createState() => _HashtagPostsPageState();
}

class _HashtagPostsPageState extends State<HashtagPostsPage> {
  List posts = [];
  bool isLoading = true;

  Set<String> likedPosts = {};
  Set<String> savedPosts = {};

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  @override
  void initState() {
    super.initState();
    SavedPostsManager.instance.addListener(_onSavedChanged);
    _loadInteractionsLocal(); // 🔥 Load from cache immediately
    fetchPosts();
    fetchUserInteractions();
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SavedPostsManager.instance.removeListener(_onSavedChanged);
    super.dispose();
  }

  Future<void> fetchUserInteractions() async {
    await _loadInteractionsLocal();
  }

  Future<void> _loadInteractionsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      likedPosts = (prefs.getStringList('cached_liked_posts') ?? []).toSet();
      savedPosts = (prefs.getStringList('cached_saved_posts') ?? []).toSet();
    });
  }

  Future<void> _saveInteractionsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cached_liked_posts', likedPosts.toList());
    await prefs.setStringList('cached_saved_posts', savedPosts.toList());
  }

  Future<void> fetchPosts() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });
    try {
      final tag = widget.tag.startsWith('#') ? widget.tag : '#${widget.tag}';
      final encodedTag = Uri.encodeComponent(tag);
      final response = await http.get(
        Uri.parse("${ApiConfig.apiBaseUrl}/posts?search=$encodedTag"),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          setState(() {
            posts = List<Map<String, dynamic>>.from(
              (decoded['data'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            );
          });
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> toggleLike(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to like stories")),
      );
      return;
    }

    final bool isAlreadyLiked = likedPosts.contains(postId);

    setState(() {
      if (isAlreadyLiked) {
        likedPosts.remove(postId);
      } else {
        likedPosts.add(postId);
      }

      for (var p in posts) {
        if (p['post_id']?.toString() == postId) {
          int currentCount =
              int.tryParse(p['support_count']?.toString() ?? '0') ?? 0;
          p['support_count'] = isAlreadyLiked
              ? (currentCount - 1).clamp(0, 999999)
              : (currentCount + 1);
          break;
        }
      }
    });

    await _saveInteractionsLocal();

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.apiBaseUrl}/posts/toggleSupport/$postId"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode != 200) {
        // Revert
        setState(() {
          if (isAlreadyLiked) {
            likedPosts.add(postId);
          } else {
            likedPosts.remove(postId);
          }
          for (var p in posts) {
            if (p['post_id']?.toString() == postId) {
              int currentCount =
                  int.tryParse(p['support_count']?.toString() ?? '0') ?? 0;
              p['support_count'] = isAlreadyLiked
                  ? (currentCount + 1)
                  : (currentCount - 1).clamp(0, 999999);
              break;
            }
          }
        });
        await _saveInteractionsLocal();
      }
    } catch (_) {
      // Revert
      setState(() {
        if (isAlreadyLiked) {
          likedPosts.add(postId);
        } else {
          likedPosts.remove(postId);
        }
        for (var p in posts) {
          if (p['post_id']?.toString() == postId) {
            int currentCount =
                int.tryParse(p['support_count']?.toString() ?? '0') ?? 0;
            p['support_count'] = isAlreadyLiked
                ? (currentCount + 1)
                : (currentCount - 1).clamp(0, 999999);
            break;
          }
        }
      });
      await _saveInteractionsLocal();
    }
  }

  void toggleSave(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final userId = prefs.getString("user_id") ?? "";
    if (token.isEmpty && userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to bookmark stories")),
      );
      return;
    }

    final postObj = posts.firstWhere(
      (p) => (p['post_id'] ?? p['_id'])?.toString() == postId,
      orElse: () => null,
    );

    await SavedPostsManager.instance.toggleSave(
      postId: postId,
      userId: userId,
      token: token,
      postData: postObj != null ? Map<String, dynamic>.from(postObj) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagLabel = widget.tag.startsWith('#') ? widget.tag : '#${widget.tag}';

    return Scaffold(
      appBar: AppBar(
        title: Text(tagLabel),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
          ? appEmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'No stories for $tagLabel',
              subtitle: 'Try another hashtag',
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 20),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                final postId = (post['post_id'] ?? post['_id'])?.toString() ?? '';

                return PostContainer(
                  post: post,
                  isLiked: likedPosts.contains(postId),
                  onLike: () => toggleLike(postId),
                  isSaved: SavedPostsManager.instance.isSaved(postId),
                  onSave: () => toggleSave(postId),
                  currentCategory: widget.category ?? 'All',
                );
              },
            ),
    );
  }
}

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

List<dynamic> parsePages(String content) {
  return jsonDecode(content);
}

class _PostDetailPageState extends State<PostDetailPage> {
  List<dynamic> pages = [];
  String? coverImg;
  String? caption;
  bool loading = true;

  int currentPage = 0;
  final PageController _pageController = PageController(initialPage: 0);

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  Future<void> _loadPost() async {
    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF0729E8);
    final totalPages = pages.length;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              "Reading",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontFamily: 'serif',
              ),
            ),
            Text(
              "Page ${currentPage + 1} of $totalPages",
              style: TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: brandColor))
          : Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: totalPages,
                    onPageChanged: (index) {
                      setState(() => currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      final fontSize = (page['fontSize'] ?? 18).toDouble();
                      final fontFamily = page['fontFamily'] ?? 'Roboto';
                      final fontColor = _parseColor(page['fontColor']);

                      return SizedBox.expand(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 75),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDFBF7),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 25,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 35,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.black.withOpacity(0.18),
                                          Colors.black.withOpacity(0.08),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: 0.02,
                                    child: Image.network(
                                      "https://www.transparenttextures.com/patterns/paper-fibers.png",
                                      repeat: ImageRepeat.repeat,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(),
                                    ),
                                  ),
                                ),
                                SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      55,
                                      50,
                                      40,
                                      70,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ...(page['blocks'] as List? ?? []).map<
                                          Widget
                                        >((block) {
                                          if (block['type'] == "text") {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 20,
                                              ),
                                              child: Text(
                                                block['text'] ?? "",
                                                style: TextStyle(
                                                  fontSize: fontSize,
                                                  fontFamily: fontFamily,
                                                  color: fontColor.withOpacity(
                                                    0.9,
                                                  ),
                                                  height: 1.7,
                                                  letterSpacing: 0.4,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            );
                                          }
                                          if (block['type'] == "image" &&
                                              block['image'] != null &&
                                              block['image']
                                                  .toString()
                                                  .isNotEmpty) {
                                            return ExpandablePostImage(
                                              imageUrl:
                                                  "${ApiConfig.baseUrl}/${block['image']}",
                                            );
                                          }
                                          return const SizedBox();
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 24,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Text(
                                      "— ${index + 1} of $totalPages —",
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        letterSpacing: 1.2,
                                        fontFamily: 'serif',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Color _parseColor(dynamic colorValue) {
    try {
      if (colorValue == null) return Colors.black;
      return Color(int.parse(colorValue.toString()));
    } catch (_) {
      return Colors.black;
    }
  }
}

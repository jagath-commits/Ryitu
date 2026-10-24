import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/community_page.dart';
import 'package:dmk_project/notification_post_page.dart';
import 'package:dmk_project/services/notification_badge_manager.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _unreadCount = 0;
  int _page = 1;
  bool _hasMore = true;
  String? _userId;
  String? _authToken;
  final ScrollController _scrollController = ScrollController();
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    NotificationBadgeManager.instance.refreshTick.addListener(_onLiveUpdateTriggered);
    // Poll every 8 seconds while user has the notifications screen open
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        _fetchNotifications(refresh: true, silent: true);
      }
    });
    _loadUserAndFetchNotifications();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    NotificationBadgeManager.instance.refreshTick.removeListener(_onLiveUpdateTriggered);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLiveUpdateTriggered() {
    if (mounted) {
      _fetchNotifications(refresh: true, silent: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadUserAndFetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? 'USR00000001';
    _authToken = prefs.getString('token') ?? '';
    await _fetchNotifications(refresh: true);
  }

  Future<void> _fetchNotifications({bool refresh = false, bool silent = false}) async {
    if (refresh && !silent) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _isLoading = true;
      });
    }

    try {
      final targetPage = refresh ? 1 : _page;
      final uri = Uri.parse(
          '${ApiConfig.apiBaseUrl}/notifications?userId=$_userId&page=$targetPage&limit=25');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken!.isNotEmpty)
          'Authorization': 'Bearer $_authToken',
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = decoded['data'];
          final rawList = data['notifications'] as List? ?? [];
          final newItems = List<Map<String, dynamic>>.from(rawList);
          final serverUnread = data['unreadCount'] ?? 0;

          setState(() {
            if (refresh) {
              _notifications.clear();
              _page = 1;
            }
            _notifications.addAll(newItems);
            _unreadCount = serverUnread;
            final pagination = data['pagination'];
            if (pagination != null) {
              final totalPages = pagination['totalPages'] ?? 1;
              _hasMore = _page < totalPages;
            } else {
              _hasMore = newItems.isNotEmpty;
            }
          });

          // Keep badge manager in sync
          NotificationBadgeManager.instance.setUnreadCount(serverUnread);
        }
      }
    } catch (e) {
      debugPrint('[Notifications fetch error]: $e');
    } finally {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _page++;
    });
    await _fetchNotifications(refresh: false);
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final notifId = notification['id'] ?? notification['_id'];
    if (notifId == null || notification['isRead'] == true) return;

    // Optimistically update UI
    setState(() {
      notification['isRead'] = true;
      if (_unreadCount > 0) _unreadCount--;
    });
    NotificationBadgeManager.instance.decrementUnreadCount(1);

    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/notifications/$notifId/read');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken!.isNotEmpty)
          'Authorization': 'Bearer $_authToken',
      };
      await http.put(uri, headers: headers, body: jsonEncode({'userId': _userId}));
    } catch (e) {
      debugPrint('[Mark read error]: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_notifications.isEmpty || _unreadCount == 0) return;

    setState(() {
      for (final n in _notifications) {
        n['isRead'] = true;
      }
      _unreadCount = 0;
    });
    NotificationBadgeManager.instance.markAllRead();

    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/notifications/mark-all-read');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken!.isNotEmpty)
          'Authorization': 'Bearer $_authToken',
      };
      await http.post(uri, headers: headers, body: jsonEncode({'userId': _userId}));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.brand,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Mark all read error]: $e');
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification, int index) async {
    final notifId = notification['id'] ?? notification['_id'];
    if (notifId == null) return;

    setState(() {
      _notifications.removeAt(index);
      if (notification['isRead'] != true && _unreadCount > 0) {
        _unreadCount--;
      }
    });

    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/notifications/$notifId?userId=$_userId');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken!.isNotEmpty)
          'Authorization': 'Bearer $_authToken',
      };
      await http.delete(uri, headers: headers);
    } catch (e) {
      debugPrint('[Delete notification error]: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    _markAsRead(notification);

    final postId = (notification['postId'] ?? notification['post_id'])?.toString();
    final communityId = (notification['communityId'] ?? notification['community_id'])?.toString();

    if (postId != null && postId.isNotEmpty && postId != 'null') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationPostPage(postId: postId),
        ),
      );
    } else if (communityId != null && communityId.isNotEmpty && communityId != 'null') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityPage(communityId: communityId),
        ),
      );
    }
  }

  String _formatTimestamp(dynamic rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d, y').format(dt);
    } catch (_) {
      return '';
    }
  }

  Widget _buildTypeBadge(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'new_post':
        icon = Icons.article_rounded;
        color = const Color(0xFF0729E8);
        break;
      case 'post_like':
        icon = Icons.favorite_rounded;
        color = const Color(0xFFE53935);
        break;
      case 'post_comment':
        icon = Icons.chat_bubble_rounded;
        color = const Color(0xFFFB8C00);
        break;
      case 'community_member_added':
        icon = Icons.group_add_rounded;
        color = const Color(0xFF43A047);
        break;
      case 'community_join_request':
        icon = Icons.person_add_alt_1_rounded;
        color = const Color(0xFF8E24AA);
        break;
      case 'community_join_approved':
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF2E7D32);
        break;
      case 'community_join_rejected':
        icon = Icons.cancel_rounded;
        color = const Color(0xFF757575);
        break;
      default:
        icon = Icons.notifications_rounded;
        color = AppColors.brand;
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Icon(icon, size: 10, color: Colors.white),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> notification) {
    final actorImage = notification['actorImage']?.toString() ?? '';
    final actorName = notification['actorName']?.toString().trim() ?? 'U';
    final initial = actorName.isNotEmpty ? actorName[0].toUpperCase() : 'U';
    final type = notification['type']?.toString() ?? '';

    String? fullImageUrl;
    if (actorImage.isNotEmpty) {
      if (actorImage.startsWith('http')) {
        fullImageUrl = actorImage;
      } else {
        fullImageUrl = '${ApiConfig.baseUrl}/uploads/profile_images/$actorImage';
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFE8EEFF),
          backgroundImage: (fullImageUrl != null)
              ? CachedNetworkImageProvider(fullImageUrl)
              : null,
          child: (fullImageUrl == null)
              ? Text(
                  initial,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: _buildTypeBadge(type),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notifications',
              style: GoogleFonts.outfit(
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_notifications.isNotEmpty && _unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchNotifications(refresh: true),
        color: AppColors.brand,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brand),
              )
            : _notifications.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 0.8,
                      color: Color(0xFFEDF0F3),
                    ),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                        );
                      }

                      final notif = _notifications[index];
                      final isRead = notif['isRead'] == true;

                      return Dismissible(
                        key: Key(notif['id'] ?? notif['_id'] ?? '$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteNotification(notif, index),
                        child: Material(
                          color: isRead
                              ? Colors.white
                              : const Color(0xFFF3F6FD),
                          child: InkWell(
                            onTap: () => _handleNotificationTap(notif),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAvatar(notif),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notif['title'] ?? 'Notification',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: isRead
                                                      ? FontWeight.w600
                                                      : FontWeight.w800,
                                                  color: const Color(0xFF1A1A1A),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatTimestamp(notif['createdAt']),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notif['body'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.35,
                                            color: isRead
                                                ? const Color(0xFF555555)
                                                : const Color(0xFF222222),
                                            fontWeight: isRead
                                                ? FontWeight.w400
                                                : FontWeight.w500,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isRead) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 6),
                                      decoration: const BoxDecoration(
                                        color: AppColors.brand,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Notifications Yet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When other readers like your stories, leave comments, or add you to communities, you will see them here.',
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
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/home.dart';
import 'package:dmk_project/saved_posts_manager.dart';
import 'package:dmk_project/liked_posts_manager.dart';

String formatCommunityImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  final trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    if (trimmed.contains('localhost') || trimmed.contains('127.0.0.1')) {
      try {
        final uri = Uri.parse(trimmed);
        final baseUri = Uri.parse(ApiConfig.baseUrl);
        return uri.replace(scheme: baseUri.scheme, host: baseUri.host, port: baseUri.port).toString();
      } catch (_) {
        return trimmed;
      }
    }
    return trimmed;
  }
  if (trimmed.startsWith('uploads/')) {
    return '${ApiConfig.baseUrl}/$trimmed';
  }
  return '${ApiConfig.baseUrl}/uploads/community_images/$trimmed';
}

// ==========================================
// 1. COMMUNITIES LIST & EXPLORE PAGE
// ==========================================
class CommunitiesListPage extends StatefulWidget {
  const CommunitiesListPage({super.key});

  @override
  State<CommunitiesListPage> createState() => _CommunitiesListPageState();
}

class _CommunitiesListPageState extends State<CommunitiesListPage> {
  List<Map<String, dynamic>> _allCommunities = [];
  List<Map<String, dynamic>> _createdCommunities = [];
  List<Map<String, dynamic>> _joinedCommunities = [];
  bool _isLoading = true;
  String? _userId;
  String _selectedFilter = 'all'; // 'all', 'created', or 'joined'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? 'USR00000001';
    await _fetchCommunities();
  }

  Future<void> _fetchCommunities() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch All Communities
      final allUri = Uri.parse('${ApiConfig.apiBaseUrl}/communities');
      final allRes = await http.get(allUri);
      if (allRes.statusCode == 200) {
        final decoded = jsonDecode(allRes.body);
        if (decoded['success'] == true && decoded['data']?['communities'] is List) {
          _allCommunities = List<Map<String, dynamic>>.from(decoded['data']['communities']);
          _allCommunities.sort((a, b) {
            final dtA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dtB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dtB.compareTo(dtA);
          });
        }
      }

      // 2. Fetch My Joined/Created Communities (Separated by Created and Joined)
      final myUri = Uri.parse('${ApiConfig.apiBaseUrl}/communities/my-communities?userId=$_userId');
      final myRes = await http.get(myUri);
      if (myRes.statusCode == 200) {
        final decoded = jsonDecode(myRes.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final data = decoded['data'];
          if (data['createdCommunities'] is List) {
            _createdCommunities = List<Map<String, dynamic>>.from(data['createdCommunities']);
          }
          if (data['joinedCommunities'] is List) {
            _joinedCommunities = List<Map<String, dynamic>>.from(data['joinedCommunities']);
          }

          // Fallback if data is in older format
          if (_createdCommunities.isEmpty && _joinedCommunities.isEmpty && data['communities'] is List) {
            final allMy = List<Map<String, dynamic>>.from(data['communities']);
            _createdCommunities = allMy.where((c) =>
                c['creatorId']?.toString() == _userId || c['isCreator'] == true).toList();
            _joinedCommunities = allMy.where((c) =>
                c['creatorId']?.toString() != _userId && c['isCreator'] != true).toList();
          }

          _createdCommunities.sort((a, b) {
            final dtA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dtB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dtB.compareTo(dtA);
          });

          _joinedCommunities.sort((a, b) {
            final dtA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dtB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dtB.compareTo(dtA);
          });
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestJoinCommunity(String commId) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/communities/$commId/request-join');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': _userId}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Join request submitted! Status: Request Pending'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _fetchCommunities();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: $e')),
        );
      }
    }
  }

  void _shareCommunity(Map<String, dynamic> comm) {
    final commId = comm['_id']?.toString() ?? comm['id']?.toString() ?? '';
    final name = comm['name'] ?? 'Community';
    final desc = comm['description'] ?? '';
    final shareUrl = "${ApiConfig.baseUrl}/share/community/$commId";
    final appUrl = "Ritpen://community/$commId";
    final text = '🌟 Join the "$name" community on Ritpen!\n\n$desc\n\nTap link to open in app:\n$shareUrl\n(or $appUrl)';
    Share.share(text, subject: 'Join $name on Ritpen');
  }

  List<Map<String, dynamic>> get _filteredCommunities {
    List<Map<String, dynamic>> source;
    if (_selectedFilter == 'created') {
      source = _createdCommunities;
    } else if (_selectedFilter == 'joined') {
      source = _joinedCommunities;
    } else {
      source = _allCommunities;
    }
    if (_searchQuery.trim().isEmpty) return source;
    final q = _searchQuery.toLowerCase().trim();
    return source.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final desc = (c['description'] ?? '').toString().toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Communities',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.brand, size: 26),
            tooltip: 'Create Community',
            onPressed: () => showCreateCommunityModal(context, onCreated: _fetchCommunities),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateCommunityModal(context, onCreated: _fetchCommunities),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text(
          'Create Community',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCommunities,
        color: AppColors.brand,
        child: Column(
          children: [
            // Search & Filter Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search communities...',
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F3F5),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All Communities (${_allCommunities.length})',
                          isSelected: _selectedFilter == 'all',
                          onTap: () => setState(() => _selectedFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Created by Me (${_createdCommunities.length})',
                          isSelected: _selectedFilter == 'created',
                          onTap: () => setState(() => _selectedFilter = 'created'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Joined Communities (${_joinedCommunities.length})',
                          isSelected: _selectedFilter == 'joined',
                          onTap: () => setState(() => _selectedFilter = 'joined'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    )
                  : _filteredCommunities.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedFilter == 'created'
                                    ? Icons.group_add_outlined
                                    : Icons.groups_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter == 'created'
                                    ? 'No communities created by you yet.'
                                    : _selectedFilter == 'joined'
                                        ? 'You have not joined any community yet.'
                                        : 'No communities found.',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedFilter == 'created'
                                    ? 'Tap below to create your community and manage members!'
                                    : _selectedFilter == 'joined'
                                        ? 'Browse "All Communities" to explore and request to join!'
                                        : 'Tap "+ Create Community" to start your own group!',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              if (_selectedFilter == 'joined')
                                OutlinedButton.icon(
                                  onPressed: () => setState(() => _selectedFilter = 'all'),
                                  icon: const Icon(Icons.explore_rounded),
                                  label: const Text('Browse All Communities'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.brand,
                                    side: const BorderSide(color: AppColors.brand),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () => showCreateCommunityModal(context, onCreated: _fetchCommunities),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Create New Community'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 80 + MediaQuery.paddingOf(context).bottom),
                          itemCount: _filteredCommunities.length,
                          itemBuilder: (context, index) {
                            final comm = _filteredCommunities[index];
                            final commId = comm['_id']?.toString() ?? comm['id']?.toString() ?? '';
                            final name = comm['name'] ?? 'Community';
                            final desc = comm['description'] ?? '';
                            final count = comm['memberCount'] ?? 1;
                            final rawImg = comm['image'] ?? comm['coverImage'];
                            final imgUrl = formatCommunityImageUrl(rawImg?.toString());

                            final isCreator = comm['isCreator'] == true ||
                                (comm['creatorId'] != null && comm['creatorId'].toString() == _userId);
                            final isJoinedMember = _joinedCommunities.any(
                                (m) => (m['_id']?.toString() ?? m['id']?.toString()) == commId);
                            final pendingRequests = int.tryParse(comm['pendingRequestsCount']?.toString() ?? '0') ?? 0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              color: Colors.white,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommunityPage(
                                        communityId: commId,
                                        communityName: name,
                                      ),
                                    ),
                                  ).then((_) => _fetchCommunities());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 26,
                                            backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                                            backgroundImage: imgUrl.isNotEmpty
                                                ? CachedNetworkImageProvider(imgUrl)
                                                : null,
                                            child: imgUrl.isEmpty
                                                ? const Icon(Icons.groups_rounded, color: AppColors.brand, size: 26)
                                                : null,
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 16,
                                                          color: AppColors.textPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isCreator)
                                                      Container(
                                                        margin: const EdgeInsets.only(left: 6),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF3E8FF),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: const Color(0xFFD8B4FE)),
                                                        ),
                                                        child: const Text(
                                                          'Creator',
                                                          style: TextStyle(
                                                            color: Color(0xFF7E22CE),
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 8,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.people_outline_rounded, size: 14, color: Colors.grey),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '$count members',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey.shade600,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (isCreator && pendingRequests > 0)
                                                      InkWell(
                                                        onTap: () => showJoinRequestsModal(
                                                          context,
                                                          commId,
                                                          name,
                                                          onRequestsUpdated: _fetchCommunities,
                                                        ),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFFFF3E0),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: const Color(0xFFFFB74D)),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              const Icon(Icons.pending_actions_rounded, size: 12, color: Color(0xFFE65100)),
                                                              const SizedBox(width: 3),
                                                              Text(
                                                                '$pendingRequests Pending',
                                                                style: const TextStyle(
                                                                  color: Color(0xFFE65100),
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.share_outlined, color: Colors.grey, size: 20),
                                            tooltip: 'Share Community',
                                            onPressed: () => _shareCommunity(comm),
                                          ),
                                        ],
                                      ),
                                      if (desc.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          desc,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      const Divider(height: 1),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: isCreator
                                                ? Wrap(
                                                    spacing: 6,
                                                    children: [
                                                      if (pendingRequests > 0)
                                                        ElevatedButton.icon(
                                                          onPressed: () => showJoinRequestsModal(
                                                            context,
                                                            commId,
                                                            name,
                                                            onRequestsUpdated: _fetchCommunities,
                                                          ),
                                                          icon: const Icon(Icons.pending_actions_rounded, size: 13),
                                                          label: Text('Requests ($pendingRequests)'),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: const Color(0xFFE65100),
                                                            foregroundColor: Colors.white,
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                            minimumSize: Size.zero,
                                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          ),
                                                        )
                                                      else
                                                        OutlinedButton.icon(
                                                          onPressed: () => showJoinRequestsModal(
                                                            context,
                                                            commId,
                                                            name,
                                                            onRequestsUpdated: _fetchCommunities,
                                                          ),
                                                          icon: const Icon(Icons.pending_actions_rounded, size: 13),
                                                          label: const Text('Join Requests'),
                                                          style: OutlinedButton.styleFrom(
                                                            foregroundColor: Colors.grey.shade700,
                                                            side: BorderSide(color: Colors.grey.shade300),
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                            minimumSize: Size.zero,
                                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          ),
                                                        ),
                                                    ],
                                                  )
                                                : isJoinedMember
                                                    ? Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green.shade50,
                                                          borderRadius: BorderRadius.circular(12),
                                                          border: Border.all(color: Colors.green.shade200),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Member',
                                                              style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    : OutlinedButton.icon(
                                                        onPressed: () => _requestJoinCommunity(commId),
                                                        icon: const Icon(Icons.group_add_rounded, size: 14),
                                                        label: const Text('Request to Join'),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: AppColors.brand,
                                                          side: const BorderSide(color: AppColors.brand),
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                          minimumSize: Size.zero,
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                        ),
                                                      ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => CommunityPage(
                                                    communityId: commId,
                                                    communityName: name,
                                                  ),
                                                ),
                                              ).then((_) => _fetchCommunities());
                                            },
                                            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                                            label: const Text('View Group'),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.grey.shade700,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                        ],
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
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. CREATE COMMUNITY MODAL DIALOG
// ==========================================
void showCreateCommunityModal(BuildContext context, {VoidCallback? onCreated}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CreateCommunitySheet(onCreated: onCreated),
  );
}

class _CreateCommunitySheet extends StatefulWidget {
  final VoidCallback? onCreated;
  const _CreateCommunitySheet({this.onCreated});

  @override
  State<_CreateCommunitySheet> createState() => _CreateCommunitySheetState();
}

class _CreateCommunitySheetState extends State<_CreateCommunitySheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  File? _communityImage;
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _communityImage = File(picked.path));
      }
    } catch (e) {
      debugPrint('Error picking community image: $e');
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.brand),
              title: const Text('Choose from Gallery (கேலரி)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.brand),
              title: const Text('Take a Photo (கேமரா)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_communityImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Remove Photo (நீக்கு)', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _communityImage = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a community name');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'USR00000001';

      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/communities');
      http.Response res;

      if (_communityImage != null) {
        var request = http.MultipartRequest('POST', uri);
        request.fields['name'] = name;
        request.fields['description'] = _descController.text.trim();
        request.fields['userId'] = userId;

        final mimeType = lookupMimeType(_communityImage!.path) ?? 'image/jpeg';
        final parts = mimeType.contains('/') ? mimeType.split('/') : ['image', 'jpeg'];
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            _communityImage!.path,
            contentType: MediaType(
              parts.isNotEmpty ? parts[0] : 'image',
              parts.length > 1 ? parts[1] : 'jpeg',
            ),
          ),
        );

        final streamed = await request.send().timeout(const Duration(seconds: 60));
        res = await http.Response.fromStream(streamed);
      } else {
        res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'description': _descController.text.trim(),
            'userId': userId,
          }),
        );
      }

      if (res.statusCode == 201 || res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final commData = decoded['data']?['community'];
        final newCommId = commData?['_id']?.toString() ?? commData?['id']?.toString() ?? '';

        if (!mounted) return;
        Navigator.pop(context); // Close sheet
        widget.onCreated?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Community "$name" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        if (newCommId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommunityPage(
                communityId: newCommId,
                communityName: name,
              ),
            ),
          ).then((_) => widget.onCreated?.call());
        }
        return;
      }

      final errorMsg = jsonDecode(res.body)['message'] ?? 'Creation failed';
      setState(() => _errorMessage = errorMsg);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create community: $e');
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group_add_rounded, color: AppColors.brand, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Create Community',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Build a dedicated group for readers and writers with shared interests.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Community Profile Image Picker
            Center(
              child: GestureDetector(
                onTap: _showImageSourcePicker,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brand.withValues(alpha: 0.08),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.35),
                          width: 2,
                        ),
                        image: _communityImage != null
                            ? DecorationImage(
                                image: FileImage(_communityImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _communityImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_rounded, color: AppColors.brand, size: 28),
                                SizedBox(height: 4),
                                Text(
                                  'Add Photo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _communityImage != null
                    ? 'Tap photo to change'
                    : 'Community Profile Photo (Optional)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 18),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const Text(
              'Community Name (பெயர்) *',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Modern Tamil Novelists',
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Description (விளக்கம்)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe topics discussed, guidelines, or books featured...',
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isCreating ? null : _submitCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Create Community',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. COMMUNITY DETAIL PAGE
// ==========================================
class CommunityPage extends StatefulWidget {
  final String communityId;
  final String? communityName;

  const CommunityPage({
    super.key,
    required this.communityId,
    this.communityName,
  });

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  Map<String, dynamic>? _community;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoadingCommunity = true;
  bool _isLoadingPosts = true;
  bool _isRequestingJoin = false;
  String _joinStatus = 'none'; // 'none', 'pending', 'approved', 'joined'
  bool _isCreator = false;
  String? _userId;
  String? _currentUsername;
  Set<String> _likedPosts = {};

  @override
  void initState() {
    super.initState();
    _loadUserAndCommunity();
  }

  @override
  void dispose() {
    SavedPostsManager.instance.removeListener(_onSavedChanged);
    LikedPostsManager.instance.removeListener(_onLikedChanged);
    super.dispose();
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  void _onLikedChanged() {
    if (!mounted) return;
    if (LikedPostsManager.instance.deletedPostIds.isNotEmpty) {
      _posts.removeWhere((p) {
        final pid = (p['post_id'] ?? p['_id'])?.toString() ?? '';
        return LikedPostsManager.instance.deletedPostIds.contains(pid);
      });
    }
    setState(() {});
  }

  Future<void> _loadUserAndCommunity() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? 'USR00000001';
    _currentUsername = prefs.getString('user_name') ?? prefs.getString('username') ?? '';
    _likedPosts = (prefs.getStringList('cached_liked_posts') ?? []).toSet();
    LikedPostsManager.instance.init(_userId);
    LikedPostsManager.instance.addListener(_onLikedChanged);
    SavedPostsManager.instance.init(_userId);
    SavedPostsManager.instance.addListener(_onSavedChanged);

    await _fetchCommunityDetails();
    await _fetchCommunityPosts();
  }

  Future<void> _fetchCommunityDetails() async {
    setState(() => _isLoadingCommunity = true);
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/communities/${widget.communityId}?userId=$_userId');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data']?['community'] != null) {
          final data = decoded['data']['community'];
          if (mounted) {
            setState(() {
              _community = Map<String, dynamic>.from(data);
              _joinStatus = data['joinStatus'] ?? 'none';
              _isCreator = data['isCreator'] == true || (data['creatorId'] != null && data['creatorId'].toString() == _userId);
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingCommunity = false);
    }
  }

  Future<void> _fetchCommunityPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final userParam = (_userId != null && _userId!.isNotEmpty) ? "?userId=$_userId" : "";
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/communities/${widget.communityId}/posts$userParam');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          final list = List<Map<String, dynamic>>.from(decoded['data']);
          for (var p in list) {
            final pid = (p['post_id'] ?? p['_id'])?.toString() ?? '';
            if (pid.isNotEmpty) {
              final isSup = (p['isSupported'] == true || p['isLiked'] == true);
              final sc = int.tryParse(p['support_count']?.toString() ?? '');
              LikedPostsManager.instance.syncPost(pid, isLiked: isSup, supportCount: sc);
              if (isSup) _likedPosts.add(pid);
              if (p['isSaved'] == true) {
                SavedPostsManager.instance.savedPostIds.add(pid);
              }
            }
          }
          if (mounted) {
            setState(() {
              _posts = list;
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _toggleLike(String postId) async {
    if (postId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final effectiveUserId = _userId ?? prefs.getString("user_id") ?? "";
    if (token.isEmpty && effectiveUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please sign in to like stories")),
        );
      }
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
    if (postId.isEmpty) return;
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
    if (mounted) setState(() {});
  }

  Future<void> _requestToJoin() async {
    if (_isRequestingJoin || _joinStatus == 'pending' || _joinStatus == 'joined' || _joinStatus == 'approved') {
      return;
    }

    setState(() => _isRequestingJoin = true);
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/communities/${widget.communityId}/request-join');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': _userId}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        final status = decoded['data']?['status'] ?? 'pending';
        setState(() {
          _joinStatus = status;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Join request submitted! Status: Request Pending'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingJoin = false);
      }
    }
  }

  void _shareCommunity() {
    final commId = widget.communityId;
    final commName = _community?['name'] ?? widget.communityName ?? 'Community';
    final description = _community?['description'] ?? '';
    final shareUrl = "${ApiConfig.baseUrl}/share/community/$commId";
    final appUrl = "Ritpen://community/$commId";
    final shareText = '🌟 Join the "$commName" community on Ritpen!\n\n$description\n\nTap link to open in app:\n$shareUrl\n(or $appUrl)';
    Share.share(shareText, subject: 'Join $commName Community on Ritpen');
  }

  void _openAddMembersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMembersSheet(
        communityId: widget.communityId,
        communityName: _community?['name'] ?? widget.communityName ?? 'Community',
        onMembersUpdated: () {
          _fetchCommunityDetails();
        },
      ),
    );
  }

  Widget _buildJoinButton() {
    if (_isCreator) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: AppColors.brand, size: 14),
            SizedBox(width: 4),
            Text(
              'Creator',
              style: TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_joinStatus == 'joined' || _joinStatus == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
            SizedBox(width: 4),
            Text(
              'Joined',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_joinStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 14),
            SizedBox(width: 4),
            Text(
              'Pending',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _isRequestingJoin ? null : _requestToJoin,
      icon: _isRequestingJoin
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.group_add_rounded, size: 16),
      label: const Text('Request to Join', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commName = _community?['name'] ?? widget.communityName ?? 'Community';
    final description = _community?['description'] ?? 'Welcome to $commName community discussions and PDF book library.';
    final memberCount = _community?['memberCount'] ?? 100;
    final coverImage = _community?['coverImage'] ?? _community?['image'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(commName),
        actions: [
          // Share across apps
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
            tooltip: 'Share Community',
            onPressed: _shareCommunity,
          ),
          if (_isCreator) ...[
            IconButton(
              icon: const Icon(Icons.pending_actions_rounded, color: Color(0xFFE65100)),
              tooltip: 'Join Requests',
              onPressed: () => showJoinRequestsModal(
                context,
                widget.communityId,
                commName,
                onRequestsUpdated: () => _fetchCommunityDetails(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.brand),
              tooltip: 'Add Members',
              onPressed: _openAddMembersModal,
            ),
          ],
        ],
      ),
      body: _isLoadingCommunity && _community == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchCommunityDetails();
                await _fetchCommunityPosts();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Community Header Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                                backgroundImage: (coverImage != null && formatCommunityImageUrl(coverImage.toString()).isNotEmpty)
                                    ? CachedNetworkImageProvider(formatCommunityImageUrl(coverImage.toString()))
                                    : null,
                                child: (coverImage == null || formatCommunityImageUrl(coverImage.toString()).isEmpty)
                                    ? const Icon(Icons.groups_rounded, size: 36, color: AppColors.brand)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      commName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.people_outline_rounded, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Members: $memberCount',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(),
                          const SizedBox(height: 12),

                          // Actions Row (Wrap layout to avoid any overflow)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildJoinButton(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isCreator) ...[
                                    OutlinedButton.icon(
                                      onPressed: () => showJoinRequestsModal(
                                        context,
                                        widget.communityId,
                                        commName,
                                        onRequestsUpdated: () {
                                          _fetchCommunityDetails();
                                        },
                                      ),
                                      icon: const Icon(Icons.pending_actions_rounded, size: 14, color: Color(0xFFE65100)),
                                      label: const Text(
                                        'Join Requests',
                                        style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFFFB74D)),
                                        backgroundColor: const Color(0xFFFFF3E0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton.icon(
                                      onPressed: _openAddMembersModal,
                                      icon: const Icon(Icons.person_add_rounded, size: 14, color: AppColors.brand),
                                      label: const Text(
                                        'Add Members',
                                        style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.brand),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.share_rounded, color: AppColors.brand, size: 20),
                                    tooltip: 'Share Community',
                                    onPressed: _shareCommunity,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Section: Community Posts
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.dynamic_feed_rounded, color: AppColors.brand, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Posts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_posts.length} stories',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),

                    if (_isLoadingPosts)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.brand),
                        ),
                      )
                    else if (_posts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'No posts in this community yet.',
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Members can post to this community from the Write tab.',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          final postId = (post['post_id'] ?? post['_id'])?.toString() ?? '';
                          return PostCard(
                            key: ValueKey('comm_post_${postId}_${post['cover_image'] ?? post['cover_img'] ?? ''}'),
                            post: post,
                            isCommunityView: true,
                            isLiked: LikedPostsManager.instance.isLiked(postId),
                            isSaved: SavedPostsManager.instance.isSaved(postId),
                            onLike: () => _toggleLike(postId),
                            onSave: () => _toggleSave(postId),
                            currentUserId: _userId,
                            currentUsername: _currentUsername,
                          );
                        },
                      ),
                    SizedBox(height: 40 + MediaQuery.paddingOf(context).bottom),
                  ],
                ),
              ),
            ),
    );
  }
}

// ==========================================
// 4. ADD APP USERS MODAL (CREATOR / ADMIN)
// ==========================================
class _AddMembersSheet extends StatefulWidget {
  final String communityId;
  final String communityName;
  final VoidCallback onMembersUpdated;

  const _AddMembersSheet({
    required this.communityId,
    required this.communityName,
    required this.onMembersUpdated,
  });

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  final Set<String> _addingUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchAvailableUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailableUsers({String query = ''}) async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/communities/${widget.communityId}/available-users?q=${Uri.encodeComponent(query)}');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data']?['users'] is List) {
          final list = List<Map<String, dynamic>>.from(decoded['data']['users']);
          if (mounted) {
            setState(() {
              _users = list;
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMember(String targetUserId, String userName) async {
    setState(() => _addingUserIds.add(targetUserId));
    try {
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/communities/${widget.communityId}/members');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userIds': [targetUserId]
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            for (var u in _users) {
              if (u['_id']?.toString() == targetUserId || u['id']?.toString() == targetUserId) {
                u['isMember'] = true;
                u['status'] = 'joined';
                break;
              }
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName added to community!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        widget.onMembersUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _addingUserIds.remove(targetUserId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20 + MediaQuery.paddingOf(context).bottom,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.person_add_rounded, color: AppColors.brand, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Add Users to Community',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select registered app users to add directly into "${widget.communityName}".',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (q) => _fetchAvailableUsers(query: q),
            decoration: InputDecoration(
              hintText: 'Search users by name, username or email...',
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF1F3F5),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No matching users found',
                              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final uId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
                          final name = user['name'] ?? user['username'] ?? 'User';
                          final username = user['username'] ?? '';
                          final email = user['email'] ?? '';
                          final isMember = user['isMember'] == true || user['status'] == 'joined' || user['status'] == 'approved';
                          final isAdding = _addingUserIds.contains(uId);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              subtitle: Text(
                                username.isNotEmpty ? '@$username' : email,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              trailing: isMember
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check, size: 14, color: Colors.green),
                                          SizedBox(width: 4),
                                          Text(
                                            'Added',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: isAdding ? null : () => _addMember(uId, name),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.brand,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: isAdding
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            )
                                          : const Text(
                                              '+ Add',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
}

// ==========================================
// PENDING JOIN REQUESTS SHEET (OWNER ONLY)
// ==========================================
void showJoinRequestsModal(
  BuildContext context,
  String communityId,
  String communityName, {
  VoidCallback? onRequestsUpdated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _JoinRequestsSheet(
      communityId: communityId,
      communityName: communityName,
      onRequestsUpdated: onRequestsUpdated,
    ),
  );
}

class _JoinRequestsSheet extends StatefulWidget {
  final String communityId;
  final String communityName;
  final VoidCallback? onRequestsUpdated;

  const _JoinRequestsSheet({
    required this.communityId,
    required this.communityName,
    this.onRequestsUpdated,
  });

  @override
  State<_JoinRequestsSheet> createState() => _JoinRequestsSheetState();
}

class _JoinRequestsSheetState extends State<_JoinRequestsSheet> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _userId;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadUserAndFetch();
  }

  Future<void> _loadUserAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? 'USR00000001';
    await _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(
          '${ApiConfig.apiBaseUrl}/communities/${widget.communityId}/join-requests?userId=$_userId');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data']?['requests'] is List) {
          setState(() {
            _requests = List<Map<String, dynamic>>.from(decoded['data']['requests']);
          });
        }
      }
    } catch (e) {
      debugPrint('[Fetch join requests error]: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(String requestId, String requesterName, String action) async {
    if (_processingIds.contains(requestId)) return;

    setState(() => _processingIds.add(requestId));
    try {
      final uri = Uri.parse(
          '${ApiConfig.apiBaseUrl}/communities/${widget.communityId}/join-requests/$requestId/action');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': action,
          'userId': _userId,
        }),
      );

      if (res.statusCode == 200) {
        setState(() {
          _requests.removeWhere((r) =>
              (r['id']?.toString() == requestId || r['_id']?.toString() == requestId));
        });
        widget.onRequestsUpdated?.call();

        if (mounted) {
          final isApprove = action == 'approve';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isApprove
                    ? 'Approved $requesterName to join ${widget.communityName}!'
                    : 'Rejected join request from $requesterName.',
              ),
              backgroundColor: isApprove ? Colors.green.shade700 : Colors.grey.shade800,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to $action request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(requestId));
      }
    }
  }

  String _formatTime(dynamic rawDate) {
    if (rawDate == null) return '';
    try {
      final dt = DateTime.parse(rawDate.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    color: Color(0xFFE65100),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Join Requests',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        '${widget.communityName} • ${_requests.length} pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List or States
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  )
                : _requests.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 40,
                                  color: Colors.green.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'All Caught Up!',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'There are no pending join requests for this community.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _requests.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final req = _requests[index];
                          final reqId = req['id'] ?? req['_id'] ?? '$index';
                          final name = req['name']?.toString() ?? 'Ritpen User';
                          final username = req['username']?.toString() ?? '';
                          final rawImg = req['profileImage']?.toString() ?? '';
                          final isProcessing = _processingIds.contains(reqId);
                          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                          String? imgUrl;
                          if (rawImg.isNotEmpty) {
                            if (rawImg.startsWith('http')) {
                              imgUrl = rawImg;
                            } else {
                              imgUrl = '${ApiConfig.baseUrl}/uploads/profile_images/$rawImg';
                            }
                          }

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: const Color(0xFFE8EEFF),
                                      backgroundImage: (imgUrl != null)
                                          ? CachedNetworkImageProvider(imgUrl)
                                          : null,
                                      child: (imgUrl == null)
                                          ? Text(
                                              initial,
                                              style: GoogleFonts.outfit(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.brand,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              if (username.isNotEmpty) ...[
                                                Text(
                                                  '@$username • ',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                              Text(
                                                _formatTime(req['requestedAt']),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFFFB74D)),
                                      ),
                                      child: const Text(
                                        'Pending',
                                        style: TextStyle(
                                          color: Color(0xFFE65100),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: isProcessing
                                          ? null
                                          : () => _handleAction(reqId, name, 'reject'),
                                      icon: const Icon(Icons.close_rounded, size: 14),
                                      label: const Text('Reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red.shade700,
                                        side: BorderSide(color: Colors.red.shade300),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: isProcessing
                                          ? null
                                          : () => _handleAction(reqId, name, 'approve'),
                                      icon: isProcessing
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.check_rounded, size: 14),
                                      label: const Text('Approve'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E7D32),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/home.dart';

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
  List<Map<String, dynamic>> _myCommunities = [];
  bool _isLoading = true;
  String? _userId;
  String _selectedFilter = 'all'; // 'all' or 'my'
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
        }
      }

      // 2. Fetch My Joined/Created Communities
      final myUri = Uri.parse('${ApiConfig.apiBaseUrl}/communities/my-communities?userId=$_userId');
      final myRes = await http.get(myUri);
      if (myRes.statusCode == 200) {
        final decoded = jsonDecode(myRes.body);
        if (decoded['success'] == true && decoded['data']?['communities'] is List) {
          _myCommunities = List<Map<String, dynamic>>.from(decoded['data']['communities']);
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
    final appUrl = "ryitu://community/$commId";
    final text = '🌟 Join the "$name" community on Ryitu!\n\n$desc\n\nTap link to open in app:\n$shareUrl\n(or $appUrl)';
    Share.share(text, subject: 'Join $name on Ryitu');
  }

  List<Map<String, dynamic>> get _filteredCommunities {
    final source = _selectedFilter == 'my' ? _myCommunities : _allCommunities;
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
                          onTap: () => setState(() => _selectedFilter == 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'My Communities (${_myCommunities.length})',
                          isSelected: _selectedFilter == 'my',
                          onTap: () => setState(() => _selectedFilter == 'my'),
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
                              Icon(Icons.groups_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter == 'my'
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
                                'Tap "+ Create Community" to start your own group!',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                              const SizedBox(height: 20),
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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _filteredCommunities.length,
                          itemBuilder: (context, index) {
                            final comm = _filteredCommunities[index];
                            final commId = comm['_id']?.toString() ?? '';
                            final name = comm['name'] ?? 'Community';
                            final desc = comm['description'] ?? '';
                            final count = comm['memberCount'] ?? 1;
                            final img = comm['image'] ?? comm['coverImage'];

                            final isMy = _myCommunities.any((m) => m['_id']?.toString() == commId);

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
                                            backgroundImage: (img != null && img.toString().isNotEmpty)
                                                ? CachedNetworkImageProvider(img.toString())
                                                : null,
                                            child: (img == null || img.toString().isEmpty)
                                                ? const Icon(Icons.groups_rounded, color: AppColors.brand, size: 26)
                                                : null,
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
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
                                            child: isMy
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
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
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
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'description': _descController.text.trim(),
          'userId': userId,
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final commData = decoded['data']?['community'];
        final newCommId = commData?['_id']?.toString() ?? '';

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
          );
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
        MediaQuery.of(context).viewInsets.bottom + 24,
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
            const SizedBox(height: 20),
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

  @override
  void initState() {
    super.initState();
    _loadUserAndCommunity();
  }

  Future<void> _loadUserAndCommunity() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? 'USR00000001';

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
      final uri = Uri.parse('${ApiConfig.apiBaseUrl}/communities/${widget.communityId}/posts');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          final list = List<Map<String, dynamic>>.from(decoded['data']);
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
    final appUrl = "ryitu://community/$commId";
    final shareText = '🌟 Join the "$commName" community on Ryitu!\n\n$description\n\nTap link to open in app:\n$shareUrl\n(or $appUrl)';
    Share.share(shareText, subject: 'Join $commName Community on Ryitu');
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
          if (_isCreator)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.brand),
              tooltip: 'Add Members',
              onPressed: _openAddMembersModal,
            ),
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
                                backgroundImage: (coverImage != null && coverImage.toString().isNotEmpty)
                                    ? CachedNetworkImageProvider(coverImage.toString())
                                    : null,
                                child: (coverImage == null || coverImage.toString().isEmpty)
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
                                  if (_isCreator)
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
                          return PostCard(
                            post: post,
                            isCommunityView: true,
                          );
                        },
                      ),
                    const SizedBox(height: 40),
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
        MediaQuery.of(context).viewInsets.bottom + 20,
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

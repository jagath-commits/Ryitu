import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/home.dart';

class NotificationPostPage extends StatefulWidget {
  final String postId;

  const NotificationPostPage({super.key, required this.postId});

  @override
  State<NotificationPostPage> createState() => _NotificationPostPageState();
}

class _NotificationPostPageState extends State<NotificationPostPage> {
  Map<String, dynamic>? _post;
  bool _isLoading = true;
  String? _userId;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _loadUserAndPost();
  }

  Future<void> _loadUserAndPost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString("user_id");
      _currentUsername = (prefs.getString("username") ??
              prefs.getString("user_name") ??
              prefs.getString("name") ??
              "")
          .trim();

      final uri = Uri.parse(
        "${ApiConfig.apiBaseUrl}/posts/${widget.postId}${_userId != null ? '?userId=$_userId' : ''}",
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final postData = decoded["data"] ?? decoded["post"] ?? decoded;
        if (postData is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              _post = postData;
              _isLoading = false;
            });
          }
          return;
        } else if (postData is Map) {
          if (mounted) {
            setState(() {
              _post = Map<String, dynamic>.from(postData);
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[NotificationPostPage error]: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : _post == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Post not found or has been removed.',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: PostContainer(
                    post: _post!,
                    currentUserId: _userId,
                    currentUsername: _currentUsername,
                  ),
                ),
    );
  }
}

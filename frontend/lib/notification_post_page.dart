import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/home.dart';

class NotificationPostPage extends StatefulWidget {
  final String postId;

  const NotificationPostPage({super.key, required this.postId});

  @override
  State<NotificationPostPage> createState() => _NotificationPostPageState();
}

class _NotificationPostPageState extends State<NotificationPostPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  List<dynamic> _extractPages(dynamic rawContent) {
    if (rawContent == null) return [];
    if (rawContent is List) return rawContent;
    // Already a decoded Map (e.g. {titleStyle: {...}, pages: [...]})
    if (rawContent is Map) {
      if (rawContent['pages'] != null) return rawContent['pages'];
      return [];
    }
    if (rawContent is String) {
      try {
        final decoded = jsonDecode(rawContent);
        if (decoded is List) return decoded;
        if (decoded is Map && decoded["pages"] != null) {
          return decoded["pages"];
        }
      } catch (e) {
        print("JSON ERROR = $e");
      }
    }
    return [];
  }

  Future<void> _loadPost() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.apiBaseUrl}/posts/${widget.postId}"),
      );

      if (response.statusCode == 200) {
        print("STATUS = ${response.statusCode}");
        print("BODY = ${response.body}");
        final data = jsonDecode(response.body);

        print("DATA = ${data['data']}");
        print("CONTENT = ${data['data']['content']}");

        final post = data["data"] ?? data["post"] ?? data;

        if (!mounted) return;

        final content = post["Content"] ?? post["content"];

        final username = post["username"] ?? post["Username"] ?? "Unknown";

        final profileImage =
            post["profile_image"] ?? post["ProfileImage"] ?? "";

        final postId = post["PostId"] ?? post["post_id"] ?? widget.postId;

        final title = post["Title"] ?? post["title"] ?? "";

        print("PAGES = ${_extractPages(content)}");
        

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenPostViewer(
              pages: _extractPages(content),
              username: username,
              profileImage: profileImage,
              postId: postId,
              postTitle: title,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

import 'dart:convert';
import 'dart:io' show File;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/home.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/password_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfilePage extends StatefulWidget {
  final String userId;
  final String? phone;
  final String? password;
  final bool isNewUser;

  const EditProfilePage({
    super.key,
    required this.userId,
    this.phone,
    this.password,
    this.isNewUser = false,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  Future<String?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();


  File? _image;
  String? _networkImageUrl;
  bool _removeImage = false;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    print("🔍 DEBUG: EditProfilePage init with userId: ${widget.userId}");
    _loadLocalProfile(); // 🔥 Load local data first for speed
    _fetchRemoteProfile(); // 🌐 Fetch latest from database to guarantee accuracy
  }

  Future<void> _loadLocalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final savedUser = prefs.getString("username");
      if (savedUser != null &&
          savedUser.isNotEmpty &&
          savedUser != widget.userId &&
          !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(savedUser)) {
        _nameController.text = savedUser;
      }
      _emailController.text =
          prefs.getString("user_email") ?? _emailController.text;
      final savedMobile = prefs.getString("user_mobile");
      if (savedMobile != null && savedMobile.isNotEmpty) {
        _mobileController.text = savedMobile;
      } else if (widget.userId.isNotEmpty && !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(widget.userId)) {
        _mobileController.text = widget.userId;
      }
      if (!_removeImage) {
        _networkImageUrl = prefs.getString("profile_image_url");
      }
    });
  }

  Future<void> _fetchRemoteProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final targetId = widget.userId.isNotEmpty
          ? widget.userId
          : (prefs.getString("user_id") ?? "");
      if (targetId.isEmpty) return;

      final res = await http.get(
        Uri.parse("${ApiConfig.apiBaseUrl}/profile/profile/$targetId"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded is Map && decoded['data'] is Map
            ? decoded['data'] as Map
            : decoded;
        if (data is Map && mounted) {
          final fetchedUser =
              (data['username'] ?? data['Username'] ?? data['name'])
                  ?.toString()
                  .trim() ??
              '';
          final fetchedEmail =
              (data['email'] ?? data['Email'])?.toString().trim() ?? '';
          final fetchedMobile =
              (data['mobileNumber'] ?? data['phone'])?.toString().trim() ?? '';
          final fetchedImg =
              (data['profile_image'] ??
                      data['ProfileImage'] ??
                      data['profileImage'])
                  ?.toString()
                  .trim() ??
              '';

          setState(() {
            if (fetchedUser.isNotEmpty &&
                fetchedUser != targetId &&
                !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(fetchedUser)) {
              _nameController.text = fetchedUser;
              prefs.setString("username", fetchedUser);
            }
            if (fetchedEmail.isNotEmpty) {
              _emailController.text = fetchedEmail;
              prefs.setString("user_email", fetchedEmail);
            }
            if (fetchedMobile.isNotEmpty) {
              _mobileController.text = fetchedMobile;
              prefs.setString("user_mobile", fetchedMobile);
            }
            if (fetchedImg.isNotEmpty && !_removeImage) {
              String fullImg = fetchedImg;
              if (!fullImg.startsWith("http")) {
                fullImg =
                    "${ApiConfig.baseUrl}/uploads/profile_images/$fetchedImg";
              }
              _networkImageUrl = fullImg;
              prefs.setString("profile_image_url", fullImg);
            } else if (_removeImage || fetchedImg.isEmpty) {
              _networkImageUrl = null;
              prefs.remove("profile_image_url");
            }
          });
        }
      }
    } catch (_) {}
  }



  // ===============================
  // IMAGE PICKER
  // ===============================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _image = File(picked.path);
          _removeImage = false;
        });

        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text(
                  'Image selected! Click Save to update.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0729E8),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ===============================
  // UI
  // ===============================
  Future<void> _saveProfile() async {
    final String username = _nameController.text.trim();
    final String email = _emailController.text.trim();

    if (username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name must be at least 3 characters")),
      );
      return;
    }
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid email address")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (widget.isNewUser) {
        final uri = Uri.parse("${ApiConfig.apiBaseUrl}/auth/register");
        var request = http.MultipartRequest("POST", uri);

        request.fields["mobileNumber"] = widget.phone ?? "";
        request.fields["password"] = widget.password ?? "";
        request.fields["username"] = username;
        request.fields["email"] = email;

        if (_image != null) {
          final mimeType = lookupMimeType(_image!.path) ?? 'image/jpeg';
          final mimeSplit = mimeType.contains('/') ? mimeType.split('/') : ['image', 'jpeg'];
          request.files.add(
            await http.MultipartFile.fromPath(
              "profile_image",
              _image!.path,
              contentType: MediaType(
                mimeSplit.isNotEmpty ? mimeSplit[0] : 'image',
                mimeSplit.length > 1 ? mimeSplit[1] : 'jpeg',
              ),
            ),
          );
        }

        var streamedResponse = await request.send().timeout(const Duration(seconds: 90));
        var response = await http.Response.fromStream(streamedResponse);

        if (!mounted) return;

        if (response.statusCode == 201 || response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded['success'] == true) {
            final data = decoded['data'];
            
            await prefs.setString("token", data["token"] ?? "");
            await prefs.setString("user_id", data["user_id"]?.toString() ?? "");
            await prefs.setString("user_mobile", data["user_mobile"] ?? "");
            await prefs.setString("username", data["username"] ?? "");
            await prefs.setString("user_email", data["email"] ?? "");
            if (data["profile_image"] != null) {
              await prefs.setString("profile_image_url", "${ApiConfig.baseUrl}/uploads/profile_images/${data["profile_image"]}");
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Registered successfully!")),
            );

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
              (route) => false,
            );
            return;
          }
        }
        
        String errorMsg = "Registration failed";
        try {
          final errJson = jsonDecode(response.body);
          errorMsg = errJson["message"] ?? errJson["error"] ?? errorMsg;
        } catch (_) {
          if (response.body.isNotEmpty) errorMsg = response.body;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration failed: $errorMsg"), backgroundColor: Colors.red),
        );
      } else {
        final token = prefs.getString("token") ?? "";
        final effectiveUserId = widget.userId.isNotEmpty
            ? widget.userId
            : (prefs.getString("user_id") ?? "");

        final uri = Uri.parse("${ApiConfig.apiBaseUrl}/profile/update");
        var request = http.MultipartRequest("POST", uri);

        if (token.isNotEmpty) {
          request.headers["Authorization"] = "Bearer $token";
        }
        if (effectiveUserId.isNotEmpty) {
          request.fields["user_id"] = effectiveUserId;
          request.fields["userId"] = effectiveUserId;
        }
        request.fields["username"] = username;
        request.fields["email"] = email;

        if (_removeImage) {
          request.fields["remove_image"] = "true";
          request.fields["profile_image"] = "";
        } else if (_image != null) {
          final mimeType = lookupMimeType(_image!.path) ?? 'image/jpeg';
          final mimeSplit = mimeType.contains('/') ? mimeType.split('/') : ['image', 'jpeg'];
          request.files.add(
            await http.MultipartFile.fromPath(
              "profile_image",
              _image!.path,
              contentType: MediaType(
                mimeSplit.isNotEmpty ? mimeSplit[0] : 'image',
                mimeSplit.length > 1 ? mimeSplit[1] : 'jpeg',
              ),
            ),
          );
        }

        var streamedResponse = await request.send().timeout(const Duration(seconds: 90));
        var response = await http.Response.fromStream(streamedResponse);

        if (!mounted) return;

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded['success'] == true) {
            final data = decoded['data'];

            final newUsername = data["Username"] ?? data["username"] ?? data["name"] ?? username;
            if (newUsername != null &&
                newUsername.toString().isNotEmpty &&
                !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(newUsername.toString())) {
              await prefs.setString("username", newUsername.toString());
            } else {
              await prefs.setString("username", username);
            }
            await prefs.setString("user_email", data["Email"] ?? data["email"] ?? email);
            final updatedImg = data["ProfileImage"] ?? data["profile_image"];
            if (_removeImage) {
              await prefs.remove("profile_image_url");
              await prefs.remove("profile_image_path");
              await prefs.remove("profile_image");
              _networkImageUrl = null;
              _removeImage = false;
            } else if (updatedImg != null && updatedImg.toString().isNotEmpty) {
              await prefs.setString("profile_image_url", "${ApiConfig.baseUrl}/uploads/profile_images/$updatedImg");
              await prefs.remove("profile_image_path");
            }
            if (data["user_id"] != null) {
              await prefs.setString("user_id", data["user_id"].toString());
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile updated successfully!")),
            );
            Navigator.pop(context, true);
            return;
          }
        }

        String errorMsg = "Update failed";
        try {
          final errJson = jsonDecode(response.body);
          errorMsg = errJson["message"] ?? errJson["error"] ?? errorMsg;
        } catch (_) {
          if (response.body.isNotEmpty) errorMsg = response.body;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: $errorMsg"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () async {
            if (widget.isNewUser) {
              // If it's a new user, they haven't registered yet. Just go back to login.
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const PasswordLoginPage()),
                (route) => false,
              );
              return;
            }

            final prefs = await SharedPreferences.getInstance();
            if (prefs.getString("temp_token") != null) {
              await prefs.remove("temp_token");
              await prefs.remove("user_id");
              await prefs.remove("user_mobile");
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const PasswordLoginPage()),
                  (route) => false,
                );
              }
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        title: const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      /// Profile Avatar Section
                      Center(child: _buildProfessionalAvatar()),

                      SizedBox(height: screenHeight * 0.04),

                      /// Input Fields Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: appCardDecoration(radius: AppRadius.lg),
                        child: Column(
                          children: [
                            _buildProfessionalInput(
                              'Full Name *',
                              _nameController,
                            ),
                            const SizedBox(height: 16),
                            _buildProfessionalInput(
                              'Mobile Number *',
                              _mobileController,
                              readOnly: true,
                            ),
                            const SizedBox(height: 16),
                            _buildProfessionalInput(
                              'Email *',
                              _emailController,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      /// Save Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0729E8).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _saveProfile,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0729E8),
                                    Color(0xFF041CA1),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white.withOpacity(0.9),
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Save Changes',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              fontFamily: 'Roboto',
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Professional Avatar with Enhanced Styling
  Widget _buildProfessionalAvatar() {
    ImageProvider? provider;

    if (!_removeImage) {
      if (_image != null) {
        provider = FileImage(_image!);
      } else if (_networkImageUrl != null && _networkImageUrl!.isNotEmpty) {
        provider = CachedNetworkImageProvider(_networkImageUrl!);
      }
    }

    final initial = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : 'U';

    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0729E8).withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundImage: provider,
              onBackgroundImageError: provider != null ? (exception, stackTrace) {} : null,
              backgroundColor: const Color(0xFF0729E8).withValues(alpha: 0.08),
              child: provider == null
                  ? Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0729E8),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showImagePickerOptions,
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withOpacity(0.4),
              highlightColor: Colors.white.withOpacity(0.2),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0729E8), Color(0xFF041CA1)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0729E8).withOpacity(0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }


  /// Professional Input Field
  Widget _buildProfessionalInput(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            fontFamily: 'Roboto',
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: readOnly
                  ? Colors.grey.shade300
                  : const Color(0xFF2196F3).withOpacity(0.3),
              width: 1.3,
            ),
            color: readOnly ? Colors.grey.shade100 : Colors.white,
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: 'Enter $label',
              hintStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontFamily: 'Roboto',
                color: Colors.grey.shade400,
              ),
              suffixIcon: readOnly
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.lock_rounded,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  /// Show Image Picker Options
  void _showImagePickerOptions() {
    final bool hasImage = !_removeImage &&
        (_image != null || (_networkImageUrl != null && _networkImageUrl!.isNotEmpty));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.brand),
              title: const Text(
                'Gallery (கேலரி)',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.brand),
              title: const Text(
                'Camera (கேமரா)',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text(
                  'Remove Profile Photo (படத்தை நீக்கு)',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _image = null;
                    _networkImageUrl = null;
                    _removeImage = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile photo removed. Click Save to apply.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/branding.dart';
import 'package:dmk_project/home.dart';
import 'package:dmk_project/profile1.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dmk_project/forgot_password_page.dart';

// ============================================================
// SINGLE PAGE TABBED PORTAL: SIGN IN / SIGN UP
// ============================================================
class PasswordLoginPage extends StatefulWidget {
  const PasswordLoginPage({super.key});

  @override
  State<PasswordLoginPage> createState() => _PasswordLoginPageState();
}

class _PasswordLoginPageState extends State<PasswordLoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isSignIn = true; // True = Sign In, False = Sign Up (Register)
  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ==========================================
  // API CALL: EXISTING USER LOGIN
  // ==========================================
  Future<void> loginUser() async {
    final String phone = phoneController.text.trim();
    final String password = passwordController.text.trim();

    if (phone.length != 10) {
      showError("Enter a valid 10-digit number");
      return;
    }
    if (password.isEmpty) {
      showError("Enter your password");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.apiBaseUrl}/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"mobileNumber": phone, "password": password}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          final data = decoded['data'];
          final prefs = await SharedPreferences.getInstance();

          String? fcmToken = await FirebaseMessaging.instance.getToken();

          print("FCM TOKEN => $fcmToken");

          await prefs.setString("token", data["token"] ?? "");
          await prefs.setString("user_id", data["user_id"]?.toString() ?? "");

          //String? fcmToken = await FirebaseMessaging.instance.getToken();

          await http.post(
            Uri.parse("${ApiConfig.apiBaseUrl}/auth/save-fcm-token"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "user_id": data["user_id"],
              "fcm_token": fcmToken,
            }),
          );
          await prefs.setString("user_mobile", data["user_mobile"] ?? "");
          await prefs.setString("username", data["username"] ?? "");
          await prefs.setString("user_email", data["email"] ?? "");
          await prefs.setString(
            "user_constituency",
            data["constituency"] ?? "",
          );
          if (data["profile_image"] != null) {
            await prefs.setString(
              "profile_image_url",
              "${ApiConfig.baseUrl}/uploads/profile_images/${data["profile_image"]}",
            );
          }

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainShell()),
            (route) => false,
          );
          return;
        }
      }

      String errorMsg = "Login failed";
      try {
        errorMsg = jsonDecode(response.body)["message"] ?? errorMsg;
      } catch (_) {}
      showError(errorMsg);
    } catch (e) {
      showError("Connection error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ==========================================
  // API CALL: NEW USER REGISTRATION
  // ==========================================
  Future<void> registerUser() async {
    final String phone = phoneController.text.trim();
    final String password = passwordController.text.trim();
    final String confirmPassword = confirmPasswordController.text.trim();

    if (phone.length != 10) {
      showError("Enter a valid 10-digit number");
      return;
    }
    if (password.length < 6) {
      showError("Password must be at least 6 characters long");
      return;
    }
    if (password != confirmPassword) {
      showError("Passwords do not match");
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditProfilePage(
            userId: phone,
            phone: phone,
            password: password,
            isNewUser: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Elegant mesh gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFCFDFD), Color(0xFFF7F8FA)],
              ),
            ),
          ),

          // Abstract Top-Right Crimson Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: screenWidth * 0.7,
              height: screenWidth * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withValues(alpha: 0.04),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.06),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          // Abstract Bottom-Left Peach Glow
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: screenWidth * 0.8,
              height: screenWidth * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.03),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.05),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 48,
                vertical: 20,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        // Logo with subtle shadow
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.015),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const AppLogo(height: 88),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          _isSignIn ? "Welcome Back!" : "Create Account",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.85),
                            letterSpacing: -0.5,
                            fontFamily: 'Roboto',
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          _isSignIn
                              ? "Sign in to connect and read thoughts"
                              : "Join today to read, write and connect",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black.withOpacity(0.45),
                            letterSpacing: 0.2,
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.04),

                        // Main White Card Layout
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.94),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.04),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                              BoxShadow(
                                color: const Color(
                                  0xFF0729E8,
                                ).withOpacity(0.01),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Premium Sliding Slide Switcher (Sign In vs Sign Up)
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.035),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Stack(
                                  children: [
                                    AnimatedAlign(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      curve: Curves.easeInOut,
                                      alignment: _isSignIn
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                      child: FractionallySizedBox(
                                        widthFactor: 0.5,
                                        child: Container(
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: AppColors.brand,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.brand
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              if (!_isSignIn) {
                                                setState(
                                                  () => _isSignIn = true,
                                                );
                                              }
                                            },
                                            behavior: HitTestBehavior.opaque,
                                            child: Center(
                                              child: AnimatedDefaultTextStyle(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                style: TextStyle(
                                                  color: _isSignIn
                                                      ? Colors.white
                                                      : Colors.black
                                                            .withOpacity(0.5),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                                child: const Text("Sign In"),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              if (_isSignIn) {
                                                setState(
                                                  () => _isSignIn = false,
                                                );
                                              }
                                            },
                                            behavior: HitTestBehavior.opaque,
                                            child: Center(
                                              child: AnimatedDefaultTextStyle(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                style: TextStyle(
                                                  color: !_isSignIn
                                                      ? Colors.white
                                                      : Colors.black
                                                            .withOpacity(0.5),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                                child: const Text("Sign Up"),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Form Field 1: Outlined Mobile Input
                              TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  letterSpacing: 1.2,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Mobile Number",
                                  labelStyle: TextStyle(
                                    color: Colors.black.withOpacity(0.4),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  floatingLabelStyle: const TextStyle(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  hintText: "Enter 10-digit number",
                                  hintStyle: TextStyle(
                                    color: Colors.black.withOpacity(0.2),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.0,
                                  ),
                                  prefixIcon: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.black.withOpacity(0.08),
                                          width: 1.2,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.phone_iphone_rounded,
                                          color: AppColors.brand,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "+91",
                                          style: TextStyle(
                                            color: Colors.black.withOpacity(
                                              0.8,
                                            ),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.black.withOpacity(0.08),
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppColors.brand,
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Form Field 2: Outlined Password Input
                              TextField(
                                controller: passwordController,
                                obscureText: !_isPasswordVisible,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  letterSpacing: 1.5,
                                ),
                                decoration: InputDecoration(
                                  labelText: _isSignIn
                                      ? "Password"
                                      : "Create Password",
                                  labelStyle: TextStyle(
                                    color: Colors.black.withOpacity(0.4),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  floatingLabelStyle: const TextStyle(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  hintText: _isSignIn
                                      ? "Enter your password"
                                      : "Choose a secure password",
                                  hintStyle: TextStyle(
                                    color: Colors.black.withOpacity(0.2),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.0,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: AppColors.brand,
                                    size: 18,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      color: Colors.black.withOpacity(0.35),
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.black.withOpacity(0.08),
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppColors.brand,
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                              ),

                              if (_isSignIn) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ForgotPasswordPage(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      "Forgot Password?",
                                      style: TextStyle(
                                        color: AppColors.brand,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              if (!_isSignIn) ...[
                                const SizedBox(height: 20),
                                TextField(
                                  controller: confirmPasswordController,
                                  obscureText: !_isConfirmPasswordVisible,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                    letterSpacing: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: "Confirm Password",
                                    labelStyle: TextStyle(
                                      color: Colors.black.withOpacity(0.4),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    floatingLabelStyle: const TextStyle(
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    hintText: "Re-enter your password",
                                    hintStyle: TextStyle(
                                      color: Colors.black.withOpacity(0.2),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.0,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: AppColors.brand,
                                      size: 18,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isConfirmPasswordVisible
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: Colors.black.withOpacity(0.35),
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isConfirmPasswordVisible =
                                              !_isConfirmPasswordVisible;
                                        });
                                      },
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.black.withOpacity(0.08),
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: AppColors.brand,
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 28),

                              // Auth Button (Sign In / Register)
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0729E8,
                                      ).withOpacity(0.25),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: isLoading
                                        ? null
                                        : (_isSignIn
                                              ? loginUser
                                              : registerUser),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      height: 54,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.brand,
                                            Color(0xFF041CA1),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    _isSignIn
                                                        ? "Sign In"
                                                        : "Register",
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Icon(
                                                    Icons.arrow_forward_rounded,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Interactive Consent links under the card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withOpacity(0.45),
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                              children: [
                                const TextSpan(
                                  text: "By continuing, you agree to our ",
                                ),
                                TextSpan(
                                  text: "Terms & Conditions",
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const TermsPage(),
                                        ),
                                      );
                                    },
                                ),
                                const TextSpan(text: " and "),
                                TextSpan(
                                  text: "Privacy Policy",
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const PrivacyPage(),
                                        ),
                                      );
                                    },
                                ),
                                const TextSpan(text: "."),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Refined watermark footer
                    Column(
                      children: [
                        const SizedBox(height: 30),
                        Text(
                          "POWERED BY",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black.withOpacity(0.3),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.03),
                            ),
                          ),
                          child: Opacity(
                            opacity: 0.65,
                            child: const PoweredByBadge(height: 56),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// STUB PAGES FOR TERMS AND PRIVACY
// ==========================================
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const brandColor = AppColors.brand;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Terms & Conditions",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: brandColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Text(
          "Terms and Conditions for Ryitu.\n\n"
          "1. Acceptance of Terms: By downloading and using the Ryitu application, you agree to comply with and be bound by these terms.\n\n"
          "2. User Content: You are solely responsible for the content you write, publish, or share within the application.\n\n"
          "3. Privacy: We respect your privacy. Please review our Privacy Policy to understand how we collect and use your data.",
          style: TextStyle(fontSize: 15, height: 1.6),
        ),
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    const brandColor = AppColors.brand;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Privacy Policy",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: brandColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Text(
          "Privacy Policy for Ryitu.\n\n"
          "1. Data Collection: We collect standard profile information such as username, mobile number, and constituency to customize your feed and enable notification delivery.\n\n"
          "2. Notifications: We send notification updates via FCM (Firebase Messaging).\n\n"
          "3. Information Sharing: We do not share your private personal data with third parties unless required by law.",
          style: TextStyle(fontSize: 15, height: 1.6),
        ),
      ),
    );
  }
}

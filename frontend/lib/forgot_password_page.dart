import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/branding.dart';

// ============================================================
// STEP 1: FORGOT PASSWORD - ENTER EMAIL PAGE
// ============================================================
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFF0729E8) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar("Please enter your email ID");
      return;
    }

    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar("Please enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.forgotPasswordSendOtpUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (!mounted) return;

      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300 && decoded['success'] == true) {
        _showSnackBar(decoded['message'] ?? "OTP sent to your email successfully", isError: false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyForgotPasswordOtpPage(email: email),
          ),
        );
      } else {
        final errorMsg = decoded['message'] ?? "Failed to send OTP. Please try again.";
        _showSnackBar(errorMsg);
      }
    } catch (e) {
      _showSnackBar("Connection error: Unable to reach server");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFCFDFD), Color(0xFFF7F8FA)],
              ),
            ),
          ),

          // Crimson Decorative Glow
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

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const Center(child: AppLogo(height: 76)),
                  const SizedBox(height: 20),

                  Text(
                    "Forgot Password",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withValues(alpha: 0.85),
                      letterSpacing: -0.5,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Enter your registered email address.\nWe'll send an OTP via email to reset your password.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form Container Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.04),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: "Email ID",
                            labelStyle: TextStyle(
                              color: Colors.black.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            floatingLabelStyle: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            hintText: "Enter your registered email",
                            hintStyle: TextStyle(
                              color: Colors.black.withValues(alpha: 0.2),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: AppColors.brand,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.black.withValues(alpha: 0.08),
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
                        const SizedBox(height: 24),

                        // Send OTP Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0729E8).withValues(alpha: 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _sendOtp,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 52,
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
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Send OTP",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.send_rounded,
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

                  // Return to login button
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.brand),
                    label: const Text(
                      "Back to Sign In",
                      style: TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STEP 2: VERIFY FORGOT PASSWORD OTP PAGE
// ============================================================
class VerifyForgotPasswordOtpPage extends StatefulWidget {
  final String email;

  const VerifyForgotPasswordOtpPage({super.key, required this.email});

  @override
  State<VerifyForgotPasswordOtpPage> createState() => _VerifyForgotPasswordOtpPageState();
}

class _VerifyForgotPasswordOtpPageState extends State<VerifyForgotPasswordOtpPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var fn in _focusNodes) {
      fn.dispose();
    }
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFF0729E8) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onOtpChanged(String value, int index) {
    if (value.length > 1) {
      // User pasted full OTP
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      if (digits.length >= 6) {
        _focusNodes[5].requestFocus();
      } else {
        _focusNodes[digits.length].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.forgotPasswordSendOtpUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email}),
      );

      if (!mounted) return;

      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300 && decoded['success'] == true) {
        _showSnackBar("New OTP sent to your email", isError: false);
        _startResendTimer();
      } else {
        _showSnackBar(decoded['message'] ?? "Failed to resend OTP");
      }
    } catch (_) {
      _showSnackBar("Connection error while resending OTP");
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text.trim()).join();

    if (otp.length < 6) {
      _showSnackBar("Please enter the complete 6-digit OTP");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.forgotPasswordVerifyOtpUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "otp": otp,
        }),
      );

      if (!mounted) return;

      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300 && decoded['success'] == true) {
        _showSnackBar("OTP verified successfully!", isError: false);
        final resetToken = decoded['data']?['resetToken']?.toString() ??
            decoded['token']?.toString();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(
              email: widget.email,
              otp: otp,
              resetToken: resetToken,
            ),
          ),
        );
      } else {
        final errorMsg = decoded['message'] ?? "Invalid or expired OTP";
        _showSnackBar(errorMsg);
      }
    } catch (e) {
      _showSnackBar("Connection error: Unable to verify OTP");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFCFDFD), Color(0xFFF7F8FA)],
              ),
            ),
          ),
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
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Email verification badge
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      color: AppColors.brand,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    "Verify OTP",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withValues(alpha: 0.85),
                      letterSpacing: -0.5,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withValues(alpha: 0.5),
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(text: "We have sent a 6-digit verification code to\n"),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // OTP Box Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.04),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 6 Pin boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            final boxWidth = ((screenWidth - 48 - 48 - 30) / 6).clamp(38.0, 50.0);
                            return SizedBox(
                              width: boxWidth,
                              height: 54,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.brand,
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                onChanged: (v) {
                                  if (v.isEmpty && index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  } else {
                                    _onOtpChanged(v, index);
                                  }
                                },
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 24),

                        // Resend OTP Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _resendCountdown > 0
                                  ? "Resend code in ${_resendCountdown}s"
                                  : "Didn't receive the code? ",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ),
                            if (_resendCountdown == 0)
                              GestureDetector(
                                onTap: _isResending ? null : _resendOtp,
                                child: Text(
                                  _isResending ? "Resending..." : "Resend OTP",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brand,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Verify Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0729E8).withValues(alpha: 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _verifyOtp,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 52,
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
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Verify OTP",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.check_circle_outline_rounded,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STEP 3: RESET NEW PASSWORD PAGE
// ============================================================
class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String otp;
  final String? resetToken;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.otp,
    this.resetToken,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFF0729E8) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.length < 6) {
      _showSnackBar("Password must be at least 6 characters long");
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar("Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.forgotPasswordResetUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "otp": widget.otp,
          "newPassword": password,
          if (widget.resetToken != null) "resetToken": widget.resetToken,
        }),
      );

      if (!mounted) return;

      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300 && decoded['success'] == true) {
        // Show success alert dialog and navigate back to login
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2E7D32),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Password Updated!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your password has been changed successfully. You can now sign in with your new password.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withValues(alpha: 0.55),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(dialogContext); // Close dialog
                        // Pop all routes back to the login screen
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        "Sign In Now",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        final errorMsg = decoded['message'] ?? "Failed to reset password";
        _showSnackBar(errorMsg);
      }
    } catch (e) {
      _showSnackBar("Connection error: Unable to update password");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFCFDFD), Color(0xFFF7F8FA)],
              ),
            ),
          ),
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
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.brand,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    "Set New Password",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withValues(alpha: 0.85),
                      letterSpacing: -0.5,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Please choose a secure new password of at least 6 characters.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Password fields card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.04),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // New Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: "New Password",
                            labelStyle: TextStyle(
                              color: Colors.black.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            floatingLabelStyle: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            hintText: "Enter at least 6 characters",
                            hintStyle: TextStyle(
                              color: Colors.black.withValues(alpha: 0.2),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
                                color: Colors.black.withValues(alpha: 0.35),
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.black.withValues(alpha: 0.08),
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

                        // Confirm Password Field
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            labelStyle: TextStyle(
                              color: Colors.black.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            floatingLabelStyle: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            hintText: "Re-enter new password",
                            hintStyle: TextStyle(
                              color: Colors.black.withValues(alpha: 0.2),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
                                color: Colors.black.withValues(alpha: 0.35),
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.black.withValues(alpha: 0.08),
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

                        const SizedBox(height: 24),

                        // Submit Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0729E8).withValues(alpha: 0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _updatePassword,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 52,
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
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Confirm & Update",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

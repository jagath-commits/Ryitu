import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static final String baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : defaultTargetPlatform == TargetPlatform.android
      ? 'http://192.168.29.182:3001'
      : 'http://localhost:3001';
  static final String apiBaseUrl = '$baseUrl/api';
  static final String forgotPasswordSendOtpUrl =
      '$apiBaseUrl/auth/forgot-password/send-otp';
  static final String forgotPasswordVerifyOtpUrl =
      '$apiBaseUrl/auth/forgot-password/verify-otp';
  static final String forgotPasswordResetUrl =
      '$apiBaseUrl/auth/forgot-password/reset-password';
}

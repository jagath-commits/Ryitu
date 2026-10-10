class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  // Production Render Deployed Backend URL
  static const String liveBaseUrl = 'https://ryitu.onrender.com';

  static final String baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : liveBaseUrl;

  static final String apiBaseUrl = '$baseUrl/api';
  static final String forgotPasswordSendOtpUrl =
      '$apiBaseUrl/auth/forgot-password/send-otp';
  static final String forgotPasswordVerifyOtpUrl =
      '$apiBaseUrl/auth/forgot-password/verify-otp';
  static final String forgotPasswordResetUrl =
      '$apiBaseUrl/auth/forgot-password/reset-password';
}

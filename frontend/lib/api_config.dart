class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  // 🔥 Set to true for local testing on mobile phone (via Wi-Fi / LAN)
  // Set to false to switch back to deployed Render production backend
  static const bool useLocalBackend = true;

  // Your PC's Local Network IPv4 Address on Wi-Fi/Ethernet:
  static const String localBaseUrl = 'http://192.168.29.182:3001';

  // Production Render Deployed Backend URL
  static const String liveBaseUrl = 'https://api.ritpen.com';

  static final String baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : (useLocalBackend ? localBaseUrl : liveBaseUrl);

  static final String apiBaseUrl = '$baseUrl/api';
  static final String forgotPasswordSendOtpUrl =
      '$apiBaseUrl/auth/forgot-password/send-otp';
  static final String forgotPasswordVerifyOtpUrl =
      '$apiBaseUrl/auth/forgot-password/verify-otp';
  static final String forgotPasswordResetUrl =
      '$apiBaseUrl/auth/forgot-password/reset-password';
}

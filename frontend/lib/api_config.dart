class ApiConfig {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  // Set to true for local testing on mobile phone (via Wi-Fi / LAN)
  // Set to false to use the deployed production backend
  static const bool useLocalBackend = true;

  // Your PC's Local Network IPv4 Address on Wi-Fi/Ethernet:
  static const String localBaseUrl = 'http://192.168.29.182:3001';

  // Production Render Deployed Backend URL
  static const String liveBaseUrl = 'https://api.ritpen.com';

  static String activeBaseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : (useLocalBackend ? localBaseUrl : liveBaseUrl);

  static String get baseUrl => activeBaseUrl;

  static String get apiBaseUrl => '$baseUrl/api';
  static String get forgotPasswordSendOtpUrl =>
      '$apiBaseUrl/auth/forgot-password/send-otp';
  static String get forgotPasswordVerifyOtpUrl =>
      '$apiBaseUrl/auth/forgot-password/verify-otp';
  static String get forgotPasswordResetUrl =>
      '$apiBaseUrl/auth/forgot-password/reset-password';
}


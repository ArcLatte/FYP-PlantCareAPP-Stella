class AppConstants {
  // Change this to your machine's local IP when testing on physical device
  // For emulator, 10.0.2.2 maps to your PC's localhost
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // Auth endpoints
  static const String loginUrl = '$baseUrl/auth/login/';
  static const String registerUrl = '$baseUrl/auth/register/';
  static const String logoutUrl = '$baseUrl/auth/logout/';
  static const String changePasswordUrl = '$baseUrl/auth/change-password/';

  // Plant endpoints
  static const String plantsUrl = '$baseUrl/plants/';
  static const String speciesUrl = '$baseUrl/species/';

  // Scan endpoints
  static const String scansUrl = '$baseUrl/scans/';
  static const String scanHistoryUrl = '$baseUrl/scans/history/';

  // Shared preferences keys
  static const String tokenKey = 'auth_token';
  static const String usernameKey = 'username';
}
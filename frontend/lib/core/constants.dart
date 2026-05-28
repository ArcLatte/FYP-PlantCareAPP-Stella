class AppConstants {
  // Change this to your machine's local IP when testing on physical device
  // For emulator, 10.0.2.2 maps to your PC's localhost
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // Root host (no /api) — used for absolute media URLs returned by Django.
  static const String mediaHost = 'http://10.0.2.2:8000';

  // Auth endpoints
  static const String loginUrl = '$baseUrl/auth/login/';
  static const String registerUrl = '$baseUrl/auth/register/';
  static const String logoutUrl = '$baseUrl/auth/logout/';
  static const String changePasswordUrl = '$baseUrl/auth/change-password/';

  // Plant endpoints
  static const String plantsUrl = '$baseUrl/plants/';
  static const String speciesUrl = '$baseUrl/species/';
  static const String locationsUrl = '$baseUrl/locations/';

  // Scan endpoints
  static const String scansUrl = '$baseUrl/scans/';
  static const String scanHistoryUrl = '$baseUrl/scans/history/';

  // Shared preferences keys
  static const String tokenKey = 'auth_token';
  static const String usernameKey = 'username';
  static const String weatherCacheKey = 'cached_weather';
  static const String weatherCacheTimeKey = 'cached_weather_time';
  static const String lastLatKey = 'last_lat';
  static const String lastLonKey = 'last_lon';

  // OpenWeather — paste your key here OR pass --dart-define=OPENWEATHER_KEY=...
  static const String openWeatherApiKey = String.fromEnvironment(
    '3a79944bda3285d599d9f480a168878d',
    defaultValue: '',
  );
}

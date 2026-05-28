import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class Weather {
  final double tempC;
  final int humidity;
  final double? uv;
  final String condition; // e.g. "Sunny", "Cloudy"
  final String iconCode; // e.g. "01d"
  final String? cityName;

  const Weather({
    required this.tempC,
    required this.humidity,
    required this.uv,
    required this.condition,
    required this.iconCode,
    this.cityName,
  });

  Map<String, dynamic> toJson() => {
        'tempC': tempC,
        'humidity': humidity,
        'uv': uv,
        'condition': condition,
        'iconCode': iconCode,
        'cityName': cityName,
      };

  factory Weather.fromJson(Map<String, dynamic> json) => Weather(
        tempC: (json['tempC'] as num).toDouble(),
        humidity: (json['humidity'] as num).toInt(),
        uv: (json['uv'] as num?)?.toDouble(),
        condition: json['condition'] as String,
        iconCode: json['iconCode'] as String,
        cityName: json['cityName'] as String?,
      );

  String get tempDisplay => '${tempC.round()}°';
  String get uvLevel {
    final u = uv;
    if (u == null) return '—';
    if (u < 3) return 'Low';
    if (u < 6) return 'Moderate';
    if (u < 8) return 'High';
    if (u < 11) return 'Very high';
    return 'Extreme';
  }
}

class WeatherService {
  static const _cacheMaxAge = Duration(minutes: 30);

  /// Returns weather for the given coords, hitting the cache when possible.
  /// Set [forceRefresh] for pull-to-refresh.
  static Future<Weather?> getWeather(
    double lat,
    double lon, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _readCache();
      if (cached != null) return cached;
    }

    if (AppConstants.openWeatherApiKey.isEmpty) {
      // No key configured — fall back to whatever we cached most recently
      // (which may be null on first run).
      return _readCache(ignoreAge: true);
    }

    try {
      final currentUri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$lat&lon=$lon&units=metric'
        '&appid=${AppConstants.openWeatherApiKey}',
      );
      final uvUri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/uvi'
        '?lat=$lat&lon=$lon'
        '&appid=${AppConstants.openWeatherApiKey}',
      );

      final currentResp = await http.get(currentUri);
      if (currentResp.statusCode != 200) {
        return _readCache(ignoreAge: true);
      }
      final c = jsonDecode(currentResp.body) as Map<String, dynamic>;

      double? uv;
      try {
        final uvResp = await http.get(uvUri);
        if (uvResp.statusCode == 200) {
          final u = jsonDecode(uvResp.body) as Map<String, dynamic>;
          uv = (u['value'] as num?)?.toDouble();
        }
      } catch (_) {
        // UV endpoint is non-critical.
      }

      final main = c['main'] as Map<String, dynamic>? ?? const {};
      final weatherList = (c['weather'] as List?) ?? const [];
      final firstWeather = (weatherList.isNotEmpty
              ? weatherList.first as Map<String, dynamic>
              : const <String, dynamic>{});

      final weather = Weather(
        tempC: (main['temp'] as num?)?.toDouble() ?? 0,
        humidity: (main['humidity'] as num?)?.toInt() ?? 0,
        uv: uv,
        condition: (firstWeather['main'] ?? '').toString(),
        iconCode: (firstWeather['icon'] ?? '01d').toString(),
        cityName: c['name']?.toString(),
      );
      await _writeCache(weather);
      return weather;
    } catch (_) {
      return _readCache(ignoreAge: true);
    }
  }

  static Future<Weather?> _readCache({bool ignoreAge = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.weatherCacheKey);
    final ts = prefs.getInt(AppConstants.weatherCacheTimeKey);
    if (raw == null || ts == null) return null;
    if (!ignoreAge) {
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _cacheMaxAge.inMilliseconds) return null;
    }
    try {
      return Weather.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(Weather w) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.weatherCacheKey,
      jsonEncode(w.toJson()),
    );
    await prefs.setInt(
      AppConstants.weatherCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}

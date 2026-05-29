// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
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

  String get tempDisplay => '${tempC.floor()}°C';

  /// Material icon matching the OpenWeather condition. Picks a day/night
  /// variant for clear-sky based on the icon-code suffix ('d' or 'n').
  IconData get icon {
    // iconCode looks like "01d", "10n", etc. The first 2 chars are the
    // condition group; the third is 'd' (day) or 'n' (night).
    final group = iconCode.length >= 2 ? iconCode.substring(0, 2) : '01';
    final isNight = iconCode.endsWith('n');
    switch (group) {
      case '01':
        return isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded;
      case '02':
        return isNight ? Icons.nights_stay_rounded : Icons.wb_cloudy_rounded;
      case '03':
      case '04':
        return Icons.cloud_rounded;
      case '09':
        return Icons.grain_rounded;
      case '10':
        return Icons.water_drop_rounded;
      case '11':
        return Icons.thunderstorm_rounded;
      case '13':
        return Icons.ac_unit_rounded;
      case '50':
        return Icons.foggy;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }
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
    print('[WX] getWeather lat=$lat lon=$lon forceRefresh=$forceRefresh');
    if (!forceRefresh) {
      final cached = await _readCache();
      if (cached != null) {
        print('[WX] returning cached (age OK): ${cached.cityName} ${cached.tempDisplay}');
        return cached;
      }
    }

    if (AppConstants.openWeatherApiKey.isEmpty) {
      print('[WX] no API key configured — returning stale cache if any');
      return _readCache(ignoreAge: true);
    }

    try {
      final currentUri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$lat&lon=$lon&units=metric'
        '&appid=${AppConstants.openWeatherApiKey}',
      );
      print('[WX] GET $currentUri');
      final uvUri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/uvi'
        '?lat=$lat&lon=$lon'
        '&appid=${AppConstants.openWeatherApiKey}',
      );

      final currentResp = await http.get(currentUri);
      print('[WX] current status=${currentResp.statusCode} body=${currentResp.body.substring(0, currentResp.body.length > 200 ? 200 : currentResp.body.length)}');
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

      // Reverse-geocode the coords to a real place name. OpenWeather's
      // `name` on /weather is the nearest reporting station's label and
      // often doesn't match the city the user is actually in.
      String? geoName;
      try {
        final geoUri = Uri.parse(
          'https://api.openweathermap.org/geo/1.0/reverse'
          '?lat=$lat&lon=$lon&limit=1'
          '&appid=${AppConstants.openWeatherApiKey}',
        );
        final geoResp = await http.get(geoUri);
        if (geoResp.statusCode == 200) {
          final list = jsonDecode(geoResp.body) as List;
          if (list.isNotEmpty) {
            final first = list.first as Map<String, dynamic>;
            geoName = first['name']?.toString();
          }
        }
      } catch (_) {
        // Non-critical; fall back to the /weather name below.
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
        cityName: geoName ?? c['name']?.toString(),
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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants.dart';
import 'package:frontend/services/weather_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const weather = Weather(
    tempC: 30,
    humidity: 75,
    uv: 5,
    condition: 'Clouds',
    iconCode: '03d',
    cityName: 'Kuala Lumpur',
    timezoneOffsetSeconds: 28800,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.weatherCacheKey: jsonEncode(weather.toJson()),
      AppConstants.weatherCacheTimeKey: DateTime.now().millisecondsSinceEpoch,
      AppConstants.weatherCacheLatKey: 3.1390,
      AppConstants.weatherCacheLonKey: 101.6869,
    });
  });

  test('returns cached weather for the same area', () async {
    final cached = await WeatherService.getCachedWeather(
      lat: 3.14,
      lon: 101.69,
    );

    expect(cached?.cityName, 'Kuala Lumpur');
    expect(cached?.timezoneOffsetSeconds, 28800);
  });

  test('rejects cached weather after moving to another location', () async {
    final cached = await WeatherService.getCachedWeather(
      ignoreAge: true,
      lat: 5.4141,
      lon: 100.3288,
    );

    expect(cached, isNull);
  });

  test('distance calculation is zero for identical coordinates', () {
    expect(WeatherService.distanceKm(3.139, 101.6869, 3.139, 101.6869), 0);
  });
}

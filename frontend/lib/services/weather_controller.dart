import 'dart:async';

import 'package:flutter/widgets.dart';

import 'location_service.dart';
import 'weather_service.dart';

/// App-wide source of truth for location-based weather.
///
/// Home and Tasks listen to the same instance, so a refresh in either place
/// updates both retained tab screens. It also refreshes after app resume and
/// periodically while the app remains active.
class WeatherController extends ChangeNotifier with WidgetsBindingObserver {
  WeatherController._();

  static final WeatherController instance = WeatherController._();
  static const _refreshInterval = Duration(minutes: 15);

  Weather? _weather;
  Weather? get weather => _weather;

  bool _started = false;
  Timer? _timer;
  Future<void>? _refreshInFlight;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      _refreshInterval,
      (_) => refresh(forceRefresh: true),
    );
    refresh(forceRefresh: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh(forceRefresh: true);
    }
  }

  Future<void> refresh({bool forceRefresh = false}) {
    final active = _refreshInFlight;
    if (active != null) return active;

    final future = _refresh(forceRefresh: forceRefresh);
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<void> _refresh({required bool forceRefresh}) async {
    // Show a matching persisted result immediately while GPS/network work is
    // in progress. Old caches without coordinates are intentionally ignored.
    final cachedLocation = await LocationService.getCached();
    if (_weather == null && cachedLocation != null) {
      final cachedWeather = await WeatherService.getCachedWeather(
        ignoreAge: true,
        lat: cachedLocation.lat,
        lon: cachedLocation.lon,
      );
      _setWeather(cachedWeather);
    }

    // A live fix on first load, app resume, periodic refresh, and pull-down
    // ensures moving users do not remain pinned to an OS/cache location.
    final location = await LocationService.getCurrent(
      forceRefresh: forceRefresh || _weather == null,
    );
    if (location == null) return;

    final latest = await WeatherService.getWeather(
      location.lat,
      location.lon,
      forceRefresh: forceRefresh,
    );
    _setWeather(latest);
  }

  void _setWeather(Weather? value) {
    if (value == null) return;
    _weather = value;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _timer?.cancel();
    _timer = null;
    _weather = null;
    _refreshInFlight = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}

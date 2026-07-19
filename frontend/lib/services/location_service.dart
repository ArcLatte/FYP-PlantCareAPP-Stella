// ignore_for_file: avoid_print
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class DeviceLocation {
  final double lat;
  final double lon;
  const DeviceLocation(this.lat, this.lon);
}

class LocationService {
  static Future<LocationPermission>? _permissionRequestInFlight;

  /// Coalesces concurrent startup checks into one Android permission request.
  /// Permission is requested before checking GPS state, because disabled
  /// location services must not suppress the runtime permission prompt.
  static Future<LocationPermission> ensurePermission() {
    final active = _permissionRequestInFlight;
    if (active != null) return active;

    final future = _ensurePermission();
    _permissionRequestInFlight = future;
    return future.whenComplete(() => _permissionRequestInFlight = null);
  }

  static Future<LocationPermission> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    print('[LOC] permission=$permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      print('[LOC] permission after request=$permission');
    }
    return permission;
  }

  /// Request runtime permission and fetch the current GPS fix.
  /// Returns null if the user denied or the OS could not produce a fix.
  static Future<DeviceLocation?> getCurrent({bool forceRefresh = false}) async {
    print('[LOC] getCurrent forceRefresh=$forceRefresh');

    final permission = await ensurePermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    print('[LOC] serviceEnabled=$serviceEnabled');
    if (!serviceEnabled) return null;

    // Try a live fix first when forceRefresh — but with a short timeout
    // because emulators frequently hang here.
    if (forceRefresh) {
      try {
        print('[LOC] requesting current position (forceRefresh)…');
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 4),
          ),
        );
        print('[LOC] current=(${pos.latitude}, ${pos.longitude})');
        final loc = DeviceLocation(pos.latitude, pos.longitude);
        await _cache(loc);
        return loc;
      } catch (e) {
        print('[LOC] current position error: $e — trying position stream');
      }

      // Stream fallback: subscribing often wakes the mock-location provider
      // on emulators where the single-shot call silently hangs.
      try {
        final pos = await Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
          ),
        ).first.timeout(const Duration(seconds: 4));
        print('[LOC] stream=(${pos.latitude}, ${pos.longitude})');
        final loc = DeviceLocation(pos.latitude, pos.longitude);
        await _cache(loc);
        return loc;
      } catch (e) {
        print('[LOC] stream error: $e — trying lastKnown');
      }
    }

    // lastKnown is the OS-level "freshest fix any app has obtained" — on
    // the emulator this reflects the Extended Controls value as soon as
    // you click Set Location. We prefer this over our SharedPreferences
    // cache because it's the OS speaking, not our stale copy.
    try {
      final last = await Geolocator.getLastKnownPosition();
      print('[LOC] lastKnown=$last');
      if (last != null) {
        final loc = DeviceLocation(last.latitude, last.longitude);
        await _cache(loc);
        return loc;
      }
    } catch (e) {
      print('[LOC] lastKnown error: $e');
    }

    // Last resort: a live fix on the slow path (not forceRefresh).
    if (!forceRefresh) {
      try {
        print('[LOC] requesting current position (slow path)…');
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
        print('[LOC] current=(${pos.latitude}, ${pos.longitude})');
        final loc = DeviceLocation(pos.latitude, pos.longitude);
        await _cache(loc);
        return loc;
      } catch (e) {
        print('[LOC] current position error: $e');
      }
    }

    // Absolutely nothing fresh — fall back to whatever we last persisted.
    print('[LOC] falling back to SharedPreferences cache');
    return getCached();
  }

  /// Read the last successful location from SharedPreferences (if any).
  /// Useful for painting the weather card immediately before a fresh fix lands.
  static Future<DeviceLocation?> getCached() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(AppConstants.lastLatKey);
    final lon = prefs.getDouble(AppConstants.lastLonKey);
    if (lat == null || lon == null) return null;
    return DeviceLocation(lat, lon);
  }

  static Future<void> _cache(DeviceLocation loc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.lastLatKey, loc.lat);
    await prefs.setDouble(AppConstants.lastLonKey, loc.lon);
  }
}

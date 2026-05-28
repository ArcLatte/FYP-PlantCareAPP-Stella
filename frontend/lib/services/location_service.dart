import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class DeviceLocation {
  final double lat;
  final double lon;
  const DeviceLocation(this.lat, this.lon);
}

class LocationService {
  /// Request runtime permission and fetch the current GPS fix.
  /// Returns null if the user denied or the OS could not produce a fix.
  static Future<DeviceLocation?> getCurrent() async {
    // 1. Make sure location services are enabled at the OS level.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    // 2. Check / request app-level permission.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final loc = DeviceLocation(pos.latitude, pos.longitude);
      await _cache(loc);
      return loc;
    } catch (_) {
      // GPS timed out or failed — fall back to the cached value if we have one.
      return getCached();
    }
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

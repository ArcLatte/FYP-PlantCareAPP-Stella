import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/user.dart';
import '../models/plant.dart';
import '../models/scan.dart';
import '../models/streak.dart';
import '../models/activity.dart';
import '../models/user_profile.dart';
import '../models/achievement.dart';
import '../models/xp_result.dart';

class ApiService {
  /// Side-channel for XP awards. Care/scan/plant-create/login endpoints
  /// populate this whenever the backend returns an `xp_gained` field; the
  /// UI calls [consumeLastXpResult] right after to surface a toast. Lets
  /// us avoid changing every existing call-site's return type.
  static XpResult? lastXpResult;

  static XpResult? consumeLastXpResult() {
    final r = lastXpResult;
    lastXpResult = null;
    return r;
  }

  /// Internal helper: pluck XP fields from a response body and stash them.
  static void _captureXp(Map<String, dynamic> body) {
    final r = XpResult.fromJsonOrNull(body);
    if (r != null && r.hasAnything) {
      lastXpResult = r;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };
  }

  /// Authed GET with expired-session handling: a 401 clears the stored
  /// credentials (so the router guard bounces to /login on the next
  /// navigation) and surfaces a friendly error instead of a raw status.
  static Future<http.Response> _authGet(String url) async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.tokenKey);
      await prefs.remove(AppConstants.usernameKey);
      throw Exception('Session expired — please log in again');
    }
    return response;
  }

  // ─── Auth ───────────────────────────────────────────────────

  static Future<User> login(String username, String password) async {
    final response = await http.post(
      Uri.parse(AppConstants.loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _captureXp(body);
      return User.fromJson(body);
    }
    throw Exception(jsonDecode(response.body)['non_field_errors']?[0] ??
        'Login failed');
  }

  static Future<User> register(
      String username, String email, String password) async {
    final response = await http.post(
      Uri.parse(AppConstants.registerUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    }
    final errors = jsonDecode(response.body);
    throw Exception(errors.values.first[0] ?? 'Registration failed');
  }

  static Future<void> logout() async {
    final headers = await _authHeaders();
    await http.post(Uri.parse(AppConstants.logoutUrl), headers: headers);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.usernameKey);
  }

  static Future<void> changePassword(
      String oldPassword, String newPassword) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(AppConstants.changePasswordUrl),
      headers: headers,
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed');
    }
  }

  // ─── Species ────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSpecies() async {
    final response = await _authGet(AppConstants.speciesUrl);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load species');
  }

  // ─── Locations ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getLocations() async {
    final response = await _authGet(AppConstants.locationsUrl);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load locations');
  }

  static Future<Map<String, dynamic>> createLocation(String name) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(AppConstants.locationsUrl),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to create location');
  }

  static Future<void> deleteLocation(int id) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${AppConstants.locationsUrl}$id/'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete location');
    }
  }

  // ─── Plants ─────────────────────────────────────────────────

  static Future<List<Plant>> getPlants() async {
    final response = await _authGet(AppConstants.plantsUrl);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((p) => Plant.fromJson(p))
          .toList();
    }
    throw Exception('Failed to load plants');
  }

  static Future<Plant> getPlant(int id) async {
    final response = await _authGet('${AppConstants.plantsUrl}$id/');
    if (response.statusCode == 200) {
      return Plant.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load plant');
  }

  static Future<Plant> createPlant(
    String name,
    int speciesId,
    String? notes, {
    String? location,
    int? wateringFreqDays,
    DateTime? lastWatered,
    DateTime? lastFertilized,
    DateTime? lastMisted,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(AppConstants.plantsUrl),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'species': speciesId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (location != null && location.isNotEmpty) 'location': location,
        'watering_freq_days': ?wateringFreqDays,
        'last_watered': ?lastWatered?.toIso8601String(),
        'last_fertilized': ?lastFertilized?.toIso8601String(),
        'last_misted': ?lastMisted?.toIso8601String(),
      }),
    );
    if (response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _captureXp(body);
      return Plant.fromJson(body);
    }
    throw Exception('Failed to create plant');
  }

  static Future<Plant> waterPlant(int id) async {
    return _careAction(id, 'water');
  }

  static Future<Plant> fertilizePlant(int id) async {
    return _careAction(id, 'fertilize');
  }

  static Future<Plant> mistPlant(int id) async {
    return _careAction(id, 'mist');
  }

  /// Shared POST for the three daily care actions (water/fertilize/mist).
  static Future<Plant> _careAction(int id, String activity) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${AppConstants.plantsUrl}$id/$activity/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _captureXp(body);
      return Plant.fromJson(body);
    }
    throw Exception('Failed to $activity plant (status ${response.statusCode})');
  }

  static Future<Streak> getStreak() async {
    final response = await _authGet(AppConstants.streakUrl);
    if (response.statusCode == 200) {
      return Streak.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load streak');
  }

  static Future<List<ActivityEvent>> getActivity() async {
    final response = await _authGet(AppConstants.activityUrl);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => ActivityEvent.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load activity');
  }

  // ─── Profile + achievements ────────────────────────────────

  static Future<UserProfile> getProfile() async {
    final response = await _authGet(AppConstants.profileUrl);
    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load profile');
  }

  static Future<List<Achievement>> getAchievements() async {
    final response = await _authGet(AppConstants.achievementsUrl);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load achievements');
  }

  static Future<Achievement> pinAchievement(String code) =>
      _togglePin(code, pin: true);
  static Future<Achievement> unpinAchievement(String code) =>
      _togglePin(code, pin: false);

  static Future<Achievement> _togglePin(String code, {required bool pin}) async {
    final headers = await _authHeaders();
    final action = pin ? 'pin' : 'unpin';
    final response = await http.post(
      Uri.parse('${AppConstants.achievementsUrl}$code/$action/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return Achievement.fromJson(jsonDecode(response.body));
    }
    final body = jsonDecode(response.body);
    throw Exception(
      (body is Map && body['error'] is String)
          ? body['error'] as String
          : 'Failed to $action achievement',
    );
  }

  /// Edit any subset of plant metadata. If [photo] is provided the request is
  /// sent as multipart so the new image lands in the same write as the rest
  /// of the changes; otherwise a JSON PUT is used.
  static Future<Plant> updatePlant(
    int id, {
    String? name,
    String? notes,
    String? location,
    int? wateringFreqDays,
    int? speciesId,
    File? photo,
  }) async {
    final url = Uri.parse('${AppConstants.plantsUrl}$id/');

    if (photo != null) {
      final token = await _getToken();
      final request = http.MultipartRequest('PUT', url);
      request.headers['Authorization'] = 'Token $token';
      if (name != null) request.fields['name'] = name;
      if (notes != null) request.fields['notes'] = notes;
      if (location != null) request.fields['location'] = location;
      if (wateringFreqDays != null) {
        request.fields['watering_freq_days'] = wateringFreqDays.toString();
      }
      if (speciesId != null) {
        request.fields['species'] = speciesId.toString();
      }
      request.files.add(
        await http.MultipartFile.fromPath('photo', photo.path),
      );
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return Plant.fromJson(jsonDecode(response.body));
      }
      throw Exception('Failed to update plant (status ${response.statusCode})');
    }

    final headers = await _authHeaders();
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode({
        'name': ?name,
        'notes': ?notes,
        'location': ?location,
        'watering_freq_days': ?wateringFreqDays,
        'species': ?speciesId,
      }),
    );
    if (response.statusCode == 200) {
      return Plant.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update plant');
  }

  static Future<void> deletePlant(int id) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${AppConstants.plantsUrl}$id/'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete plant (status ${response.statusCode})');
    }
  }

  // ─── Scans ──────────────────────────────────────────────────

  static Future<ScanResult> scanPlant(int plantId, File imageFile) async {
    final token = await _getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(AppConstants.scansUrl),
    );
    request.headers['Authorization'] = 'Token $token';
    request.fields['plant_id'] = plantId.toString();
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
    ));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _captureXp(body);
      return ScanResult.fromJson(body);
    }
    throw Exception('Scan failed');
  }

  static Future<ScanResult> confirmDisease(
      int scanId, String diseaseLabel) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('${AppConstants.scansUrl}$scanId/confirm/'),
      headers: headers,
      body: jsonEncode({'label': diseaseLabel}),
    );
    if (response.statusCode == 200) {
      return ScanResult.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to confirm disease');
  }

  static Future<List<ScanResult>> getPlantScans(int plantId) async {
    final response = await _authGet('${AppConstants.plantsUrl}$plantId/scans/');
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((s) => ScanResult.fromJson(s))
          .toList();
    }
    throw Exception('Failed to load scans');
  }

  static Future<List<ScanResult>> getAllScans() async {
    final response = await _authGet(AppConstants.scanHistoryUrl);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((s) => ScanResult.fromJson(s))
          .toList();
    }
    throw Exception('Failed to load history');
  }

  static Future<ScanResult> getScan(int scanId) async {
    final response = await _authGet('${AppConstants.scansUrl}$scanId/');
    if (response.statusCode == 200) {
      return ScanResult.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load scan');
  }

  static Future<void> deleteScan(int scanId) async {
    final headers = await _authHeaders();
    await http.delete(
      Uri.parse('${AppConstants.scansUrl}$scanId/'),
      headers: headers,
    );
  }
}
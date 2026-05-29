import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/user.dart';
import '../models/plant.dart';
import '../models/scan.dart';

class ApiService {
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

  // ─── Auth ───────────────────────────────────────────────────

  static Future<User> login(String username, String password) async {
    final response = await http.post(
      Uri.parse(AppConstants.loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
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
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(AppConstants.speciesUrl),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to load species');
  }

  // ─── Locations ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getLocations() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(AppConstants.locationsUrl),
      headers: headers,
    );
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
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(AppConstants.plantsUrl),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((p) => Plant.fromJson(p))
          .toList();
    }
    throw Exception('Failed to load plants');
  }

  static Future<Plant> getPlant(int id) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${AppConstants.plantsUrl}$id/'),
      headers: headers,
    );
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
      }),
    );
    if (response.statusCode == 201) {
      return Plant.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create plant');
  }

  static Future<Plant> waterPlant(int id) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${AppConstants.plantsUrl}$id/water/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return Plant.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to water plant (status ${response.statusCode})');
  }

  static Future<Plant> updatePlant(
      int id, String name, String? notes) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('${AppConstants.plantsUrl}$id/'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        'notes': ?notes,
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
      return ScanResult.fromJson(jsonDecode(response.body));
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
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${AppConstants.plantsUrl}$plantId/scans/'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((s) => ScanResult.fromJson(s))
          .toList();
    }
    throw Exception('Failed to load scans');
  }

  static Future<List<ScanResult>> getAllScans() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse(AppConstants.scanHistoryUrl),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((s) => ScanResult.fromJson(s))
          .toList();
    }
    throw Exception('Failed to load history');
  }

  static Future<ScanResult> getScan(int scanId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${AppConstants.scansUrl}$scanId/'),
      headers: headers,
    );
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
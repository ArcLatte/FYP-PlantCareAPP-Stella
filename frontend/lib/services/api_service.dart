import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_error.dart';
import '../core/constants.dart';
import '../models/user.dart';
import '../models/plant.dart';
import '../models/scan.dart';
import '../models/species.dart';
import '../models/disease.dart';
import '../models/streak.dart';
import '../models/activity.dart';
import '../models/user_profile.dart';
import '../models/achievement.dart';
import '../models/cosmetic.dart';
import '../models/weekly_challenge.dart';
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

  static String _errorMessageFromResponse(
    http.Response response,
    String fallback,
  ) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        for (final key in ['error', 'detail', 'message', 'non_field_errors']) {
          final message = _stringFromErrorValue(decoded[key]);
          if (message != null) return message;
        }
        for (final value in decoded.values) {
          final message = _stringFromErrorValue(value);
          if (message != null) return message;
        }
      }
      final message = _stringFromErrorValue(decoded);
      if (message != null) return message;
    } catch (_) {
      // Fall through to the endpoint-specific fallback for non-JSON errors.
    }
    return fallback;
  }

  static String? _stringFromErrorValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value;
    if (value is List && value.isNotEmpty) {
      return _stringFromErrorValue(value.first);
    }
    return null;
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<String?> currentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.usernameKey);
  }

  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final timezoneOffset = _timezoneOffsetMinutes(prefs);
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
      'X-Timezone-Offset-Minutes': '$timezoneOffset',
    };
  }

  static int _timezoneOffsetMinutes(SharedPreferences prefs) {
    return prefs.getInt(AppConstants.locationTimezoneOffsetKey) ??
        DateTime.now().timeZoneOffset.inMinutes;
  }

  static Future<void> _addTimezoneHeader(Map<String, String> headers) async {
    final prefs = await SharedPreferences.getInstance();
    headers['X-Timezone-Offset-Minutes'] = '${_timezoneOffsetMinutes(prefs)}';
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
      throw const AppException(
        'Session expired — please log in again',
        code: 'session_expired',
      );
    }
    return response;
  }

  // ─── Auth ───────────────────────────────────────────────────

  static Future<User> login(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final response = await http.post(
      Uri.parse(AppConstants.loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'timezone_offset_minutes': _timezoneOffsetMinutes(prefs),
      }),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _captureXp(body);
      return User.fromJson(body);
    }
    throw AppException(_errorMessageFromResponse(response, 'Login failed'));
  }

  static Future<User> register(
    String username,
    String email,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final response = await http.post(
      Uri.parse(AppConstants.registerUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'timezone_offset_minutes': _timezoneOffsetMinutes(prefs),
      }),
    );
    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw AppException(
      _errorMessageFromResponse(response, 'Registration failed'),
    );
  }

  static Future<void> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse(AppConstants.passwordResetRequestUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) {
      throw AppException(
        _errorMessageFromResponse(response, 'Could not send reset code'),
      );
    }
  }

  static Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse(AppConstants.passwordResetVerifyUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (response.statusCode != 200) {
      throw AppException(
        _errorMessageFromResponse(response, 'Could not verify reset code'),
      );
    }
  }

  static Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse(AppConstants.passwordResetConfirmUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode != 200) {
      throw AppException(
        _errorMessageFromResponse(response, 'Could not reset password'),
      );
    }
  }

  static Future<void> logout() async {
    final headers = await _authHeaders();
    await http.post(Uri.parse(AppConstants.logoutUrl), headers: headers);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.usernameKey);
  }

  static Future<void> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
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
      throw AppException(jsonDecode(response.body)['error'] ?? 'Failed');
    }
  }

  // ─── Species ────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSpecies() async {
    final response = await _authGet(AppConstants.speciesUrl);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw const AppException('Failed to load species');
  }

  /// Full reference entry for one species (Library species page).
  static Future<SpeciesDetail> getSpeciesDetail(int id) async {
    final response = await _authGet('${AppConstants.speciesUrl}$id/');
    if (response.statusCode == 200) {
      return SpeciesDetail.fromJson(jsonDecode(response.body));
    }
    throw const AppException('Failed to load species');
  }

  // ─── Locations ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getLocations() async {
    final response = await _authGet(AppConstants.locationsUrl);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw const AppException('Failed to load locations');
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
    throw const AppException('Failed to create location');
  }

  static Future<void> deleteLocation(int id) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${AppConstants.locationsUrl}$id/'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AppException('Failed to delete location');
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
    throw const AppException('Failed to load plants');
  }

  static Future<Plant> getPlant(int id) async {
    final response = await _authGet('${AppConstants.plantsUrl}$id/');
    if (response.statusCode == 200) {
      return Plant.fromJson(jsonDecode(response.body));
    }
    throw const AppException('Failed to load plant');
  }

  static Future<Plant> createPlant(
    String name,
    int speciesId,
    String? notes, {
    String? location,
    int? wateringFreqDays,
    int? fertilizerFreqDays,
    int? mistingFreqDays,
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
        'fertilizer_freq_days': ?fertilizerFreqDays,
        'misting_freq_days': ?mistingFreqDays,
        if (lastWatered != null) 'last_watered': lastWatered.toIso8601String(),
        if (lastFertilized != null)
          'last_fertilized': lastFertilized.toIso8601String(),
        if (lastMisted != null) 'last_misted': lastMisted.toIso8601String(),
      }),
    );
    if (response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _captureXp(body);
      return Plant.fromJson(body);
    }
    throw const AppException('Failed to create plant');
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

  /// Append a free-text journal note to a plant. Returns the created entry in
  /// the [ActivityEvent] shape so the caller can prepend it to the timeline.
  /// Unlike the care actions this awards no XP and doesn't change the plant.
  static Future<ActivityEvent> addPlantNote(
    int id,
    String text, {
    String? title,
    List<File> photos = const [],
  }) async {
    final url = Uri.parse('${AppConstants.plantsUrl}$id/note/');
    final http.Response response;
    if (photos.isNotEmpty) {
      final token = await _getToken();
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Token $token';
      await _addTimezoneHeader(request.headers);
      request.fields['note'] = text;
      request.fields['title'] = title ?? '';
      for (final photo in photos) {
        request.files.add(
          await http.MultipartFile.fromPath('photos', photo.path),
        );
      }
      response = await http.Response.fromStream(await request.send());
    } else {
      response = await http.post(
        url,
        headers: await _authHeaders(),
        body: jsonEncode({'note': text, 'title': title ?? ''}),
      );
    }
    if (response.statusCode == 201) {
      return ActivityEvent.fromJson(jsonDecode(response.body));
    }
    final decoded = jsonDecode(response.body);
    throw AppException(
      (decoded is Map && decoded['error'] is String)
          ? decoded['error'] as String
          : 'Failed to add note',
    );
  }

  /// Edit an existing journal note, appending and removing selected images.
  static Future<ActivityEvent> updatePlantNote(
    int plantId,
    int logId,
    String text, {
    String? title,
    List<File> photos = const [],
    Set<int> removeImageIds = const {},
    bool removeLegacyPhoto = false,
  }) async {
    final url = Uri.parse('${AppConstants.plantsUrl}$plantId/note/$logId/');
    final http.Response response;
    if (photos.isNotEmpty) {
      final token = await _getToken();
      final request = http.MultipartRequest('PUT', url);
      request.headers['Authorization'] = 'Token $token';
      await _addTimezoneHeader(request.headers);
      request.fields['note'] = text;
      request.fields['title'] = title ?? '';
      request.fields['remove_image_ids'] = jsonEncode(removeImageIds.toList());
      if (removeLegacyPhoto) request.fields['remove_photo'] = 'true';
      for (final photo in photos) {
        request.files.add(
          await http.MultipartFile.fromPath('photos', photo.path),
        );
      }
      response = await http.Response.fromStream(await request.send());
    } else {
      response = await http.put(
        url,
        headers: await _authHeaders(),
        body: jsonEncode({
          'note': text,
          'title': title ?? '',
          'remove_image_ids': removeImageIds.toList(),
          if (removeLegacyPhoto) 'remove_photo': true,
        }),
      );
    }
    if (response.statusCode == 200) {
      return ActivityEvent.fromJson(jsonDecode(response.body));
    }
    final decoded = jsonDecode(response.body);
    throw AppException(
      (decoded is Map && decoded['error'] is String)
          ? decoded['error'] as String
          : 'Failed to update note',
    );
  }

  /// Delete a journal note.
  static Future<void> deletePlantNote(int plantId, int logId) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.plantsUrl}$plantId/note/$logId/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw const AppException('Could not delete the note. Please try again.');
    }
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
    throw AppException(
      _errorMessageFromResponse(response, 'Could not log this care activity.'),
    );
  }

  static Future<Streak> getStreak() async {
    final response = await _authGet(AppConstants.streakUrl);
    if (response.statusCode == 200) {
      return Streak.fromJson(jsonDecode(response.body));
    }
    throw const AppException('Failed to load streak');
  }

  static Future<StreakCalendar> getStreakCalendar() async {
    final response = await _authGet(AppConstants.streakCalendarUrl);
    if (response.statusCode == 200) {
      return StreakCalendar.fromJson(jsonDecode(response.body));
    }
    throw const AppException('Failed to load streak calendar');
  }

  static Future<WeeklyChallenge> getWeeklyChallenge() async {
    final response = await _authGet(AppConstants.weeklyChallengeUrl);
    if (response.statusCode == 200) {
      return WeeklyChallenge.fromJson(jsonDecode(response.body));
    }
    throw const AppException('Failed to load weekly challenge');
  }

  static Future<List<ActivityEvent>> getActivity() async {
    final response = await _authGet(AppConstants.activityUrl);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => ActivityEvent.fromJson(e))
          .toList();
    }
    throw const AppException('Failed to load activity');
  }

  // ─── Profile + achievements ────────────────────────────────

  static Future<UserProfile> getProfile() async {
    final response = await _authGet(AppConstants.profileUrl);
    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body));
    }
    throw const AppException('Failed to load profile');
  }

  /// Update any subset of account fields (Settings screen). If [avatar] is
  /// provided the request is multipart so the image rides along; pass
  /// [removeAvatar] to clear the current picture. Returns the fresh profile.
  static Future<UserProfile> updateProfile({
    String? username,
    String? email,
    File? avatar,
    bool removeAvatar = false,
  }) async {
    final url = Uri.parse(AppConstants.profileUrl);
    final http.Response response;
    if (avatar != null) {
      final token = await _getToken();
      final request = http.MultipartRequest('PATCH', url);
      request.headers['Authorization'] = 'Token $token';
      await _addTimezoneHeader(request.headers);
      if (username != null) request.fields['username'] = username;
      if (email != null) request.fields['email'] = email;
      request.files.add(
        await http.MultipartFile.fromPath('avatar', avatar.path),
      );
      response = await http.Response.fromStream(await request.send());
    } else {
      response = await http.patch(
        url,
        headers: await _authHeaders(),
        body: jsonEncode({
          'username': ?username,
          'email': ?email,
          if (removeAvatar) 'remove_avatar': true,
        }),
      );
    }
    if (response.statusCode == 200) {
      final profile = UserProfile.fromJson(jsonDecode(response.body));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.usernameKey, profile.username);
      return profile;
    }
    throw AppException(
      _errorMessageFromResponse(response, 'Failed to update profile'),
    );
  }

  /// Permanently delete the account (password-confirmed), then clear local
  /// credentials so the router guard bounces to /login.
  static Future<void> deleteAccount(String password) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse(AppConstants.deleteAccountUrl),
      headers: headers,
      body: jsonEncode({'password': password}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw AppException(
        (body is Map && body['error'] is String)
            ? body['error'] as String
            : 'Failed to delete account',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.usernameKey);
  }

  static Future<List<Achievement>> getAchievements() async {
    final response = await _authGet(AppConstants.achievementsUrl);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw const AppException('Failed to load achievements');
  }

  // ─── Seed shop ─────────────────────────────────────────────

  static Future<ShopState> getShop() async {
    final response = await _authGet(AppConstants.shopUrl);
    if (response.statusCode == 200) {
      return ShopState.fromJson(jsonDecode(response.body));
    }
    throw const AppException('Failed to load shop');
  }

  static Future<ShopState> buyCosmetic(String code) => _shopAction(code, 'buy');

  /// Equip toggles: equipping the currently-equipped item unequips it.
  static Future<ShopState> equipCosmetic(String code) =>
      _shopAction(code, 'equip');

  /// Shared buy/equip POST. Both endpoints return `{seeds, item}`; the shop
  /// screen refetches the full catalog after, so only the balance matters
  /// here — wrap the single item into a [ShopState] for a uniform return.
  static Future<ShopState> _shopAction(String code, String action) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${AppConstants.shopUrl}$code/$action/'),
      headers: headers,
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return ShopState(
        seeds: (body['seeds'] as num?)?.toInt() ?? 0,
        items: [Cosmetic.fromJson(body['item'] as Map<String, dynamic>)],
      );
    }
    throw AppException(
      (body is Map && body['error'] is String)
          ? body['error'] as String
          : 'Failed to $action item',
    );
  }

  static Future<Achievement> pinAchievement(String code) =>
      _togglePin(code, pin: true);
  static Future<Achievement> unpinAchievement(String code) =>
      _togglePin(code, pin: false);

  static Future<Achievement> _togglePin(
    String code, {
    required bool pin,
  }) async {
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
    throw AppException(
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
    int? fertilizerFreqDays,
    int? mistingFreqDays,
    bool clearFertilizerSchedule = false,
    bool clearMistingSchedule = false,
    int? speciesId,
    File? photo,
  }) async {
    final url = Uri.parse('${AppConstants.plantsUrl}$id/');

    if (photo != null) {
      final token = await _getToken();
      final request = http.MultipartRequest('PUT', url);
      request.headers['Authorization'] = 'Token $token';
      await _addTimezoneHeader(request.headers);
      if (name != null) request.fields['name'] = name;
      if (notes != null) request.fields['notes'] = notes;
      if (location != null) request.fields['location'] = location;
      if (wateringFreqDays != null) {
        request.fields['watering_freq_days'] = wateringFreqDays.toString();
      }
      if (clearFertilizerSchedule) {
        request.fields['fertilizer_freq_days'] = '';
      } else if (fertilizerFreqDays != null) {
        request.fields['fertilizer_freq_days'] = fertilizerFreqDays.toString();
      }
      if (clearMistingSchedule) {
        request.fields['misting_freq_days'] = '';
      } else if (mistingFreqDays != null) {
        request.fields['misting_freq_days'] = mistingFreqDays.toString();
      }
      if (speciesId != null) {
        request.fields['species'] = speciesId.toString();
      }
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return Plant.fromJson(jsonDecode(response.body));
      }
      throw AppException(
        _errorMessageFromResponse(response, 'Could not update the plant.'),
      );
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
        if (clearFertilizerSchedule)
          'fertilizer_freq_days': null
        else
          'fertilizer_freq_days': ?fertilizerFreqDays,
        if (clearMistingSchedule)
          'misting_freq_days': null
        else
          'misting_freq_days': ?mistingFreqDays,
        'species': ?speciesId,
      }),
    );
    if (response.statusCode == 200) {
      return Plant.fromJson(jsonDecode(response.body));
    }
    throw AppException(
      _errorMessageFromResponse(response, 'Could not update the plant.'),
    );
  }

  static Future<void> deletePlant(int id) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${AppConstants.plantsUrl}$id/'),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(
        _errorMessageFromResponse(response, 'Could not delete the plant.'),
      );
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
    await _addTimezoneHeader(request.headers);
    request.fields['plant_id'] = plantId.toString();
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _captureXp(body);
      return ScanResult.fromJson(body);
    }
    throw AppException(_errorMessageFromResponse(response, 'Scan failed'));
  }

  static Future<ScanResult> confirmDisease(
    int scanId,
    String diseaseLabel,
  ) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('${AppConstants.scansUrl}$scanId/confirm/'),
      headers: headers,
      body: jsonEncode({'label': diseaseLabel}),
    );
    if (response.statusCode == 200) {
      return ScanResult.fromJson(jsonDecode(response.body));
    }
    throw AppException(
      _errorMessageFromResponse(response, 'Could not save the diagnosis.'),
    );
  }

  static Future<List<ScanResult>> getPlantScans(int plantId) async {
    final response = await _authGet('${AppConstants.plantsUrl}$plantId/scans/');
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((s) => ScanResult.fromJson(s))
          .toList();
    }
    throw const AppException('Failed to load scans');
  }

  /// Per-plant unified history: care events (water/fertilize/mist) merged with
  /// scans, reverse-chronological. Same payload shape as [getActivity].
  static Future<List<ActivityEvent>> getPlantActivity(int plantId) async {
    final response = await _authGet(
      '${AppConstants.plantsUrl}$plantId/activity/',
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => ActivityEvent.fromJson(e))
          .toList();
    }
    throw const AppException('Failed to load plant activity');
  }

  static Future<List<ScanResult>> getAllScans() async {
    final response = await _authGet(AppConstants.scanHistoryUrl);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((s) => ScanResult.fromJson(s))
          .toList();
    }
    throw const AppException('Failed to load history');
  }

  static Future<ScanResult> getScan(int scanId) async {
    final response = await _authGet('${AppConstants.scansUrl}$scanId/');
    if (response.statusCode == 200) {
      return ScanResult.fromJson(jsonDecode(response.body));
    }
    throw const AppException('Failed to load scan');
  }

  static Future<void> deleteScan(int scanId) async {
    final headers = await _authHeaders();
    await http.delete(
      Uri.parse('${AppConstants.scansUrl}$scanId/'),
      headers: headers,
    );
  }

  // ─── Disease knowledge base ─────────────────────────────────

  static Future<Disease> getDisease(String label) async {
    final response = await _authGet(
      '${AppConstants.diseasesUrl}${Uri.encodeComponent(label)}/',
    );
    if (response.statusCode == 200) {
      return Disease.fromJson(jsonDecode(response.body));
    }
    throw const AppException('Failed to load disease');
  }

  /// All diseases for the Library browse list (backend already drops the
  /// "Healthy" pseudo-entries).
  static Future<List<Disease>> getDiseases() async {
    final response = await _authGet(AppConstants.diseasesUrl);
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list
          .map((e) => Disease.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw const AppException('Failed to load diseases');
  }

  // ─── Social ─────────────────────────────────────────────────
}

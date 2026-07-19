import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/plant.dart';
import 'api_service.dart';
import 'app_refresh_bus.dart';
import 'notification_service.dart';

/// Live attention state for the persistent bottom navigation.
///
/// Task badges are state-based: they remain until the corresponding care is
/// completed. Profile's dot is event-based: a newly unlocked achievement stays
/// marked until the user visits Profile.
class AppBadgeController extends ChangeNotifier {
  AppBadgeController._();

  static final AppBadgeController instance = AppBadgeController._();

  int _dueCareActions = 0;
  bool _hasNewProfileUnlock = false;
  bool _started = false;
  bool _refreshing = false;
  bool _refreshAgain = false;
  String? _username;

  int get dueCareActions => _dueCareActions;
  bool get hasNewProfileUnlock => _hasNewProfileUnlock;

  Future<void> start() async {
    if (!_started) {
      _started = true;
      AppRefreshBus.plants.addListener(_onPlantsChanged);
    }
    await refresh();
  }

  void _onPlantsChanged() => refresh();

  Future<void> refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        await _loadProfileFlagForCurrentUser();
        final plants = await ApiService.getPlants();
        updateFromPlants(plants);
        await NotificationService.scheduleCareReminders(plants);
      } while (_refreshAgain);
    } catch (_) {
      // A badge is supplementary UI; keep the last known value on failure.
    } finally {
      _refreshing = false;
    }
  }

  void updateFromPlants(List<Plant> plants) {
    final next = plants.fold<int>(
      0,
      (sum, p) =>
          sum +
          (p.needsWater ? 1 : 0) +
          (p.needsFertilizer ? 1 : 0) +
          (p.needsMisting ? 1 : 0),
    );
    if (next == _dueCareActions) return;
    _dueCareActions = next;
    notifyListeners();
  }

  Future<void> markProfileUnlock() async {
    await _loadProfileFlagForCurrentUser();
    if (!_hasNewProfileUnlock) {
      _hasNewProfileUnlock = true;
      notifyListeners();
    }
    final key = _profileUnlockKey;
    if (key != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    }
  }

  Future<void> clearProfileUnlock() async {
    await _loadProfileFlagForCurrentUser();
    if (_hasNewProfileUnlock) {
      _hasNewProfileUnlock = false;
      notifyListeners();
    }
    final key = _profileUnlockKey;
    if (key != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }

  Future<void> _loadProfileFlagForCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(AppConstants.usernameKey);
    if (current == _username) return;
    _username = current;
    final next = current == null
        ? false
        : prefs.getBool('profile_new_unlock_$current') ?? false;
    if (next != _hasNewProfileUnlock) {
      _hasNewProfileUnlock = next;
      notifyListeners();
    }
  }

  String? get _profileUnlockKey =>
      _username == null ? null : 'profile_new_unlock_$_username';
}

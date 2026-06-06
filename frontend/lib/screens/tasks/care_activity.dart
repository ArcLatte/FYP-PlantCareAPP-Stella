import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../services/api_service.dart';

/// Config for the three daily care activities surfaced on the Tasks page.
/// Centralises label/icon/color, the "is this due?" predicate, and the
/// API call so the Tasks list and the per-activity detail screen stay in sync.
enum CareActivity {
  water,
  fertilize,
  mist;

  static CareActivity? fromKey(String key) {
    for (final a in CareActivity.values) {
      if (a.key == key) return a;
    }
    return null;
  }

  String get key => name; // 'water' | 'fertilize' | 'mist'

  String get label {
    switch (this) {
      case CareActivity.water:
        return 'Water';
      case CareActivity.fertilize:
        return 'Fertilize';
      case CareActivity.mist:
        return 'Mist';
    }
  }

  /// Gerund used as the detail-screen title, e.g. "Watering".
  String get title {
    switch (this) {
      case CareActivity.water:
        return 'Watering';
      case CareActivity.fertilize:
        return 'Fertilizing';
      case CareActivity.mist:
        return 'Misting';
    }
  }

  IconData get icon {
    switch (this) {
      case CareActivity.water:
        return Icons.water_drop_rounded;
      case CareActivity.fertilize:
        return Icons.compost_rounded;
      case CareActivity.mist:
        return Icons.cloud_rounded;
    }
  }

  Color get color {
    switch (this) {
      case CareActivity.water:
        return const Color(0xFF4F9FD9);
      case CareActivity.fertilize:
        return AppColors.amber;
      case CareActivity.mist:
        return const Color(0xFF26A69A);
    }
  }

  /// True when this activity is currently due for [p].
  bool isDue(Plant p) {
    switch (this) {
      case CareActivity.water:
        return p.needsWater;
      case CareActivity.fertilize:
        return p.needsFertilizer;
      case CareActivity.mist:
        return p.needsMisting;
    }
  }

  /// Days until this activity is next due for [p] (negative = overdue).
  int? daysUntil(Plant p) {
    switch (this) {
      case CareActivity.water:
        return p.daysUntilWater;
      case CareActivity.fertilize:
        return p.daysUntilFertilizer;
      case CareActivity.mist:
        return p.daysUntilMisting;
    }
  }

  /// Whether this activity applies to the plant's species at all (mist only
  /// applies to some species). Used to decide whether to surface the Mist
  /// card even when nothing is due yet.
  bool appliesTo(Plant p) {
    switch (this) {
      case CareActivity.water:
        return true;
      case CareActivity.fertilize:
        return p.speciesDetail?.defaultFertilizerFreqDays != null;
      case CareActivity.mist:
        return p.speciesDetail?.defaultMistingFreqDays != null;
    }
  }

  Future<Plant> performOn(int plantId) {
    switch (this) {
      case CareActivity.water:
        return ApiService.waterPlant(plantId);
      case CareActivity.fertilize:
        return ApiService.fertilizePlant(plantId);
      case CareActivity.mist:
        return ApiService.mistPlant(plantId);
    }
  }
}

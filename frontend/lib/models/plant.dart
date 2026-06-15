import '../core/constants.dart';
import 'species.dart';

class Plant {
  final int id;
  final String name;
  final String species;
  final int speciesId;
  final String? notes;
  final String createdAt;
  final String? photoUrl;
  final String location;
  final DateTime? lastWatered;
  final DateTime? lastFertilized;
  final DateTime? lastMisted;
  final int wateringFreqDays;
  final bool needsWater;
  final bool needsFertilizer;
  final bool needsMisting;
  final int? daysUntilWater;
  final int? daysUntilFertilizer;
  final int? daysUntilMisting;
  final String? latestHealth; // 'healthy' | 'diseased' | null
  final LatestDisease? latestDisease; // most recent *confirmed* diagnosis
  final SpeciesDetail? speciesDetail;

  Plant({
    required this.id,
    required this.name,
    required this.species,
    required this.speciesId,
    this.notes,
    required this.createdAt,
    this.photoUrl,
    this.location = '',
    this.lastWatered,
    this.lastFertilized,
    this.lastMisted,
    this.wateringFreqDays = 7,
    this.needsWater = false,
    this.needsFertilizer = false,
    this.needsMisting = false,
    this.daysUntilWater,
    this.daysUntilFertilizer,
    this.daysUntilMisting,
    this.latestHealth,
    this.latestDisease,
    this.speciesDetail,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    final detail = json['species_detail'];
    return Plant(
      id: json['id'] as int,
      name: json['name'] as String,
      species: (json['species_name'] ?? json['species'])?.toString() ?? '',
      speciesId: (json['species'] as num).toInt(),
      notes: json['notes']?.toString(),
      createdAt:
          (json['date_planted'] ?? json['created_at'] ?? '').toString(),
      photoUrl: _absolutePhotoUrl(json['photo']),
      location: json['location']?.toString() ?? '',
      lastWatered: _parseDate(json['last_watered']),
      lastFertilized: _parseDate(json['last_fertilized']),
      lastMisted: _parseDate(json['last_misted']),
      wateringFreqDays:
          (json['watering_freq_days'] as num?)?.toInt() ?? 7,
      needsWater: json['needs_water'] == true,
      needsFertilizer: json['needs_fertilizer'] == true,
      needsMisting: json['needs_misting'] == true,
      daysUntilWater: (json['days_until_water'] as num?)?.toInt(),
      daysUntilFertilizer: (json['days_until_fertilizer'] as num?)?.toInt(),
      daysUntilMisting: (json['days_until_misting'] as num?)?.toInt(),
      latestHealth: json['latest_health']?.toString(),
      latestDisease: json['latest_disease'] is Map<String, dynamic>
          ? LatestDisease.fromJson(json['latest_disease'])
          : null,
      speciesDetail: detail is Map<String, dynamic>
          ? SpeciesDetail.fromJson(detail)
          : null,
    );
  }
}

/// Lightweight summary of the most recent confirmed diagnosis, embedded in the
/// plant payload so the profile can show care actions + a 'read more' link.
class LatestDisease {
  final int scanId;
  final String label;
  final String name;
  final String severity;
  final String treatment;
  final String careTips;

  LatestDisease({
    required this.scanId,
    required this.label,
    required this.name,
    this.severity = '',
    this.treatment = '',
    this.careTips = '',
  });

  bool get isHealthy => label.toLowerCase().contains('healthy');

  factory LatestDisease.fromJson(Map<String, dynamic> json) {
    return LatestDisease(
      scanId: (json['scan_id'] as num).toInt(),
      label: json['label']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      treatment: json['treatment']?.toString() ?? '',
      careTips: json['care_tips']?.toString() ?? '',
    );
  }
}

String? _absolutePhotoUrl(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  // Relative path like "/media/plants/foo.jpg" — prepend host.
  if (s.startsWith('/')) return '${AppConstants.mediaHost}$s';
  return '${AppConstants.mediaHost}/$s';
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

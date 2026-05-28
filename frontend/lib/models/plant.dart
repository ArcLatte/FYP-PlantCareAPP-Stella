import '../core/constants.dart';

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
  final int wateringFreqDays;
  final bool needsWater;
  final String? latestHealth; // 'healthy' | 'diseased' | null

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
    this.wateringFreqDays = 7,
    this.needsWater = false,
    this.latestHealth,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
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
      wateringFreqDays:
          (json['watering_freq_days'] as num?)?.toInt() ?? 7,
      needsWater: json['needs_water'] == true,
      latestHealth: json['latest_health']?.toString(),
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

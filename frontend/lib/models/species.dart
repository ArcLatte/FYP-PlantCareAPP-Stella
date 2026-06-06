/// Structured care info for a plant species, mirrored from the backend
/// `species_detail` payload (see backend/core/serializers.py).
class SpeciesDetail {
  final int id;
  final String name;
  final String scientificName;
  final String description;
  final String growingTips;
  final String sunlight; // enum string, e.g. "full_sun"
  final String recommendedLocation; // "indoor" | "outdoor" | "both"
  final int? temperatureMinC;
  final int? temperatureMaxC;
  final int? defaultWateringFreqDays;
  final int? defaultFertilizerFreqDays;
  final int? defaultMistingFreqDays;
  final int? daysToHarvest;

  const SpeciesDetail({
    required this.id,
    required this.name,
    this.scientificName = '',
    this.description = '',
    this.growingTips = '',
    this.sunlight = '',
    this.recommendedLocation = '',
    this.temperatureMinC,
    this.temperatureMaxC,
    this.defaultWateringFreqDays,
    this.defaultFertilizerFreqDays,
    this.defaultMistingFreqDays,
    this.daysToHarvest,
  });

  factory SpeciesDetail.fromJson(Map<String, dynamic> json) {
    return SpeciesDetail(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      scientificName: json['scientific_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      growingTips: json['growing_tips']?.toString() ?? '',
      sunlight: json['sunlight']?.toString() ?? '',
      recommendedLocation: json['recommended_location']?.toString() ?? '',
      temperatureMinC: (json['temperature_min_c'] as num?)?.toInt(),
      temperatureMaxC: (json['temperature_max_c'] as num?)?.toInt(),
      defaultWateringFreqDays:
          (json['default_watering_freq_days'] as num?)?.toInt(),
      defaultFertilizerFreqDays:
          (json['default_fertilizer_freq_days'] as num?)?.toInt(),
      defaultMistingFreqDays:
          (json['default_misting_freq_days'] as num?)?.toInt(),
      daysToHarvest: (json['days_to_harvest'] as num?)?.toInt(),
    );
  }

  // ─── Display helpers ───────────────────────────────────────

  String get sunlightLabel {
    switch (sunlight) {
      case 'full_sun':
        return 'Full sun';
      case 'partial_sun':
        return 'Partial sun';
      case 'partial_shade':
        return 'Partial shade';
      case 'shade':
        return 'Shade';
      default:
        return '';
    }
  }

  String get locationLabel {
    switch (recommendedLocation) {
      case 'indoor':
        return 'Indoor';
      case 'outdoor':
        return 'Outdoor';
      case 'both':
        return 'Indoor / outdoor';
      default:
        return '';
    }
  }

  String? get temperatureRange {
    if (temperatureMinC == null || temperatureMaxC == null) return null;
    return '$temperatureMinC–$temperatureMaxC°C';
  }
}

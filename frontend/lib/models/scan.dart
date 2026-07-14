import '../core/constants.dart';

class Prediction {
  final String label;
  final double confidence;
  final String? name; // friendly disease name (from the knowledge base)
  final String? imageUrl; // example reference photo for comparison

  Prediction({
    required this.label,
    required this.confidence,
    this.name,
    this.imageUrl,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      label: json['label'].toString(),
      confidence: (json['confidence'] as num).toDouble(),
      name: json['name']?.toString(),
      // Backend now sends site-relative /static/ paths (self-hosted library
      // images); absolutize so CachedNetworkImage can load them. Legacy
      // absolute http(s) URLs pass through unchanged.
      imageUrl: _absolutePhotoUrl(json['image']),
    );
  }
}

class ScanResult {
  final int id;
  final int? plantId;
  final String? plantName;
  final String? imageUrl;
  final List<Prediction> predictions;
  // When true (top-1 confidence ≥ backend threshold) only the top prediction
  // may be confirmed; the result screen locks the lower-ranked alternatives.
  final bool alternativesLocked;
  final String? confirmedDisease;
  final String? diseaseName;
  final String? treatment;
  final String? careTips;
  final String createdAt;

  ScanResult({
    required this.id,
    this.plantId,
    this.plantName,
    this.imageUrl,
    required this.predictions,
    this.alternativesLocked = false,
    this.confirmedDisease,
    this.diseaseName,
    this.treatment,
    this.careTips,
    required this.createdAt,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final predictionsRaw =
        json['top3'] ?? json['predictions'] ?? const [];
    final List predictionsList =
        predictionsRaw is List ? predictionsRaw : const [];

    final plantField = json['plant'];
    int? plantId;
    String? plantName;
    if (plantField is int) {
      plantId = plantField;
    } else if (plantField is String) {
      plantName = plantField;
    } else if (plantField is num) {
      plantId = plantField.toInt();
    }
    // `plant_id` (when present) is authoritative for navigation.
    if (json['plant_id'] is num) {
      plantId = (json['plant_id'] as num).toInt();
    }

    return ScanResult(
      id: ((json['scan_id'] ?? json['id']) as num).toInt(),
      plantId: plantId,
      plantName: plantName,
      imageUrl: _absolutePhotoUrl(json['image']),
      predictions: predictionsList
          .map((p) => Prediction.fromJson(p as Map<String, dynamic>))
          .toList(),
      alternativesLocked: json['alternatives_locked'] == true,
      confirmedDisease: (json['disease'] ??
              json['confirmed_disease'] ??
              json['confirmed_label'])
          ?.toString(),
      diseaseName: json['disease_name']?.toString(),
      treatment: json['treatment']?.toString(),
      careTips: json['care_tips']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

/// Turn a backend image reference into a loadable URL. Absolute http(s) URLs
/// pass through; site-relative paths (uploaded media or /static/ library
/// images) get the API host prepended. Mirrors the helper in plant.dart.
String? _absolutePhotoUrl(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('/')) return '${AppConstants.mediaHost}$s';
  return '${AppConstants.mediaHost}/$s';
}

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
      imageUrl: json['image']?.toString(),
    );
  }
}

class ScanResult {
  final int id;
  final int? plantId;
  final String? plantName;
  final String? imageUrl;
  final List<Prediction> predictions;
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
      imageUrl: json['image']?.toString(),
      predictions: predictionsList
          .map((p) => Prediction.fromJson(p as Map<String, dynamic>))
          .toList(),
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

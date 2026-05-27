class Prediction {
  final String label;
  final double confidence;

  Prediction({required this.label, required this.confidence});

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      label: json['label'].toString(),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class ScanResult {
  final int id;
  final int? plantId;
  final String? plantName;
  final List<Prediction> predictions;
  final String? confirmedDisease;
  final String? treatment;
  final String? careTips;
  final String createdAt;

  ScanResult({
    required this.id,
    this.plantId,
    this.plantName,
    required this.predictions,
    this.confirmedDisease,
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

    return ScanResult(
      id: ((json['scan_id'] ?? json['id']) as num).toInt(),
      plantId: plantId,
      plantName: plantName,
      predictions: predictionsList
          .map((p) => Prediction.fromJson(p as Map<String, dynamic>))
          .toList(),
      confirmedDisease: (json['disease'] ??
              json['confirmed_disease'] ??
              json['confirmed_label'])
          ?.toString(),
      treatment: json['treatment']?.toString(),
      careTips: json['care_tips']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

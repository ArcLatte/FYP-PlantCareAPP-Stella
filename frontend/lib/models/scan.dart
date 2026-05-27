class Prediction {
  final String label;
  final double confidence;

  Prediction({required this.label, required this.confidence});

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      label: json['label'],
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class ScanResult {
  final int id;
  final int plantId;
  final List<Prediction> predictions;
  final String? confirmedDisease;
  final String? treatment;
  final String? careTips;
  final String createdAt;

  ScanResult({
    required this.id,
    required this.plantId,
    required this.predictions,
    this.confirmedDisease,
    this.treatment,
    this.careTips,
    required this.createdAt,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      id: json['id'],
      plantId: json['plant'],
      predictions: (json['predictions'] as List)
          .map((p) => Prediction.fromJson(p))
          .toList(),
      confirmedDisease: json['confirmed_disease'],
      treatment: json['treatment'],
      careTips: json['care_tips'],
      createdAt: json['created_at'],
    );
  }
}
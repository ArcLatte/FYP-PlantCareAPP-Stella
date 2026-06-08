/// A single entry in the History timeline — either a care action
/// (water/fertilize/mist) or a disease scan. Mirrors `GET /api/activity/`.
class ActivityEvent {
  final String type; // 'care' | 'scan'
  final String? activity; // care: 'water' | 'fertilize' | 'mist'
  final int? plantId;
  final String? plantName;
  final int? scanId; // scan only
  final String? label; // scan: disease/prediction label
  final String? health; // scan: 'healthy' | 'diseased' | null
  final DateTime createdAt;

  const ActivityEvent({
    required this.type,
    this.activity,
    this.plantId,
    this.plantName,
    this.scanId,
    this.label,
    this.health,
    required this.createdAt,
  });

  bool get isCare => type == 'care';
  bool get isScan => type == 'scan';

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      type: json['type']?.toString() ?? 'care',
      activity: json['activity']?.toString(),
      plantId: (json['plant_id'] as num?)?.toInt(),
      plantName: json['plant_name']?.toString(),
      scanId: (json['scan_id'] as num?)?.toInt(),
      label: json['label']?.toString(),
      health: json['health']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

import '../core/constants.dart';

/// A single entry in the History timeline: a care action
/// (water/fertilize/mist), a free-text journal note, or a disease scan.
/// Mirrors `GET /api/activity/`.
class ActivityEvent {
  final String type; // 'care' | 'scan'
  final int? careLogId; // care: the CareLog row id (for editing notes)
  final String? activity; // care: 'water' | 'fertilize' | 'mist' | 'note'
  final String? noteTitle; // note: optional short subject/heading
  final String? note; // care/note: the user's journal text
  final List<dynamic>? noteDocument; // Quill Delta operations
  final List<NoteImageAttachment> noteImages;
  final int? plantId;
  final String? plantName;
  final int? scanId; // scan only
  final String? label; // scan: disease/prediction label
  final String? health; // scan: 'healthy' | 'diseased' | null
  final DateTime createdAt;

  const ActivityEvent({
    required this.type,
    this.careLogId,
    this.activity,
    this.noteTitle,
    this.note,
    this.noteDocument,
    this.noteImages = const [],
    this.plantId,
    this.plantName,
    this.scanId,
    this.label,
    this.health,
    required this.createdAt,
  });

  bool get isCare => type == 'care';
  bool get isScan => type == 'scan';

  /// A journal note (a care log carrying free text rather than a watering etc.).
  bool get isNote => type == 'care' && activity == 'note';

  String? get notePhotoUrl => noteImages.isEmpty ? null : noteImages.first.url;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    final note = json['note']?.toString();
    final title = json['title']?.toString();
    final rawImages = json['note_images'];
    final rawDocument = json['document'];
    final images = rawImages is List
        ? rawImages
              .whereType<Map>()
              .map(
                (item) => NoteImageAttachment.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.url.isNotEmpty)
              .toList()
        : <NoteImageAttachment>[];
    final legacyUrl = _absoluteUrl(json['note_photo']);
    if (images.isEmpty && legacyUrl != null) {
      images.add(NoteImageAttachment(id: null, url: legacyUrl, legacy: true));
    }
    return ActivityEvent(
      type: json['type']?.toString() ?? 'care',
      careLogId: (json['id'] as num?)?.toInt(),
      activity: json['activity']?.toString(),
      noteTitle: (title != null && title.isNotEmpty) ? title : null,
      note: (note != null && note.isNotEmpty) ? note : null,
      noteDocument: rawDocument is List
          ? rawDocument.map((operation) {
              if (operation is! Map) return operation;
              final copy = Map<String, dynamic>.from(operation);
              final insert = copy['insert'];
              if (insert is Map && insert['image'] != null) {
                final embed = Map<String, dynamic>.from(insert);
                embed['image'] = _absoluteUrl(embed['image']) ?? embed['image'];
                copy['insert'] = embed;
              }
              return copy;
            }).toList()
          : null,
      noteImages: images,
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

class NoteImageAttachment {
  final int? id;
  final String url;
  final bool legacy;

  const NoteImageAttachment({
    required this.id,
    required this.url,
    this.legacy = false,
  });

  factory NoteImageAttachment.fromJson(Map<String, dynamic> json) {
    return NoteImageAttachment(
      id: (json['id'] as num?)?.toInt(),
      url: _absoluteUrl(json['url']) ?? '',
      legacy: json['legacy'] == true,
    );
  }
}

/// Resolve a possibly-relative media path (e.g. "/media/notes/x.jpg") to an
/// absolute URL, mirroring how Plant.photoUrl is built.
String? _absoluteUrl(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('/')) return '${AppConstants.mediaHost}$s';
  return '${AppConstants.mediaHost}/$s';
}

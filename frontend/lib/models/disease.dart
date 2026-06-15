/// A disease knowledge-base entry, fetched from `GET /diseases/<label>/`.
/// Powers the in-app disease detail ("read more") page. Content is curated
/// on the backend (seeded once), not retrieved live per request.
class Disease {
  final String label;
  final String name;
  final String? speciesName;
  final String description;
  final String symptoms;
  final String cause;
  final String treatment;
  final String careTips;
  final String prevention;
  final String severity; // 'low' | 'medium' | 'high' | ''
  final String sourceName;
  final String sourceUrl;
  final String imageUrl;
  final List<String> imageUrls;

  Disease({
    required this.label,
    required this.name,
    this.speciesName,
    this.description = '',
    this.symptoms = '',
    this.cause = '',
    this.treatment = '',
    this.careTips = '',
    this.prevention = '',
    this.severity = '',
    this.sourceName = '',
    this.sourceUrl = '',
    this.imageUrl = '',
    this.imageUrls = const [],
  });

  bool get isHealthy => label.toLowerCase().contains('healthy');

  /// All reference photos, preferring the list and falling back to the single
  /// [imageUrl] for backward compatibility.
  List<String> get allImages {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageUrl.isNotEmpty) return [imageUrl];
    return const [];
  }

  factory Disease.fromJson(Map<String, dynamic> json) {
    return Disease(
      label: json['label']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      speciesName: json['species_name']?.toString(),
      description: json['description']?.toString() ?? '',
      symptoms: json['symptoms']?.toString() ?? '',
      cause: json['cause']?.toString() ?? '',
      treatment: json['treatment']?.toString() ?? '',
      careTips: json['care_tips']?.toString() ?? '',
      prevention: json['prevention']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      sourceName: json['source_name']?.toString() ?? '',
      sourceUrl: json['source_url']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      imageUrls: json['image_urls'] is List
          ? (json['image_urls'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

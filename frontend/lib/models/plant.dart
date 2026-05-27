class Plant {
  final int id;
  final String name;
  final String species;
  final int speciesId;
  final String? notes;
  final String createdAt;

  Plant({
    required this.id,
    required this.name,
    required this.species,
    required this.speciesId,
    this.notes,
    required this.createdAt,
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
    );
  }
}
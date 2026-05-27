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
      id: json['id'],
      name: json['name'],
      species: json['species_name'] ?? json['species'].toString(),
      speciesId: json['species'] is int
          ? json['species']
          : int.parse(json['species'].toString()),
      notes: json['notes'],
      createdAt: json['date_planted'] ?? json['created_at'] ?? '',
    );
  }
}
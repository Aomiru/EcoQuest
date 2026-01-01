class Species {
  final String id;
  final String name;
  final String scientificName;
  final String description;
  final String habitat;
  final String conservationStatus;
  final List<String> characteristics;
  final String imageUrl;
  final String type; // 'flora' or 'fauna'
  final String? category; // 'bird', 'reptile', 'mammal', 'insect', etc.

  Species({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.description,
    required this.habitat,
    required this.conservationStatus,
    required this.characteristics,
    required this.imageUrl,
    this.type = 'fauna', // Default to fauna
    this.category,
  });

  factory Species.fromJson(Map<String, dynamic> json) {
    return Species(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      scientificName: json['scientificName'] ?? '',
      description: json['description'] ?? '',
      habitat: json['habitat'] ?? '',
      conservationStatus: json['conservationStatus'] ?? '',
      characteristics: List<String>.from(json['characteristics'] ?? []),
      imageUrl: json['imageUrl'] ?? '',
      type: json['type'] ?? 'fauna',
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'scientificName': scientificName,
      'description': description,
      'habitat': habitat,
      'conservationStatus': conservationStatus,
      'characteristics': characteristics,
      'imageUrl': imageUrl,
      'type': type,
      'category': category,
    };
  }
}

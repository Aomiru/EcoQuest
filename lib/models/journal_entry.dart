import 'species.dart';

class JournalEntry {
  final String id;
  final String imagePath;
  final String captureDate;
  final List<Species> identifiedSpecies;
  final double confidence;
  final String location;
  final String notes;
  final double? latitude;
  final double? longitude;
  final String? type;
  final String? category;
  final bool isSynced; // Track if entry has been synced to database

  JournalEntry({
    required this.id,
    required this.imagePath,
    required this.captureDate,
    required this.identifiedSpecies,
    required this.confidence,
    this.location = '',
    this.notes = '',
    this.latitude,
    this.longitude,
    this.type,
    this.category,
    this.isSynced = false, // Default to not synced
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final speciesList =
        (json['identifiedSpecies'] as List<dynamic>?)
            ?.map((species) => Species.fromJson(species))
            .toList() ??
        [];
    final derivedType =
        json['type'] as String? ??
        (speciesList.isNotEmpty ? speciesList.first.type : null);
    final derivedCategory =
        json['category'] as String? ??
        (speciesList.isNotEmpty ? speciesList.first.category : null);
    return JournalEntry(
      id: json['id'] ?? '',
      imagePath: json['imagePath'] ?? '',
      captureDate: json['captureDate'] ?? '',
      identifiedSpecies: speciesList,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      location: json['location'] ?? '',
      notes: json['notes'] ?? '',
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      type: derivedType,
      category: derivedCategory,
      isSynced: json['isSynced'] ?? false, // Load synced status
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'captureDate': captureDate,
      'identifiedSpecies': identifiedSpecies
          .map((species) => species.toJson())
          .toList(),
      'confidence': confidence,
      'location': location,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'type':
          type ??
          (identifiedSpecies.isNotEmpty ? identifiedSpecies.first.type : null),
      'category':
          category ??
          (identifiedSpecies.isNotEmpty
              ? identifiedSpecies.first.category
              : null),
      'isSynced': isSynced, // Save synced status
    };
  }
}

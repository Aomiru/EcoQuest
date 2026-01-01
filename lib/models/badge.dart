class Badge {
  final String id;
  final String name;
  final String description;
  final String type; // flora, fauna, or both
  final String category; // e.g., 'fish', 'bird', 'mammal', 'conservation', etc.
  final String? specificSpecies; // Specific species name if required
  final String requirement; // What needs to be done to unlock
  final String colorImage; // Path to colored badge image
  final String bwImage; // Path to black & white badge image
  final int expReward; // XP reward when unlocked
  bool isUnlocked;
  DateTime? unlockDate; // Date when badge was unlocked

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.category,
    this.specificSpecies,
    required this.requirement,
    required this.colorImage,
    required this.bwImage,
    this.expReward = 50,
    this.isUnlocked = false,
    this.unlockDate,
  });

  factory Badge.fromMap(Map<String, dynamic> map) {
    return Badge(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      type: map['type'] as String,
      category: map['category'] as String,
      specificSpecies: map['specificSpecies'] as String?,
      requirement: map['requirement'] as String,
      colorImage: map['colorImage'] as String,
      bwImage: map['bwImage'] as String,
      isUnlocked: (map['isUnlocked'] as bool?) ?? false,
      unlockDate: map['unlockDate'] != null
          ? DateTime.parse(map['unlockDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'category': category,
      'specificSpecies': specificSpecies,
      'requirement': requirement,
      'colorImage': colorImage,
      'bwImage': bwImage,
      'expReward': expReward,
      'isUnlocked': isUnlocked,
      'unlockDate': unlockDate?.toIso8601String(),
    };
  }

  Badge copyWith({bool? isUnlocked, DateTime? unlockDate, int? expReward}) {
    return Badge(
      id: id,
      name: name,
      description: description,
      type: type,
      category: category,
      specificSpecies: specificSpecies,
      requirement: requirement,
      colorImage: colorImage,
      bwImage: bwImage,
      expReward: expReward ?? this.expReward,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockDate: unlockDate ?? this.unlockDate,
    );
  }
}

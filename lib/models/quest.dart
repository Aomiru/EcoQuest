enum QuestType { daily, weekly }

class Quest {
  final String id;
  final String description;
  final int expReward;
  final int pointReward;
  final QuestType questType;
  final String? type; // flora or fauna
  final String? category; // bird, mammal, insect, flower, etc.
  bool isCompleted;

  Quest({
    required this.id,
    required this.description,
    required this.expReward,
    required this.pointReward,
    required this.questType,
    this.type,
    this.category,
    this.isCompleted = false,
  });

  factory Quest.fromMap(Map<String, dynamic> map) {
    return Quest(
      id: map['id'] as String,
      description: map['description'] as String,
      expReward: map['expReward'] as int,
      pointReward: (map['pointReward'] as int?) ?? 10, // Default 10 points
      questType:
          (map['questType'] as String?) == 'daily' ||
              (map['type'] as String?) == 'daily'
          ? QuestType.daily
          : QuestType.weekly,
      type: map['type'] as String?,
      category: map['category'] as String?,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'expReward': expReward,
      'pointReward': pointReward,
      'questType': questType == QuestType.daily ? 'daily' : 'weekly',
      'type': type,
      'category': category,
      'isCompleted': isCompleted,
    };
  }
}

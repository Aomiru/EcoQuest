import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/quest.dart';
import '../models/journal_entry.dart';
import 'quest_service.dart';

class QuestTrackingService {
  static const String _questProgressKey = 'quest_progress';

  // Track quest progress - call this when user adds a journal entry
  static Future<void> updateQuestProgress(JournalEntry entry) async {
    if (entry.identifiedSpecies.isEmpty) {
      return;
    }

    final dailyQuests = await QuestService.getDailyQuests();
    final weeklyQuests = await QuestService.getWeeklyQuests();

    // Check and update daily quests
    for (var quest in dailyQuests) {
      if (!quest.isCompleted) {
        if (await _checkQuestCompletion(quest, entry)) {
          await QuestService.markQuestCompleted(quest);
        }
      }
    }

    // Check and update weekly quests
    for (var quest in weeklyQuests) {
      if (!quest.isCompleted) {
        final currentProgress = await _getQuestProgress(quest.id);
        final newProgress = await _calculateProgress(
          quest,
          entry,
          currentProgress,
        );

        if (newProgress['completed'] == true) {
          await QuestService.markQuestCompleted(quest);
          await clearQuestProgress(quest.id);
        } else {
          await _saveQuestProgress(quest.id, newProgress);
        }
      }
    }
  }

  // Check if a quest is completed based on the journal entry
  static Future<bool> _checkQuestCompletion(
    Quest quest,
    JournalEntry entry,
  ) async {
    if (entry.identifiedSpecies.isEmpty) return false;
    final primarySpecies = entry.identifiedSpecies.first;
    final speciesType = primarySpecies.type.toLowerCase(); // flora/fauna
    final speciesCategory = primarySpecies.category?.toLowerCase() ?? '';
    final questType = quest.type?.toLowerCase() ?? '';
    final questCategory = quest.category?.toLowerCase() ?? '';

    // If quest has a specific category (bird, mammal, etc.), check category match
    if (questCategory.isNotEmpty && questCategory != '') {
      return speciesCategory == questCategory;
    }
    // Otherwise, check type only (flora/fauna)
    if (questType.isNotEmpty && questType != '') {
      return speciesType == questType;
    }
    return false;
  }

  // Calculate progress for multi-step quests (like "Catch 10 flora")
  static Future<Map<String, dynamic>> _calculateProgress(
    Quest quest,
    JournalEntry entry,
    Map<String, dynamic> currentProgress,
  ) async {
    if (entry.identifiedSpecies.isEmpty) return currentProgress;

    final description = quest.description;

    int targetCount = _extractTargetCount(description);
    int currentCount = currentProgress['count'] ?? 0;
    String trackingCategory = currentProgress['category'] ?? '';

    // Get quest type and category from quest object
    final questType = quest.type?.toLowerCase() ?? '';
    final questCategory = quest.category?.toLowerCase() ?? '';

    // Check if this entry matches the quest type/category
    if (await _checkQuestCompletion(quest, entry)) {
      trackingCategory = questCategory.isNotEmpty ? questCategory : questType;
      currentCount++; // Increment count for each catch (not just unique)
    }

    bool completed = currentCount >= targetCount;

    return {
      'count': currentCount,
      'target': targetCount,
      'category': trackingCategory,
      'completed': completed,
    };
  }

  // Extract target count from quest description (e.g., "Catch 10 flora" -> 10)
  static int _extractTargetCount(String description) {
    final numbers = RegExp(r'\d+').allMatches(description);
    if (numbers.isNotEmpty) {
      return int.parse(numbers.first.group(0)!);
    }
    return 1; // Default to 1 if no number found
  }

  // Get current progress for a quest
  static Future<Map<String, dynamic>> _getQuestProgress(String questId) async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getString('${_questProgressKey}_$questId');

    if (progressJson != null) {
      final progress = Map<String, dynamic>.from(json.decode(progressJson));
      // Ensure completed flag exists
      progress['completed'] = progress['completed'] ?? false;
      return progress;
    }

    return {'count': 0, 'target': 0, 'category': '', 'completed': false};
  }

  // Save quest progress
  static Future<void> _saveQuestProgress(
    String questId,
    Map<String, dynamic> progress,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_questProgressKey}_$questId',
      json.encode(progress),
    );
  }

  // Clear quest progress (when completed or reset)
  static Future<void> clearQuestProgress(String questId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_questProgressKey}_$questId');
  }

  // Get progress for display (returns "3/10" format)
  static Future<String> getQuestProgressDisplay(String questId) async {
    final progress = await _getQuestProgress(questId);
    final count = progress['count'] ?? 0;
    final target = progress['target'] ?? 0;

    if (target > 1) {
      return '$count/$target';
    }
    return '';
  }

  // Clear all quest progress (useful for testing or reset)
  static Future<void> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (var key in keys) {
      if (key.startsWith(_questProgressKey)) {
        await prefs.remove(key);
      }
    }
  }
}

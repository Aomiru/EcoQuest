import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quest.dart';
import 'progress_service.dart';
import 'quest_tracking_service.dart';
import 'supabase_sync_service.dart';

class QuestService {
  static const _dailyKey = 'quests_daily_json';
  static const _dailyDateKey = 'quests_daily_date'; // yyyy-MM-dd
  static const _weeklyKey = 'quests_weekly_json';
  static const _weeklyWeekKey = 'quests_weekly_yearweek'; // e.g., 2025-W48

  static const int dailyCount = 1;
  static const int weeklyCount = 1;

  static Future<List<Quest>> getDailyQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _formatDate(DateTime.now());
    final savedDate = prefs.getString(_dailyDateKey);
    if (savedDate == todayStr) {
      final jsonStr = prefs.getString(_dailyKey);
      if (jsonStr != null) {
        final list = (json.decode(jsonStr) as List)
            .map((e) => Quest.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        // Enforce single quest after count change (migration safeguard)
        if (list.length > dailyCount) {
          final trimmed = list.take(dailyCount).toList();
          await _persistList(_dailyKey, trimmed);
          return trimmed;
        }
        return list;
      }
    }

    // Daily reset detected - clear progress for old daily quests
    await _clearProgressForOldQuests(QuestType.daily);

    final pool = await _loadQuestPool(
      'assets/quests/daily_quests.txt',
      QuestType.daily,
    );
    final selected = _pickRandom(pool, dailyCount);
    await _saveQuests(_dailyKey, _dailyDateKey, selected, todayStr);
    return selected;
  }

  static Future<List<Quest>> getWeeklyQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final weekStr = _formatYearWeek(DateTime.now());
    final savedWeek = prefs.getString(_weeklyWeekKey);
    if (savedWeek == weekStr) {
      final jsonStr = prefs.getString(_weeklyKey);
      if (jsonStr != null) {
        final list = (json.decode(jsonStr) as List)
            .map((e) => Quest.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        // Enforce single quest after count change (migration safeguard)
        if (list.length > weeklyCount) {
          final trimmed = list.take(weeklyCount).toList();
          await _persistList(_weeklyKey, trimmed);
          return trimmed;
        }
        return list;
      }
    }

    // Weekly reset detected - clear progress for old weekly quests
    await _clearProgressForOldQuests(QuestType.weekly);

    final pool = await _loadQuestPool(
      'assets/quests/weekly_quests.txt',
      QuestType.weekly,
    );
    final selected = _pickRandom(pool, weeklyCount);
    await _saveQuests(_weeklyKey, _weeklyWeekKey, selected, weekStr);
    return selected;
  }

  static Future<void> markQuestCompleted(Quest quest) async {
    // Load the persisted quest list directly (avoid calling getters which may regenerate lists)
    final prefs = await SharedPreferences.getInstance();
    final key = quest.questType == QuestType.daily ? _dailyKey : _weeklyKey;
    final jsonStr = prefs.getString(key);
    List<Quest> list = [];
    if (jsonStr != null) {
      list = (json.decode(jsonStr) as List)
          .map((e) => Quest.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    // Mark the matching quest completed in the list
    bool found = false;
    for (final q in list) {
      if (q.id == quest.id) {
        q.isCompleted = true;
        found = true;
        break;
      }
    }

    // Fallback: if not found (unexpected), add it as completed
    if (!found) {
      quest.isCompleted = true;
      list.add(quest);
    }

    // Persist updated list
    await _persistList(key, list);

    // Award EXP and Points
    await ProgressService.addExp(quest.expReward);
    await SupabaseSyncService.addPointsToSupabase(quest.pointReward);
  }

  static Future<void> _saveQuests(
    String listKey,
    String stampKey,
    List<Quest> quests,
    String stamp,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await _persistList(listKey, quests);
    await prefs.setString(stampKey, stamp);
  }

  static Future<void> _persistList(String key, List<Quest> quests) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(quests.map((e) => e.toMap()).toList());
    await prefs.setString(key, jsonStr);
  }

  static Future<List<Quest>> _loadQuestPool(
    String assetPath,
    QuestType type,
  ) async {
    final raw = await rootBundle.loadString(assetPath);
    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.startsWith('#'))
        .toList();

    // Format: description|exp|points|type|category
    final List<Quest> quests = [];
    for (int i = 0; i < lines.length; i++) {
      final parts = lines[i].split('|');
      final desc = parts[0].trim();
      final expReward = parts.length > 1
          ? int.tryParse(parts[1].trim()) ?? _defaultReward(type)
          : _defaultReward(type);
      final pointReward = parts.length > 2
          ? int.tryParse(parts[2].trim()) ?? _defaultPointReward(type)
          : _defaultPointReward(type);
      final questTypeRaw = parts.length > 3
          ? parts[3].trim().toLowerCase()
          : null;
      final categoryRaw = parts.length > 4
          ? parts[4].trim().toLowerCase()
          : null;

      // Convert empty strings to null for proper handling
      final questType = (questTypeRaw != null && questTypeRaw.isNotEmpty)
          ? questTypeRaw
          : null;
      final category = (categoryRaw != null && categoryRaw.isNotEmpty)
          ? categoryRaw
          : null;

      quests.add(
        Quest(
          id: '${type.name}_$i',
          description: desc,
          expReward: expReward,
          pointReward: pointReward,
          questType: type,
          type: questType,
          category: category,
        ),
      );
    }
    return quests;
  }

  static List<Quest> _pickRandom(List<Quest> pool, int count) {
    final rand = Random();
    final poolCopy = List<Quest>.from(pool);
    poolCopy.shuffle(rand);
    return poolCopy.take(count.clamp(0, poolCopy.length)).toList();
  }

  static int _defaultReward(QuestType type) =>
      type == QuestType.daily ? 25 : 75;

  static int _defaultPointReward(QuestType type) =>
      type == QuestType.daily ? 10 : 30;

  static String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatYearWeek(DateTime dt) {
    // ISO-like week format, rough: year-W<weekNumber>
    final firstDayOfYear = DateTime(dt.year, 1, 1);
    final days = dt.difference(firstDayOfYear).inDays;
    final week = (days / 7).floor() + 1;
    return '${dt.year}-W$week';
  }

  static Duration getTimeUntilDailyReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  static Duration getTimeUntilWeeklyReset() {
    final now = DateTime.now();
    // Find next Monday (start of week)
    final daysUntilMonday = (8 - now.weekday) % 7;
    final nextMonday = DateTime(now.year, now.month, now.day + daysUntilMonday);
    return nextMonday.difference(now);
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 24) {
      final days = (hours / 24).floor();
      return '${days}d ${hours % 24}h';
    }
    return '${hours}h ${minutes}m';
  }

  /// Clear cached quests to force reload from text files (useful for testing/debugging)
  static Future<void> clearQuestCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dailyKey);
    await prefs.remove(_dailyDateKey);
    await prefs.remove(_weeklyKey);
    await prefs.remove(_weeklyWeekKey);
  }

  /// Clear progress for old quests when they reset
  static Future<void> _clearProgressForOldQuests(QuestType type) async {
    final prefs = await SharedPreferences.getInstance();

    // Get the old quest IDs before they get replaced
    String key = type == QuestType.daily ? _dailyKey : _weeklyKey;
    final jsonStr = prefs.getString(key);

    if (jsonStr != null) {
      final list = (json.decode(jsonStr) as List)
          .map((e) => Quest.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      // Clear progress for each old quest
      for (var quest in list) {
        await QuestTrackingService.clearQuestProgress(quest.id);
      }
    }
  }
}

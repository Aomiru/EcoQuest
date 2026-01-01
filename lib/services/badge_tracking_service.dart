import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/journal_entry.dart';
import '../services/badge_service.dart';
import '../services/journal_service.dart';
import '../services/progress_service.dart';

class BadgeTrackingService {
  static const String _badgeProgressKey = 'badge_progress';
  static const String _pendingBadgeUnlocksKey = 'pending_badge_unlocks';

  // Track badge progress - call this when user adds a journal entry
  static Future<List<String>> updateBadgeProgress(JournalEntry entry) async {
    final newlyUnlockedBadges = <String>[];

    if (entry.identifiedSpecies.isEmpty) {
      return newlyUnlockedBadges;
    }

    // Get all badges
    final badges = await BadgeService.loadAllBadges();

    for (var badge in badges) {
      if (badge.isUnlocked) continue; // Skip already unlocked badges

      final currentProgress = await _getBadgeProgress(badge.id);
      final shouldUnlock = await _checkBadgeCompletion(
        badge,
        entry,
        currentProgress,
      );

      if (shouldUnlock) {
        final unlocked = await BadgeService.unlockBadge(badge.id);
        if (unlocked) {
          newlyUnlockedBadges.add(badge.name);

          // Award XP for unlocking badge
          final expReward = await BadgeService.getBadgeExpReward(badge.id);
          await ProgressService.addExp(expReward);

          // Add to pending badge unlocks for popup display
          await _addPendingBadgeUnlock(badge.id);

          await clearBadgeProgress(badge.id);
        }
      }
    }

    return newlyUnlockedBadges;
  }

  // Check and unlock all badges (for initial load or periodic checks)
  static Future<List<String>> checkAndUnlockBadges() async {
    final newlyUnlockedBadges = <String>[];

    // Get all badges and journal entries
    final badges = await BadgeService.loadAllBadges();
    final journalEntries = await JournalService.getJournalEntries();

    for (var badge in badges) {
      if (badge.isUnlocked) continue;

      final currentProgress = await _getBadgeProgress(badge.id);
      bool shouldUnlock = false;

      // Check against all journal entries
      for (var entry in journalEntries) {
        shouldUnlock = await _checkBadgeCompletion(
          badge,
          entry,
          currentProgress,
        );
        if (shouldUnlock) break;
      }

      if (shouldUnlock) {
        final unlocked = await BadgeService.unlockBadge(badge.id);
        if (unlocked) {
          newlyUnlockedBadges.add(badge.name);

          // Award XP for unlocking badge
          final expReward = await BadgeService.getBadgeExpReward(badge.id);
          await ProgressService.addExp(expReward);

          // Add to pending badge unlocks for popup display
          await _addPendingBadgeUnlock(badge.id);

          await clearBadgeProgress(badge.id);
        }
      }
    }

    return newlyUnlockedBadges;
  }

  // Check if a badge should be unlocked based on the journal entry
  static Future<bool> _checkBadgeCompletion(
    badge,
    JournalEntry entry,
    Map<String, dynamic> currentProgress,
  ) async {
    if (entry.identifiedSpecies.isEmpty) return false;

    final primarySpecies = entry.identifiedSpecies.first;
    final speciesType = primarySpecies.type.toLowerCase(); // flora/fauna
    final speciesCategory = primarySpecies.category?.toLowerCase() ?? '';
    final speciesName = primarySpecies.name.toLowerCase();

    final badgeType = badge.type?.toLowerCase() ?? '';
    final badgeCategory = badge.category?.toLowerCase() ?? '';
    final specificSpecies = badge.specificSpecies?.toLowerCase() ?? '';

    // Check if badge requires a specific species
    if (specificSpecies.isNotEmpty) {
      final match =
          speciesName.contains(specificSpecies) ||
          specificSpecies.contains(speciesName);
      if (match) return true;
      return false;
    }

    // Check if badge requires conservation actions
    if (badgeCategory == 'conservation') {
      final conservationActions = await _getConservationActionCount();
      final target = _extractTargetCount(badge.requirement);
      return conservationActions >= target;
    }

    // Check if badge requires counting multiple species
    final targetCount = _extractTargetCount(badge.requirement);
    if (targetCount > 1) {
      // Get all journal entries to count
      final allEntries = await JournalService.getJournalEntries();
      int count = 0;

      // Count matching species
      if (badgeCategory.isNotEmpty && badgeCategory != 'all') {
        count = _countSpeciesByCategory(allEntries, badgeCategory);
      } else if (badgeType == 'flora') {
        count = _countSpeciesByType(allEntries, 'flora');
      } else if (badgeType == 'fauna') {
        count = _countSpeciesByType(allEntries, 'fauna');
      } else if (badgeCategory == 'all') {
        count = _countTotalUniqueSpecies(allEntries);
      }

      await _saveBadgeProgress(badge.id, {
        'count': count,
        'target': targetCount,
        'category': badgeCategory,
      });

      return count >= targetCount;
    }

    // Single species requirement - check category or type match
    if (badgeCategory.isNotEmpty && badgeCategory != 'all') {
      return speciesCategory == badgeCategory;
    }

    if (badgeType == 'flora' || badgeType == 'fauna') {
      return speciesType == badgeType;
    }

    return false;
  }

  // Count species by type (flora/fauna)
  static int _countSpeciesByType(List<JournalEntry> entries, String type) {
    final uniqueSpecies = <String>{};
    for (var entry in entries) {
      for (var species in entry.identifiedSpecies) {
        if (species.type.toLowerCase() == type.toLowerCase()) {
          uniqueSpecies.add(species.name.toLowerCase());
        }
      }
    }
    return uniqueSpecies.length;
  }

  // Count species by category (bird, reptile, mammal, etc.)
  static int _countSpeciesByCategory(
    List<JournalEntry> entries,
    String category,
  ) {
    final uniqueSpecies = <String>{};
    for (var entry in entries) {
      for (var species in entry.identifiedSpecies) {
        final speciesCategory = species.category?.toLowerCase() ?? '';
        if (speciesCategory == category.toLowerCase()) {
          uniqueSpecies.add(species.name.toLowerCase());
        }
      }
    }
    return uniqueSpecies.length;
  }

  // Get conservation action count (tracked separately)
  static Future<int> _getConservationActionCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('conservation_actions') ?? 0;
  }

  // Increment conservation action count
  static Future<void> addConservationAction() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('conservation_actions') ?? 0;
    await prefs.setInt('conservation_actions', current + 1);

    // Check for badge unlocks
    await checkAndUnlockBadges();
  }

  // Get badge unlock progress (for display)
  static Future<Map<String, dynamic>> getBadgeProgress(String badgeId) async {
    final badges = await BadgeService.loadAllBadges();
    final badge = badges.firstWhere(
      (b) => b.id == badgeId,
      orElse: () => badges.first,
    );

    final journalEntries = await JournalService.getJournalEntries();

    // Extract target from badge requirement
    final target = _extractTargetCount(badge.requirement);
    int current = 0;

    // Check if it's a specific species badge
    if (badge.specificSpecies != null && badge.specificSpecies!.isNotEmpty) {
      // Count if this specific species has been discovered
      for (var entry in journalEntries) {
        for (var species in entry.identifiedSpecies) {
          final speciesName = species.name.toLowerCase();
          final targetSpecies = badge.specificSpecies!.toLowerCase();
          if (speciesName.contains(targetSpecies) ||
              targetSpecies.contains(speciesName)) {
            current = 1;
            break;
          }
        }
        if (current > 0) break;
      }
      return {'current': current, 'target': target};
    }

    // Check if it's conservation actions
    if (badge.category.toLowerCase() == 'conservation') {
      current = await _getConservationActionCount();
      return {'current': current, 'target': target};
    }

    // Count by category or type
    if (badge.category.toLowerCase() == 'all') {
      current = _countTotalUniqueSpecies(journalEntries);
    } else if (badge.category.isNotEmpty) {
      current = _countSpeciesByCategory(journalEntries, badge.category);
    } else if (badge.type == 'flora') {
      current = _countSpeciesByType(journalEntries, 'flora');
    } else if (badge.type == 'fauna') {
      current = _countSpeciesByType(journalEntries, 'fauna');
    }

    return {'current': current, 'target': target};
  }

  // Count total unique species
  static int _countTotalUniqueSpecies(List<JournalEntry> entries) {
    final uniqueSpecies = <String>{};
    for (var entry in entries) {
      for (var species in entry.identifiedSpecies) {
        uniqueSpecies.add(species.name.toLowerCase());
      }
    }
    return uniqueSpecies.length;
  }

  // Extract target count from requirement text (e.g., "Discover 5 reptile species" -> 5)
  static int _extractTargetCount(String requirement) {
    final numbers = RegExp(r'\d+').allMatches(requirement);
    if (numbers.isNotEmpty) {
      return int.parse(numbers.first.group(0)!);
    }
    return 1; // Default to 1 if no number found
  }

  // Get current progress for a badge
  static Future<Map<String, dynamic>> _getBadgeProgress(String badgeId) async {
    final prefs = await SharedPreferences.getInstance();
    final progressJson = prefs.getString('${_badgeProgressKey}_$badgeId');

    if (progressJson != null) {
      return Map<String, dynamic>.from(json.decode(progressJson));
    }

    return {'count': 0, 'target': 0, 'category': ''};
  }

  // Save badge progress
  static Future<void> _saveBadgeProgress(
    String badgeId,
    Map<String, dynamic> progress,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_badgeProgressKey}_$badgeId',
      json.encode(progress),
    );
  }

  // Clear badge progress (when completed or reset)
  static Future<void> clearBadgeProgress(String badgeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_badgeProgressKey}_$badgeId');
  }

  // Clear all badge progress (useful for testing or reset)
  static Future<void> clearAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (var key in keys) {
      if (key.startsWith(_badgeProgressKey)) {
        await prefs.remove(key);
      }
    }
  }

  // Add newly unlocked badge to pending list (for popup display)
  static Future<void> _addPendingBadgeUnlock(String badgeId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingJson = prefs.getString(_pendingBadgeUnlocksKey);

    List<String> pending = [];
    if (pendingJson != null) {
      pending = List<String>.from(json.decode(pendingJson));
    }

    if (!pending.contains(badgeId)) {
      pending.add(badgeId);
      await prefs.setString(_pendingBadgeUnlocksKey, json.encode(pending));
    }
  }

  // Get and clear pending badge unlocks (returns badge IDs)
  static Future<List<String>> getPendingBadgeUnlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingJson = prefs.getString(_pendingBadgeUnlocksKey);

    if (pendingJson != null) {
      final pending = List<String>.from(json.decode(pendingJson));
      await prefs.remove(_pendingBadgeUnlocksKey); // Clear after reading
      return pending;
    }

    return [];
  }
}

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/badge.dart';

class BadgeService {
  static const String _badgesKey = 'badges_json';
  static const String _unlockedBadgesKey = 'unlocked_badges';

  // Load all badges from the asset file
  static Future<List<Badge>> loadAllBadges() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we have cached badges
    final cachedJson = prefs.getString(_badgesKey);
    List<Badge> badges;

    if (cachedJson != null) {
      // Load from cache
      badges = (json.decode(cachedJson) as List)
          .map((e) => Badge.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      // Load from asset file
      badges = await _loadBadgesFromAsset();
      // Cache the badges
      await _cacheBadges(badges);
    }

    // Get unlocked badge IDs and dates
    final unlockedIds = await _getUnlockedBadgeIds();

    // Update unlock status and load unlock dates
    badges = badges.map((badge) {
      final isUnlocked = unlockedIds.contains(badge.id);
      DateTime? unlockDate;

      if (isUnlocked) {
        final dateStr = prefs.getString('badge_unlock_date_${badge.id}');
        if (dateStr != null) {
          unlockDate = DateTime.parse(dateStr);
        }
      }

      return badge.copyWith(isUnlocked: isUnlocked, unlockDate: unlockDate);
    }).toList();

    // Sort: unlocked badges first (by latest unlock date), then locked badges
    badges.sort((a, b) {
      if (a.isUnlocked && b.isUnlocked) {
        // Both unlocked: sort by unlock date (newest first)
        if (a.unlockDate != null && b.unlockDate != null) {
          return b.unlockDate!.compareTo(a.unlockDate!);
        }
        return a.isUnlocked ? -1 : 1;
      } else if (a.isUnlocked) {
        return -1; // Unlocked badges come first
      } else if (b.isUnlocked) {
        return 1;
      }
      return 0; // Both locked, maintain original order
    });

    return badges;
  }

  // Load badges from the asset file
  // Format: name|description|type(flora/fauna/both)|category|specific species|imagename|exp
  static Future<List<Badge>> _loadBadgesFromAsset() async {
    final contents = await rootBundle.loadString('assets/badge/badges.txt');
    final lines = contents
        .split('\n')
        .where((line) => line.trim().isNotEmpty && !line.startsWith('#'))
        .toList();

    final badges = <Badge>[];

    for (var line in lines) {
      final parts = line.split('|');
      if (parts.length == 7) {
        final name = parts[0].trim();
        final description = parts[1].trim();
        final type = parts[2].trim(); // flora, fauna, or both
        final category = parts[3]
            .trim(); // fish, bird, mammal, conservation, etc.
        final specificSpecies = parts[4]
            .trim(); // specific species name or empty
        final imageName = parts[5].trim();
        final expReward = int.tryParse(parts[6].trim()) ?? 50; // XP from file

        badges.add(
          Badge(
            id: imageName,
            name: name,
            description: description,
            type: type,
            category: category,
            specificSpecies: specificSpecies.isEmpty ? null : specificSpecies,
            requirement: description,
            colorImage: 'assets/badge/$imageName.color.png',
            bwImage: 'assets/badge/$imageName.bw.png',
            expReward: expReward,
            isUnlocked: false,
          ),
        );
      }
    }

    return badges;
  }

  // Cache badges to SharedPreferences
  static Future<void> _cacheBadges(List<Badge> badges) async {
    final prefs = await SharedPreferences.getInstance();
    final badgesJson = json.encode(badges.map((b) => b.toMap()).toList());
    await prefs.setString(_badgesKey, badgesJson);
  }

  // Get unlocked badge IDs
  static Future<Set<String>> _getUnlockedBadgeIds() async {
    final prefs = await SharedPreferences.getInstance();
    final unlockedJson = prefs.getString(_unlockedBadgesKey);

    if (unlockedJson != null) {
      final unlockedList = json.decode(unlockedJson) as List;
      return Set<String>.from(unlockedList);
    }

    return <String>{};
  }

  // Unlock a badge
  static Future<bool> unlockBadge(String badgeId) async {
    final unlockedIds = await _getUnlockedBadgeIds();

    // Check if already unlocked
    if (unlockedIds.contains(badgeId)) {
      return false; // Already unlocked
    }

    // Add to unlocked set
    unlockedIds.add(badgeId);

    // Save unlock date
    final unlockDate = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _unlockedBadgesKey,
      json.encode(unlockedIds.toList()),
    );
    await prefs.setString(
      'badge_unlock_date_$badgeId',
      unlockDate.toIso8601String(),
    );

    return true; // Newly unlocked
  }

  // Get XP reward for a badge
  static Future<int> getBadgeExpReward(String badgeId) async {
    final badges = await loadAllBadges();
    final badge = badges.firstWhere(
      (b) => b.id == badgeId,
      orElse: () => badges.first,
    );
    return badge.expReward;
  }

  // Check if a badge is unlocked
  static Future<bool> isBadgeUnlocked(String badgeId) async {
    final unlockedIds = await _getUnlockedBadgeIds();
    return unlockedIds.contains(badgeId);
  }

  // Get unlocked badges
  static Future<List<Badge>> getUnlockedBadges() async {
    final allBadges = await loadAllBadges();
    return allBadges.where((badge) => badge.isUnlocked).toList();
  }

  // Get locked badges
  static Future<List<Badge>> getLockedBadges() async {
    final allBadges = await loadAllBadges();
    return allBadges.where((badge) => !badge.isUnlocked).toList();
  }

  // Get badges by category
  static Future<List<Badge>> getBadgesByCategory(String category) async {
    final allBadges = await loadAllBadges();
    return allBadges.where((badge) => badge.category == category).toList();
  }

  // Clear all unlocked badges (for testing/reset)
  static Future<void> clearAllUnlockedBadges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_unlockedBadgesKey);
  }

  // Refresh badge cache from asset file
  static Future<void> refreshBadgeCache() async {
    final badges = await _loadBadgesFromAsset();
    await _cacheBadges(badges);
  }
}

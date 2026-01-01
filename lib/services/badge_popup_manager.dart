import 'package:flutter/material.dart';
import '../services/badge_service.dart';
import '../services/badge_tracking_service.dart';
import '../widgets/badge_unlock_popup.dart';

class BadgePopupManager {
  /// Check and show any pending badge unlock popups
  /// Call this in initState or onResume of screens (except camera screen)
  static Future<void> checkAndShowPendingBadges(BuildContext context) async {
    // Get pending badge unlocks
    final pendingBadgeIds = await BadgeTrackingService.getPendingBadgeUnlocks();

    if (pendingBadgeIds.isEmpty) return;

    // Get all badges to find the ones that were unlocked
    final allBadges = await BadgeService.loadAllBadges();

    // Show popup for each unlocked badge
    for (var badgeId in pendingBadgeIds) {
      final badge = allBadges.firstWhere(
        (b) => b.id == badgeId,
        orElse: () => allBadges.first,
      );

      if (!context.mounted) return;

      await BadgeUnlockPopup.show(context, badge);
    }
  }
}

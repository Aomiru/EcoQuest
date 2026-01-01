import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_progress.dart';
import 'badge_tracking_service.dart';

class ProgressService {
  static const String _expKey = 'user_exp';

  static Future<int> getExp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_expKey) ?? 0;
  }

  static Future<void> setExp(int exp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_expKey, exp);
  }

  static Future<void> addExp(int amount) async {
    final current = await getExp();
    final updated = current + amount;
    await setExp(updated);

    // Check and unlock badges when exp is added
    await BadgeTrackingService.checkAndUnlockBadges();
  }

  static Future<UserProgress> getUserProgress() async {
    final exp = await getExp();
    return UserProgress(exp: exp);
  }
}

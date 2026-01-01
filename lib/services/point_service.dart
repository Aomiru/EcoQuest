import 'package:shared_preferences/shared_preferences.dart';

class PointService {
  static const String _pointsKey = 'user_points';
  static const String _weeklyWeekKey = 'points_weekly_yearweek';

  /// Get current points for the week
  static Future<int> getPoints() async {
    await _checkAndResetIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? 0;
  }

  /// Set points (internal use)
  static Future<void> setPoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsKey, points);
  }

  /// Add points to current week's total
  static Future<void> addPoints(int amount) async {
    await _checkAndResetIfNeeded();
    final current = await getPoints();
    final updated = current + amount;
    await setPoints(updated);
  }

  /// Check if we need to reset points for a new week
  static Future<void> _checkAndResetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final currentWeek = _formatYearWeek(DateTime.now());
    final savedWeek = prefs.getString(_weeklyWeekKey);

    if (savedWeek != currentWeek) {
      // New week detected - reset points
      await prefs.setInt(_pointsKey, 0);
      await prefs.setString(_weeklyWeekKey, currentWeek);
    }
  }

  /// Format date as year-week string (ISO-like)
  static String _formatYearWeek(DateTime dt) {
    final firstDayOfYear = DateTime(dt.year, 1, 1);
    final days = dt.difference(firstDayOfYear).inDays;
    final week = (days / 7).floor() + 1;
    return '${dt.year}-W$week';
  }

  /// Clear points cache (useful for testing/debugging)
  static Future<void> clearPointsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pointsKey);
    await prefs.remove(_weeklyWeekKey);
  }
}

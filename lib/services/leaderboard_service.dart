import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth_service.dart';

/// Model for leaderboard entry
class LeaderboardEntry {
  final String userId;
  final String name;
  final String? photoUrl;
  final int level;
  final int points;
  final int rank;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.level,
    required this.points,
    required this.rank,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, int rank) {
    final currentUserId = SupabaseAuthService.userId;
    return LeaderboardEntry(
      userId: json['user_id'] ?? '',
      name: json['name'] ?? 'Anonymous',
      photoUrl: json['avatar_url'],
      level: json['level'] ?? 1,
      points: json['points'] ?? 0,
      rank: rank,
      isCurrentUser: currentUserId != null && json['user_id'] == currentUserId,
    );
  }
}

/// Service to fetch leaderboard data from Supabase
class LeaderboardService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all-time leaderboard (top 50 users by total points)
  /// Ensures current user is included even if not in top 50
  static Future<List<LeaderboardEntry>> getAllTimeLeaderboard({
    int limit = 50,
  }) async {
    try {
      final currentUserId = SupabaseAuthService.userId;

      // Query top users by points from user_progress
      final progressData = await _supabase
          .from('user_progress')
          .select('user_id, level, points')
          .order('points', ascending: false)
          .limit(limit);

      // Get all user_ids to fetch user details
      final userIds = progressData.map((p) => p['user_id']).toList();

      // Fetch user details for these user_ids
      final usersData = await _supabase
          .from('users')
          .select('user_id, name, profile_image')
          .inFilter('user_id', userIds);

      // Create a map of user_id to user data for quick lookup
      final usersMap = {for (var user in usersData) user['user_id']: user};

      final List<LeaderboardEntry> entries = [];
      int rank = 1;
      bool currentUserInTop = false;

      for (var item in progressData) {
        final userId = item['user_id'];
        final isCurrentUser = userId == currentUserId;
        final userData = usersMap[userId];

        if (isCurrentUser) {
          currentUserInTop = true;
        }

        entries.add(
          LeaderboardEntry(
            userId: userId,
            name: userData?['name'] ?? 'Anonymous',
            photoUrl: userData?['profile_image'],
            level: item['level'] ?? 1,
            points: item['points'] ?? 0,
            rank: rank++,
            isCurrentUser: isCurrentUser,
          ),
        );
      }

      // If current user is not in top 50, fetch their rank and add them
      if (currentUserId != null && !currentUserInTop) {
        final userProgress = await _supabase
            .from('user_progress')
            .select('user_id, level, points')
            .eq('user_id', currentUserId)
            .maybeSingle();

        if (userProgress != null) {
          // Calculate user's rank by counting users with more points
          final allProgressData = await _supabase
              .from('user_progress')
              .select('points')
              .gt('points', userProgress['points']);

          final userRank = allProgressData.length + 1;

          // Fetch current user's details
          final userData = await _supabase
              .from('users')
              .select('name, profile_image')
              .eq('user_id', currentUserId)
              .maybeSingle();

          entries.add(
            LeaderboardEntry(
              userId: userProgress['user_id'],
              name: userData?['name'] ?? 'Anonymous',
              photoUrl: userData?['profile_image'],
              level: userProgress['level'] ?? 1,
              points: userProgress['points'] ?? 0,
              rank: userRank,
              isCurrentUser: true,
            ),
          );
        }
      }

      return entries;
    } catch (e) {
      // Error fetching all-time leaderboard
      return [];
    }
  }

  /// Get weekly leaderboard (users by points gained this week)
  /// Ensures current user is included even if not in top 50
  static Future<List<LeaderboardEntry>> getWeeklyLeaderboard({
    int limit = 50,
  }) async {
    try {
      final currentUserId = SupabaseAuthService.userId;

      // Query top users by weekly_points
      final progressData = await _supabase
          .from('user_progress')
          .select('user_id, level, weekly_points')
          .order('weekly_points', ascending: false)
          .limit(limit);

      // Get all user_ids to fetch user details
      final userIds = progressData.map((p) => p['user_id']).toList();

      // Fetch user details for these user_ids
      final usersData = await _supabase
          .from('users')
          .select('user_id, name, profile_image')
          .inFilter('user_id', userIds);

      // Create a map of user_id to user data for quick lookup
      final usersMap = {for (var user in usersData) user['user_id']: user};

      final List<LeaderboardEntry> entries = [];
      int rank = 1;
      bool currentUserInTop = false;

      for (var item in progressData) {
        final userId = item['user_id'];
        final isCurrentUser = userId == currentUserId;
        final userData = usersMap[userId];

        if (isCurrentUser) {
          currentUserInTop = true;
        }

        entries.add(
          LeaderboardEntry(
            userId: userId,
            name: userData?['name'] ?? 'Anonymous',
            photoUrl: userData?['profile_image'],
            level: item['level'] ?? 1,
            points: item['weekly_points'] ?? 0,
            rank: rank++,
            isCurrentUser: isCurrentUser,
          ),
        );
      }

      // If current user is not in top 50, fetch their rank and add them
      if (currentUserId != null && !currentUserInTop) {
        final userProgress = await _supabase
            .from('user_progress')
            .select('user_id, level, weekly_points')
            .eq('user_id', currentUserId)
            .maybeSingle();

        if (userProgress != null) {
          // Calculate user's rank by counting users with more weekly points
          final allProgressData = await _supabase
              .from('user_progress')
              .select('weekly_points')
              .gt('weekly_points', userProgress['weekly_points']);

          final userRank = allProgressData.length + 1;

          // Fetch current user's details
          final userData = await _supabase
              .from('users')
              .select('name, profile_image')
              .eq('user_id', currentUserId)
              .maybeSingle();

          entries.add(
            LeaderboardEntry(
              userId: userProgress['user_id'],
              name: userData?['name'] ?? 'Anonymous',
              photoUrl: userData?['profile_image'],
              level: userProgress['level'] ?? 1,
              points: userProgress['weekly_points'] ?? 0,
              rank: userRank,
              isCurrentUser: true,
            ),
          );
        }
      }

      return entries;
    } catch (e) {
      // Error fetching weekly leaderboard
      return [];
    }
  }

  /// Get current user's rank in all-time leaderboard
  static Future<int?> getCurrentUserRank() async {
    try {
      final userId = SupabaseAuthService.userId;
      if (userId == null) return null;

      final allUsers = await getAllTimeLeaderboard(limit: 1000);
      final userEntry = allUsers.firstWhere(
        (entry) => entry.userId == userId,
        orElse: () => LeaderboardEntry(
          userId: '',
          name: '',
          level: 0,
          points: 0,
          rank: 0,
          isCurrentUser: false,
        ),
      );

      return userEntry.rank > 0 ? userEntry.rank : null;
    } catch (e) {
      // Error getting user rank
      return null;
    }
  }
}

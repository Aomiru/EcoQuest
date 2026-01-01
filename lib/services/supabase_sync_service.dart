import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth_service.dart';
import 'journal_service.dart';
import 'progress_service.dart';
import 'point_service.dart';
import 'user_profile_service.dart';
import '../models/journal_entry.dart';

/// Service to sync local data with Supabase database
class SupabaseSyncService {
  static final SupabaseClient _supabase = SupabaseAuthService.supabase;

  /// Check if user has existing data in Supabase
  static Future<bool> hasExistingData() async {
    if (!SupabaseAuthService.isSignedIn) {
      return false;
    }

    try {
      final userId = SupabaseAuthService.userId!;

      // Check if user profile exists
      final userProfile = await _supabase
          .from('users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return userProfile != null;
    } catch (e) {
      // If there's an error, assume no existing data
      return false;
    }
  }

  /// Sync all user data to Supabase (call after Google sign in)
  static Future<void> syncAllDataToSupabase() async {
    if (!SupabaseAuthService.isSignedIn) {
      return;
    }

    try {
      await syncUserProfile();
      await syncUserProgress();
      await syncJournalEntries();
    } catch (e) {
      // Error syncing data to Supabase
      rethrow;
    }
  }

  /// Sync user profile to Supabase
  static Future<void> syncUserProfile() async {
    if (!SupabaseAuthService.isSignedIn) return;

    final userId = SupabaseAuthService.userId!;
    final profile = await UserProfileService.getUserProfile();

    // Add user metadata from Google
    final userEmail = SupabaseAuthService.userEmail;
    final userDisplayName = SupabaseAuthService.userDisplayName;
    final userPhotoUrl = SupabaseAuthService.userPhotoUrl;

    // Check if user already has a profile in Supabase
    final existingProfile = await _supabase
        .from('users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    final profileData = {
      'user_id': userId,
      'name': profile['name'] ?? userDisplayName ?? 'Explorer',
      'email': userEmail,
      'age': profile['age'],
      'gender': profile['gender'],
      'hobby': profile['hobby'],
      'favorite_animal': profile['favoriteAnimal'],
      'profile_image': userPhotoUrl ?? profile['profileImage'],
      'is_connected_to_google': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Only update the profile if local data is not empty or if no existing profile
    if (existingProfile == null || profile['name'] != 'Explorer') {
      // Upsert user profile (insert or update) with conflict resolution on user_id
      await _supabase.from('users').upsert(profileData, onConflict: 'user_id');
    }

    // Update local profile
    profile['isConnectedToGoogle'] = true;
    if (userEmail != null) profile['email'] = userEmail;
    if (userDisplayName != null && profile['name'] == 'Explorer') {
      profile['name'] = userDisplayName;
    }
    if (userPhotoUrl != null) {
      profile['profileImage'] = 'google'; // Mark as using Google photo
    }
    await UserProfileService.saveUserProfile(profile);
  }

  /// Sync user progress (level and exp) to Supabase
  static Future<void> syncUserProgress() async {
    if (!SupabaseAuthService.isSignedIn) return;

    final userId = SupabaseAuthService.userId!;
    final exp = await ProgressService.getExp();
    final weeklyPoints = await PointService.getPoints();
    final userProgress = await ProgressService.getUserProgress();

    // Get current all-time points from Supabase (or 0 if new user)
    final currentProgress = await _supabase
        .from('user_progress')
        .select('points, exp, level')
        .eq('user_id', userId)
        .maybeSingle();

    // If user has existing data, keep the higher values
    final currentAllTimePoints = currentProgress?['points'] ?? 0;
    final remoteExp = currentProgress?['exp'] ?? 0;
    final remoteLevel = currentProgress?['level'] ?? 1;

    // Use the higher exp and level between local and remote
    final finalExp = exp > remoteExp ? exp : remoteExp;
    final finalLevel = userProgress.level > remoteLevel
        ? userProgress.level
        : remoteLevel;

    final progressData = {
      'user_id': userId,
      'exp': finalExp,
      'level': finalLevel,
      'points': currentAllTimePoints, // Keep all-time points as-is
      'weekly_points': weeklyPoints,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Upsert user progress (conflict on user_id)
    await _supabase
        .from('user_progress')
        .upsert(progressData, onConflict: 'user_id');
  }

  /// Sync journal entries to Supabase
  static Future<void> syncJournalEntries() async {
    if (!SupabaseAuthService.isSignedIn) return;

    final userId = SupabaseAuthService.userId!;
    final localEntries = await JournalService.getJournalEntries();

    // Get existing entries from Supabase
    final remoteResponse = await _supabase
        .from('journals')
        .select()
        .eq('user_id', userId);

    final remoteEntries = remoteResponse as List;

    // Create a set of existing entry IDs in Supabase
    final remoteEntryIds = remoteEntries
        .map((e) => e['entry_id'] as String)
        .toSet();

    // Only sync new entries that don't exist in Supabase
    final newEntries = localEntries
        .where((entry) => !remoteEntryIds.contains(entry.id))
        .toList();

    if (newEntries.isNotEmpty) {
      // Prepare new journal entries for upload
      final journalData = newEntries.map((entry) {
        return {
          'user_id': userId,
          'entry_id': entry.id,
          'image_path': entry.imagePath,
          'capture_date': entry.captureDate,
          'identified_species': entry.identifiedSpecies
              .map((s) => s.toJson())
              .toList(),
          'confidence': entry.confidence,
          'location': entry.location,
          'notes': entry.notes,
          'latitude': entry.latitude,
          'longitude': entry.longitude,
          'type': entry.type,
          'category': entry.category,
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      // Insert new entries only (don't delete existing ones)
      await _supabase.from('journals').insert(journalData);
    }
  }

  /// Load all data from Supabase (call on app start if user is signed in)
  static Future<void> loadAllDataFromSupabase() async {
    if (!SupabaseAuthService.isSignedIn) return;

    try {
      await loadUserProfile();
      await loadUserProgress();
      await loadJournalEntries();
    } catch (e) {
      // Error loading data from Supabase
      rethrow;
    }
  }

  /// Load user profile from Supabase
  static Future<void> loadUserProfile() async {
    if (!SupabaseAuthService.isSignedIn) return;

    final userId = SupabaseAuthService.userId!;

    final response = await _supabase
        .from('users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response != null) {
      // Check if user has Google photo
      final userPhotoUrl = SupabaseAuthService.userPhotoUrl;
      final profileImage = userPhotoUrl != null
          ? 'google'
          : response['profile_image'];

      final profile = {
        'name': response['name'],
        'age': response['age'],
        'gender': response['gender'],
        'hobby': response['hobby'],
        'favoriteAnimal': response['favorite_animal'],
        'profileImage': profileImage,
        'isConnectedToGoogle': response['is_connected_to_google'] ?? true,
        'email': response['email'],
      };

      await UserProfileService.saveUserProfile(profile);
    }
  }

  /// Load user progress from Supabase
  static Future<void> loadUserProgress() async {
    if (!SupabaseAuthService.isSignedIn) return;

    final userId = SupabaseAuthService.userId!;

    final response = await _supabase
        .from('user_progress')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response != null) {
      await ProgressService.setExp(response['exp'] ?? 0);
      // Load weekly_points to local storage (PointService manages weekly reset)
      await PointService.setPoints(response['weekly_points'] ?? 0);
      // All-time points stay in Supabase only
    }
  }

  /// Load journal entries from Supabase
  static Future<void> loadJournalEntries() async {
    if (!SupabaseAuthService.isSignedIn) return;

    final userId = SupabaseAuthService.userId!;

    final response = await _supabase
        .from('journals')
        .select()
        .eq('user_id', userId);

    if (response.isNotEmpty) {
      // Convert Supabase data back to JournalEntry objects
      final entries = (response as List).map((data) {
        return JournalEntry.fromJson({
          'id': data['entry_id'],
          'imagePath': data['image_path'],
          'captureDate': data['capture_date'],
          'identifiedSpecies': data['identified_species'],
          'confidence': data['confidence'],
          'location': data['location'] ?? '',
          'notes': data['notes'] ?? '',
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'type': data['type'],
          'category': data['category'],
        });
      }).toList();

      // Merge remote entries with local entries instead of overwriting
      await JournalService.mergeJournalEntries(entries);
    }
  }

  /// Add points to both weekly and all-time scores in Supabase
  static Future<void> addPointsToSupabase(int pointsToAdd) async {
    if (!SupabaseAuthService.isSignedIn) return;

    final userId = SupabaseAuthService.userId!;

    // Get current progress from Supabase
    final response = await _supabase
        .from('user_progress')
        .select('points, weekly_points')
        .eq('user_id', userId)
        .maybeSingle();

    final currentAllTimePoints = response?['points'] ?? 0;
    final currentWeeklyPoints = response?['weekly_points'] ?? 0;

    // Update both points (conflict on user_id)
    await _supabase.from('user_progress').upsert({
      'user_id': userId,
      'points': currentAllTimePoints + pointsToAdd,
      'weekly_points': currentWeeklyPoints + pointsToAdd,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');

    // Also update local weekly points
    await PointService.addPoints(pointsToAdd);
  }

  /// Auto-sync after important actions
  static Future<void> autoSyncAfterAction() async {
    if (SupabaseAuthService.isSignedIn) {
      await syncUserProgress();
      await syncJournalEntries();
    }
  }
}

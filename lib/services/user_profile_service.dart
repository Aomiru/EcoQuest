import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth_service.dart';

class UserProfileService {
  static const String _userProfileKey = 'user_profile';
  static const String _customImagePathKey = 'custom_profile_image_path';
  static final SupabaseClient _supabase = SupabaseAuthService.supabase;

  // Get user profile (from local cache or Supabase)
  static Future<Map<String, dynamic>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userProfileKey);

    if (jsonStr != null) {
      return Map<String, dynamic>.from(json.decode(jsonStr));
    }

    // If user is signed in, try to load from Supabase
    if (SupabaseAuthService.isSignedIn) {
      final userId = SupabaseAuthService.userId!;

      try {
        final response = await _supabase
            .from('users')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (response != null) {
          final userPhotoUrl = SupabaseAuthService.userPhotoUrl;
          final profileImage = userPhotoUrl != null
              ? 'google'
              : (response['profile_image'] ?? 'assets/profile1.jpg');

          final profile = {
            'name': response['name'] ?? 'Explorer',
            'age': response['age'] ?? '0',
            'gender': response['gender'] ?? 'Other',
            'hobby': response['hobby'] ?? 'Nature Exploration',
            'favoriteAnimal': response['favorite_animal'] ?? 'Unknown',
            'profileImage': profileImage,
            'isConnectedToGoogle': response['is_connected_to_google'] ?? false,
            'email': response['email'],
          };

          await saveUserProfile(profile);
          return profile;
        }
      } catch (e) {
        // Error loading profile from Supabase
      }
    }

    // Return default profile if not signed in or loading fails
    return {
      'name': 'Explorer',
      'age': '0',
      'gender': 'Other',
      'hobby': 'Nature Exploration',
      'favoriteAnimal': 'Unknown',
      'profileImage': 'assets/profile1.jpg',
      'isConnectedToGoogle': false,
    };
  }

  // Save user profile (to local cache and Supabase if signed in)
  static Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(profile);
    await prefs.setString(_userProfileKey, jsonStr);

    // If user is signed in, also save to Supabase
    if (SupabaseAuthService.isSignedIn) {
      try {
        final userId = SupabaseAuthService.userId!;

        await _supabase.from('users').upsert({
          'user_id': userId,
          'name': profile['name'],
          'email': profile['email'],
          'age': profile['age'],
          'gender': profile['gender'],
          'hobby': profile['hobby'],
          'favorite_animal': profile['favoriteAnimal'],
          'profile_image': profile['profileImage'] == 'google'
              ? SupabaseAuthService.userPhotoUrl
              : profile['profileImage'],
          'is_connected_to_google': profile['isConnectedToGoogle'] ?? false,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id');
      } catch (e) {
        // Error saving profile to Supabase
      }
    }
  }

  // Get user name
  static Future<String> getUserName() async {
    final profile = await getUserProfile();
    return profile['name'] ?? 'Explorer';
  }

  // Get profile image path
  static Future<String> getProfileImagePath() async {
    final profile = await getUserProfile();
    return profile['profileImage'] ?? 'assets/profile1.jpg';
  }

  // Get custom image path (for images from gallery)
  static Future<String?> getCustomImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customImagePathKey);
  }

  // Save custom image path
  static Future<void> saveCustomImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customImagePathKey, path);
  }
}

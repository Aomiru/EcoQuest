import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/supabase_config.dart';

/// Service to handle Supabase authentication and user management
class SupabaseAuthService {
  static final SupabaseClient supabase = Supabase.instance.client;

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  /// Get current user
  static User? get currentUser => supabase.auth.currentUser;

  /// Check if user is signed in
  static bool get isSignedIn => currentUser != null;

  /// Get user ID
  static String? get userId => currentUser?.id;

  /// Sign in with Google
  static Future<AuthResponse?> signInWithGoogle() async {
    try {
      // Initialize Google Sign In with Web Client ID only
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: SupabaseConfig.googleClientIdWeb,
      );

      // Sign out first to ensure fresh login
      await googleSignIn.signOut();

      // Trigger the Google Sign In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw 'No Access Token found.';
      }
      if (idToken == null) {
        throw 'No ID Token found.';
      }

      // Sign in to Supabase with Google credentials
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return response;
    } catch (e) {
      // Error signing in with Google
      rethrow;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      // Sign out from Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      // Sign out from Supabase
      await supabase.auth.signOut();
    } catch (e) {
      // Error signing out
      rethrow;
    }
  }

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges =>
      supabase.auth.onAuthStateChange;

  /// Get user email
  static String? get userEmail => currentUser?.email;

  /// Get user display name
  static String? get userDisplayName =>
      currentUser?.userMetadata?['full_name'] ??
      currentUser?.userMetadata?['name'];

  /// Get user profile picture URL
  static String? get userPhotoUrl {
    final metadata = currentUser?.userMetadata;
    final photoUrl = metadata?['avatar_url'] ?? metadata?['picture'];
    return photoUrl;
  }
}

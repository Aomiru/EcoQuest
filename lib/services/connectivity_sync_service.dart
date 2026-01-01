import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:developer' as developer;
import 'journal_service.dart';
import 'supabase_auth_service.dart';

/// Service to monitor internet connectivity and auto-sync when online
class ConnectivitySyncService {
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;
  static bool _isOnline = false;
  static DateTime? _lastSyncAttempt;
  static const Duration _syncCooldown = Duration(minutes: 5);

  /// Initialize connectivity monitoring
  static Future<void> initialize() async {
    // Check initial connectivity
    _isOnline = await _checkConnectivity();

    // Listen to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        developer.log('Connectivity monitoring error: $error');
      },
    );

    developer.log('Connectivity monitoring initialized');
  }

  /// Stop connectivity monitoring
  static void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Check if device has internet connectivity
  static Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Handle connectivity change events
  static Future<void> _onConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    final wasOffline = !_isOnline;
    _isOnline = await _checkConnectivity();

    developer.log('Connectivity changed: ${_isOnline ? "Online" : "Offline"}');

    // If we just came online and user is signed in, sync data
    if (_isOnline && wasOffline && SupabaseAuthService.isSignedIn) {
      await _attemptAutoSync();
    }
  }

  /// Attempt to auto-sync unsynced entries
  static Future<void> _attemptAutoSync() async {
    try {
      // Check cooldown to avoid too frequent syncs
      if (_lastSyncAttempt != null) {
        final timeSinceLastSync = DateTime.now().difference(_lastSyncAttempt!);
        if (timeSinceLastSync < _syncCooldown) {
          developer.log('Sync cooldown active, skipping auto-sync');
          return;
        }
      }

      _lastSyncAttempt = DateTime.now();

      developer.log('Attempting auto-sync of offline entries...');
      await JournalService.syncUnsyncedEntries();
      developer.log('Auto-sync completed successfully');
    } catch (e) {
      developer.log('Auto-sync failed: $e');
    }
  }

  /// Manually trigger sync (can be called by user action)
  static Future<bool> manualSync() async {
    if (!_isOnline) {
      developer.log('Cannot sync: Device is offline');
      return false;
    }

    if (!SupabaseAuthService.isSignedIn) {
      developer.log('Cannot sync: User is not signed in');
      return false;
    }

    try {
      developer.log('Manual sync triggered');
      await JournalService.syncUnsyncedEntries();
      developer.log('Manual sync completed successfully');
      return true;
    } catch (e) {
      developer.log('Manual sync failed: $e');
      return false;
    }
  }

  /// Get current online status
  static bool get isOnline => _isOnline;

  /// Force refresh connectivity status
  static Future<bool> refreshConnectivity() async {
    _isOnline = await _checkConnectivity();
    return _isOnline;
  }
}

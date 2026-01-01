import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/journal_entry.dart';
import '../models/species.dart';
import 'ai_species_service.dart';
import 'quest_tracking_service.dart';
import 'badge_tracking_service.dart';
import 'progress_service.dart';
import 'supabase_sync_service.dart';
import 'supabase_auth_service.dart';
import 'image_storage_service.dart';

class JournalService {
  static const String _journalEntriesKey = 'journal_entries';

  static Future<List<JournalEntry>> getJournalEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? entriesJson = prefs.getString(_journalEntriesKey);

    if (entriesJson == null) {
      return [];
    }

    final List<dynamic> entriesList = jsonDecode(entriesJson);
    return entriesList.map((entry) => JournalEntry.fromJson(entry)).toList();
  }

  static Future<void> saveJournalEntry(JournalEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final List<JournalEntry> entries = await getJournalEntries();

    entries.add(entry);

    final String entriesJson = jsonEncode(
      entries.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_journalEntriesKey, entriesJson);

    // Award XP and Points based on conservation status
    await _awardConservationRewards(entry);

    // Automatically update quest progress when a new journal entry is saved
    await QuestTrackingService.updateQuestProgress(entry);

    // Check and unlock badges
    await BadgeTrackingService.checkAndUnlockBadges();

    // Try to sync to Supabase if online (non-blocking)
    _trySyncToSupabase(entry);
  }

  /// Try to sync entry to Supabase in background (non-blocking)
  static Future<void> _trySyncToSupabase(JournalEntry entry) async {
    try {
      // Only sync if user is signed in
      if (!SupabaseAuthService.isSignedIn) {
        return;
      }

      // Attempt sync without blocking
      await SupabaseSyncService.syncJournalEntries();

      // Mark entry as synced
      await _markEntryAsSynced(entry.id);
    } catch (e) {
      // Silently fail - entry will be synced later when online
    }
  }

  /// Mark a journal entry as synced
  static Future<void> _markEntryAsSynced(String entryId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<JournalEntry> entries = await getJournalEntries();

    final index = entries.indexWhere((e) => e.id == entryId);
    if (index != -1) {
      final entry = entries[index];
      entries[index] = JournalEntry(
        id: entry.id,
        imagePath: entry.imagePath,
        captureDate: entry.captureDate,
        identifiedSpecies: entry.identifiedSpecies,
        confidence: entry.confidence,
        location: entry.location,
        latitude: entry.latitude,
        longitude: entry.longitude,
        notes: entry.notes,
        type: entry.type,
        category: entry.category,
        isSynced: true,
      );

      final String entriesJson = jsonEncode(
        entries.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_journalEntriesKey, entriesJson);
    }
  }

  /// Sync all unsynced entries to Supabase
  static Future<void> syncUnsyncedEntries() async {
    try {
      final entries = await getJournalEntries();
      final unsyncedEntries = entries.where((e) => !e.isSynced).toList();

      if (unsyncedEntries.isEmpty) {
        return;
      }

      await SupabaseSyncService.syncJournalEntries();

      // Mark all entries as synced
      for (var entry in unsyncedEntries) {
        await _markEntryAsSynced(entry.id);
      }
    } catch (e) {
      // Silently fail - will retry later
    }
  }

  /// Award XP and Points based on species conservation status
  static Future<void> _awardConservationRewards(JournalEntry entry) async {
    if (entry.identifiedSpecies.isEmpty) return;

    for (var species in entry.identifiedSpecies) {
      final status = species.conservationStatus.toLowerCase();
      int reward = 50; // Default reward

      if (status.contains('critically endangered') ||
          status.contains('critical')) {
        reward = 150;
      } else if (status.contains('vulnerable') ||
          status.contains('endangered')) {
        reward = 100;
      } else {
        reward = 50;
      }

      // Award XP
      await ProgressService.addExp(reward);

      // Award Points
      await SupabaseSyncService.addPointsToSupabase(reward);
    }
  }

  static Future<void> deleteJournalEntry(String entryId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<JournalEntry> entries = await getJournalEntries();

    entries.removeWhere((entry) => entry.id == entryId);

    final String entriesJson = jsonEncode(
      entries.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_journalEntriesKey, entriesJson);
  }

  static Future<void> updateJournalNotes(String entryId, String notes) async {
    final prefs = await SharedPreferences.getInstance();
    final List<JournalEntry> entries = await getJournalEntries();

    final index = entries.indexWhere((entry) => entry.id == entryId);
    if (index != -1) {
      final entry = entries[index];
      entries[index] = JournalEntry(
        id: entry.id,
        imagePath: entry.imagePath,
        captureDate: entry.captureDate,
        identifiedSpecies: entry.identifiedSpecies,
        confidence: entry.confidence,
        location: entry.location,
        notes: notes,
        latitude: entry.latitude,
        longitude: entry.longitude,
        type: entry.type,
        category: entry.category,
        isSynced: false, // Mark as unsynced since notes changed
      );

      final String entriesJson = jsonEncode(
        entries.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_journalEntriesKey, entriesJson);
    }
  }

  /// Check if a species already exists in the journal
  static Future<bool> hasSpecies(String speciesName) async {
    final entries = await getJournalEntries();
    return entries.any(
      (entry) => entry.identifiedSpecies.any(
        (species) => species.name.toLowerCase() == speciesName.toLowerCase(),
      ),
    );
  }

  /// Merge remote entries with local entries (for syncing from database)
  static Future<void> mergeJournalEntries(
    List<JournalEntry> remoteEntries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final List<JournalEntry> localEntries = await getJournalEntries();

    // Create a map of local entries by ID for quick lookup
    final localEntriesMap = {for (var e in localEntries) e.id: e};

    // Merge: add remote entries that don't exist locally, and mark them as synced
    for (var remoteEntry in remoteEntries) {
      if (!localEntriesMap.containsKey(remoteEntry.id)) {
        // Create new entry from remote data and mark as synced
        final syncedEntry = JournalEntry(
          id: remoteEntry.id,
          imagePath: remoteEntry.imagePath,
          captureDate: remoteEntry.captureDate,
          identifiedSpecies: remoteEntry.identifiedSpecies,
          confidence: remoteEntry.confidence,
          location: remoteEntry.location,
          latitude: remoteEntry.latitude,
          longitude: remoteEntry.longitude,
          notes: remoteEntry.notes,
          type: remoteEntry.type,
          category: remoteEntry.category,
          isSynced: true, // Remote entries are already synced
        );
        localEntries.add(syncedEntry);
      }
    }

    // Save merged entries
    final String entriesJson = jsonEncode(
      localEntries.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_journalEntriesKey, entriesJson);
  }

  // AI identification service using intelligent image analysis
  static Future<List<Species>> identifySpecies(String imagePath) async {
    try {
      // Use the AI service for species identification
      final species = await AISpeciesIdentificationService.identifySpecies(
        imagePath,
      );
      return species != null
          ? [species]
          : []; // Return list with single species or empty list
    } catch (e) {
      // Error in species identification
      return []; // Return empty list if AI identification fails
    }
  }

  // AI identification service with confidence information
  static Future<Map<String, dynamic>> identifySpeciesWithConfidence(
    String imagePath,
  ) async {
    try {
      // Use the AI service for species identification with its internal confidence calculation
      final analysisResult =
          await AISpeciesIdentificationService.identifySpeciesWithConfidence(
            imagePath,
          );

      if (analysisResult['species'] != null) {
        final species = analysisResult['species'] as Species;
        final confidence = analysisResult['confidence'] as double;

        // Ensure confidence never exceeds 100%
        final clampedConfidence = confidence > 100.0 ? 100.0 : confidence;

        return {
          'species': [species],
          'confidence': clampedConfidence,
        };
      } else {
        // Species not identified - return empty list to trigger "not recognized" popup
        return {'species': <Species>[], 'confidence': 0.0};
      }
    } catch (e) {
      // Error in species identification
      return {'species': <Species>[], 'confidence': 0.0};
    }
  }

  /// Migrate old journal entries with temporary image paths to permanent storage
  /// Returns number of entries migrated
  static Future<int> migrateOldImagePaths() async {
    final prefs = await SharedPreferences.getInstance();
    final List<JournalEntry> entries = await getJournalEntries();
    int migratedCount = 0;
    List<JournalEntry> updatedEntries = [];

    for (var entry in entries) {
      final imageFile = File(entry.imagePath);

      // Check if image exists at current path
      if (await imageFile.exists()) {
        // Check if it's a temporary path (contains 'cache' or is in temp directory)
        if (entry.imagePath.contains('cache') ||
            entry.imagePath.contains('tmp') ||
            !entry.imagePath.contains('species_images')) {
          try {
            // Migrate to permanent storage
            final permanentPath =
                await ImageStorageService.saveImagePermanently(imageFile);

            // Create updated entry with new path
            final updatedEntry = JournalEntry(
              id: entry.id,
              imagePath: permanentPath,
              captureDate: entry.captureDate,
              identifiedSpecies: entry.identifiedSpecies,
              confidence: entry.confidence,
              location: entry.location,
              latitude: entry.latitude,
              longitude: entry.longitude,
              notes: entry.notes,
              type: entry.type,
              category: entry.category,
              isSynced: false, // Mark as unsynced to re-upload with new path
            );

            updatedEntries.add(updatedEntry);
            migratedCount++;
          } catch (e) {
            // If migration fails, keep original entry
            updatedEntries.add(entry);
          }
        } else {
          // Already in permanent storage
          updatedEntries.add(entry);
        }
      } else {
        // Image doesn't exist, keep entry as-is (will be handled by cleanup)
        updatedEntries.add(entry);
      }
    }

    // Save updated entries if any were migrated
    if (migratedCount > 0) {
      final String entriesJson = jsonEncode(
        updatedEntries.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_journalEntriesKey, entriesJson);
    }

    return migratedCount;
  }
}

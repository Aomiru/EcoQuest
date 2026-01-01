import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:developer' as developer;

/// Service for managing persistent local image storage
/// Images are saved to app documents directory and persist across app sessions
class ImageStorageService {
  static const String _imagesFolder = 'species_images';

  /// Get the directory where species images are stored
  static Future<Directory> _getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(appDir.path, _imagesFolder));

    // Create directory if it doesn't exist
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    return imagesDir;
  }

  /// Save an image file to permanent storage
  /// Returns the permanent file path
  static Future<String> saveImagePermanently(File tempImage) async {
    try {
      final imagesDir = await _getImagesDirectory();

      // Generate unique filename with timestamp
      final fileName = 'species_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final permanentPath = path.join(imagesDir.path, fileName);

      // Copy image from temporary location to permanent storage
      final permanentFile = await tempImage.copy(permanentPath);

      developer.log('Image saved permanently: $permanentPath');

      return permanentFile.path;
    } catch (e) {
      developer.log('Error saving image permanently: $e');
      rethrow;
    }
  }

  /// Delete an image from permanent storage
  static Future<void> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        developer.log('Image deleted: $imagePath');
      }
    } catch (e) {
      developer.log('Error deleting image: $e');
      // Don't throw - image deletion is not critical
    }
  }

  /// Check if an image file exists
  static Future<bool> imageExists(String imagePath) async {
    try {
      final file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Clean up orphaned images (images not referenced in journal entries)
  static Future<void> cleanupOrphanedImages(
    List<String> validImagePaths,
  ) async {
    try {
      final imagesDir = await _getImagesDirectory();

      if (!await imagesDir.exists()) {
        return;
      }

      final files = await imagesDir.list().toList();
      int deletedCount = 0;

      for (var entity in files) {
        if (entity is File) {
          // Check if this image path is in the valid list
          if (!validImagePaths.contains(entity.path)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        developer.log('Cleaned up $deletedCount orphaned images');
      }
    } catch (e) {
      developer.log('Error cleaning up orphaned images: $e');
    }
  }

  /// Get total size of all stored images in MB
  static Future<double> getTotalStorageSize() async {
    try {
      final imagesDir = await _getImagesDirectory();

      if (!await imagesDir.exists()) {
        return 0.0;
      }

      int totalBytes = 0;
      final files = await imagesDir.list().toList();

      for (var entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          totalBytes += stat.size;
        }
      }

      return totalBytes / (1024 * 1024); // Convert to MB
    } catch (e) {
      developer.log('Error calculating storage size: $e');
      return 0.0;
    }
  }
}

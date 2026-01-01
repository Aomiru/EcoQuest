import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/species.dart';
import 'app_logger.dart';

/// AI Species Identification Service using TensorFlow Lite
class AISpeciesIdentificationService {
  static List<String>? _labels;
  static Interpreter? _interpreter;
  static bool _isInitialized = false;
  static final Map<String, Map<String, dynamic>> _speciesData = {};

  /// Get initialization status
  static bool get isInitialized => _isInitialized;

  /// Get number of species in the model
  static int get speciesCount => _labels?.length ?? 0;

  /// Initialize and load TensorFlow Lite model + labels
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('🧠 Initializing AI Species Identification Service...');

      // ✅ Load labels
      final labelsData = await rootBundle.loadString(
        'assets/models/labels.txt',
      );
      _labels = labelsData
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      AppLogger.info('✅ Loaded ${_labels!.length} labels.');

      // ✅ Load species database
      await _loadSpeciesDatabase();

      // ✅ Load TensorFlow Lite model (use full asset path)
      _interpreter = await Interpreter.fromAsset(
        'assets/models/species_model.tflite',
      );
      AppLogger.info('✅ TensorFlow Lite model loaded successfully.');

      _isInitialized = true;
    } catch (e) {
      AppLogger.error('❌ Error initializing AI Service: $e', e);
      _isInitialized = false;
    }
  }

  /// Identify species from image file
  static Future<Species?> identifySpecies(String imagePath) async {
    if (!_isInitialized) await initialize();

    final imageFile = File(imagePath);
    if (!imageFile.existsSync()) {
      AppLogger.warning('⚠️ Image file not found: $imagePath');
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        AppLogger.warning('⚠️ Failed to decode image.');
        return null;
      }

      // Run inference
      final result = await _runInference(image);

      final confidence = result['confidence'] as double;
      final speciesName = result['species'] as String;

      if (confidence < 90) {
        AppLogger.warning('⚠️ Confidence too low: $confidence%');
        return null;
      }
      AppLogger.info(
        '✅ Species detected: $speciesName (${confidence.toStringAsFixed(2)}%)',
      );
      return _createSpecies(speciesName, confidence, imagePath);
    } catch (e) {
      AppLogger.error('❌ Error identifying species: $e', e);
      return null;
    }
  }

  /// Identify species with confidence information
  static Future<Map<String, dynamic>> identifySpeciesWithConfidence(
    String imagePath,
  ) async {
    if (!_isInitialized) await initialize();

    final imageFile = File(imagePath);
    if (!imageFile.existsSync()) {
      AppLogger.warning('⚠️ Image file not found: $imagePath');
      return {'species': null, 'confidence': 0.0};
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        AppLogger.warning('⚠️ Failed to decode image.');
        return {'species': null, 'confidence': 0.0};
      }

      // Run inference
      final result = await _runInference(image);

      final confidence = result['confidence'] as double;
      final speciesName = result['species'] as String;

      AppLogger.debug(
        '🔍 Species analysis: $speciesName (${confidence.toStringAsFixed(2)}%)',
      );

      if (confidence < 90) {
        AppLogger.warning('⚠️ Confidence too low: $confidence%');
        return {'species': null, 'confidence': confidence};
      }

      final species = _createSpecies(speciesName, confidence, imagePath);
      AppLogger.info(
        '✅ Species detected with confidence: $speciesName (${confidence.toStringAsFixed(2)}%)',
      );

      return {'species': species, 'confidence': confidence};
    } catch (e) {
      AppLogger.error('❌ Error identifying species with confidence: $e', e);
      return {'species': null, 'confidence': 0.0};
    }
  }

  /// Core inference function
  static Future<Map<String, dynamic>> _runInference(img.Image image) async {
    if (_interpreter == null || _labels == null) {
      throw Exception('Model not initialized');
    }

    // Get input shape
    final inputShape = _interpreter!.getInputTensor(0).shape;
    final height = inputShape[1];
    final width = inputShape[2];

    // Preprocess image
    final resized = img.copyResize(image, width: width, height: height);

    final input = List.generate(
      1,
      (_) => List.generate(height, (y) {
        return List.generate(width, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        });
      }),
    );

    final output = List.generate(1, (_) => List.filled(_labels!.length, 0.0));

    _interpreter!.run(input, output);

    final predictions = List<double>.from(output[0]);
    final maxIndex = predictions.indexWhere(
      (score) => score == predictions.reduce((a, b) => a > b ? a : b),
    );

    final confidence = (predictions[maxIndex] * 100).clamp(0.0, 100.0);
    final species = _labels![maxIndex];

    return {'species': species, 'confidence': confidence};
  }

  /// Create species object
  static Species _createSpecies(
    String name,
    double confidence,
    String imagePath,
  ) {
    final info = _getSpeciesData(name);
    return Species(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      scientificName: info['scientificName'] ?? 'Unknown',
      description: info['description'] ?? 'No description available.',
      habitat: info['habitat'] ?? 'Unknown habitat',
      conservationStatus: info['status'] ?? 'Unknown',
      characteristics: List<String>.from(info['characteristics'] ?? []),
      imageUrl: imagePath,
      type: info['type'] ?? 'fauna', // flora or fauna
      category: info['category'], // Mammal, Bird, Fish, Insect, Plant, Flower
    );
  }

  /// Get species data from loaded map
  static Map<String, dynamic> _getSpeciesData(String name) {
    return _speciesData[name] ?? {};
  }

  /// Load species database from assets/models/species_db.txt
  static Future<void> _loadSpeciesDatabase() async {
    try {
      final raw = await rootBundle.loadString('assets/models/species_db.txt');
      final lines = raw
          .split('\n')
          .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('#'));
      for (final line in lines) {
        final parts = line.split('|');
        if (parts.length < 8) {
          continue; // skip malformed (now requires 8 parts: name|scientific|desc|habitat|status|type|category|characteristics)
        }
        final name = parts[0].trim();
        final scientific = parts[1].trim();
        final description = parts[2].trim();
        final habitat = parts[3].trim();
        final status = parts[4].trim();
        final type = parts[5].trim().toLowerCase(); // flora or fauna
        final category = parts[6]
            .trim(); // Mammal, Bird, Fish, Insect, Plant, Flower
        final characteristics = parts[7]
            .split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        _speciesData[name] = {
          'scientificName': scientific,
          'description': description,
          'habitat': habitat,
          'status': status,
          'type': type,
          'category': category,
          'characteristics': characteristics,
        };
      }
      AppLogger.info(
        '📄 Species database loaded: ${_speciesData.length} entries',
      );
    } catch (e) {
      AppLogger.error('❌ Failed to load species database', e);
    }
  }

  /// Cleanup
  static void dispose() {
    if (_interpreter != null) {
      _interpreter!.close();
      AppLogger.info('🧹 TensorFlow interpreter closed.');
    }
    _interpreter = null;
    _labels = null;
    _speciesData.clear();
    _isInitialized = false;
  }
}

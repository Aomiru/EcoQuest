import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'main_container.dart';
import '../services/journal_service.dart';
import '../services/ai_species_service.dart';
import '../services/location_service.dart';
import '../services/image_storage_service.dart';
import '../services/background_music_service.dart';
import '../models/journal_entry.dart';
import '../models/species.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isFlashOn = false;
  bool _isBackCamera = true;
  File? _capturedImage;
  late AnimationController _flashAnimationController;
  late AnimationController _captureAnimationController;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flashAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _captureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeCamera();
    _initializeAIService();

    // Pause background music when entering camera screen
    BackgroundMusicService.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _flashAnimationController.dispose();
    _captureAnimationController.dispose();
    AISpeciesIdentificationService.dispose();

    // Resume background music when leaving camera screen
    BackgroundMusicService.resume();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
      // Pause music when app goes to background
      BackgroundMusicService.pause();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      // Music stays paused while in camera screen
    }
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No cameras available on this device');
      }

      // Use back camera by default
      final camera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      setState(() {
        _isCameraInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeAIService() async {
    try {
      if (!AISpeciesIdentificationService.isInitialized) {
        await AISpeciesIdentificationService.initialize();
        developer.log(
          'AI Service initialized - TensorFlow Lite Model Loaded, Species: ${AISpeciesIdentificationService.speciesCount}',
        );
      } else {
        developer.log('AI Service already initialized');
      }
    } catch (e) {
      developer.log('Failed to initialize AI Service: $e');
      // Show error to user since TensorFlow model is required
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'AI species identification unavailable: Model loading failed',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _initializeAIService(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;

    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });

      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );

      _flashAnimationController.forward().then((_) {
        _flashAnimationController.reverse();
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      _showErrorDialog(
        'Flash Error',
        'Failed to toggle flash: ${e.toString()}',
      );
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;

    try {
      setState(() {
        _isLoading = true;
      });

      await _cameraController?.dispose();

      final newCamera = _cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            (_isBackCamera
                ? CameraLensDirection.front
                : CameraLensDirection.back),
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      setState(() {
        _isBackCamera = !_isBackCamera;
        _isFlashOn = false; // Reset flash when switching cameras
        _isCameraInitialized = true;
        _isLoading = false;
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog(
        'Camera Error',
        'Failed to flip camera: ${e.toString()}',
      );
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Check if AI service is ready
    if (!AISpeciesIdentificationService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('AI service is still loading. Please wait...'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Retry Init',
            textColor: Colors.white,
            onPressed: () => _initializeAIService(),
          ),
        ),
      );
      return;
    }

    try {
      HapticFeedback.heavyImpact();
      _captureAnimationController.forward().then((_) {
        _captureAnimationController.reverse();
      });

      final XFile image = await _cameraController!.takePicture();

      // Store original image for display
      setState(() {
        _capturedImage = File(image.path);
      });

      _showImagePreview();
    } catch (e) {
      _showErrorDialog(
        'Capture Error',
        'Failed to take picture: ${e.toString()}',
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
        });
        _showImagePreview();
      }
    } catch (e) {
      _showErrorDialog(
        'Gallery Error',
        'Failed to pick image: ${e.toString()}',
      );
    }
  }

  void _showImagePreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildImagePreviewModal(),
    );
  }

  Widget _buildImagePreviewModal() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 50,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Great Shot!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MainContainer(initialIndex: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Image preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: _capturedImage != null
                    ? Image.file(_capturedImage!, fit: BoxFit.cover)
                    : const Center(child: Text('No image captured')),
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MainContainer(initialIndex: 1),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAnalysisDialog();
                      // Navigation to journal will happen after saving in the dialog
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text('Identify'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAnalysisDialog() {
    _performAIAnalysis();
  }

  Future<void> _performAIAnalysis() async {
    if (_capturedImage == null) {
      _showErrorDialog('Analysis Error', 'No image available for analysis');
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      color: const Color(0xFF4CAF50),
                      strokeWidth: 4,
                    ),
                  ),
                  const Icon(
                    Icons.psychology,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'AI Analysis in Progress...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Identify species\nand saving results to your journal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Check if AI service is initialized
      if (!AISpeciesIdentificationService.isInitialized) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorDialog(
          'AI Service Error',
          'AI Species Identification Service is not initialized. Please restart the app.',
        );
        return;
      }

      // Create cropped image for AI analysis (but keep original for display/saving)
      final File croppedImageForAI = await _cropImageToFocusArea(
        _capturedImage!,
      );

      // Perform AI analysis using the cropped image
      final result = await JournalService.identifySpeciesWithConfidence(
        croppedImageForAI.path,
      );
      final List<Species> identifiedSpecies = result['species'];
      final double aiConfidence = result['confidence'];

      // Clean up the temporary cropped image after analysis
      try {
        await croppedImageForAI.delete();
      } catch (e) {
        // Ignore cleanup errors
      }

      // Close loading dialog (ensure still mounted)
      if (!mounted) return;
      Navigator.of(context).pop();

      if (identifiedSpecies.isNotEmpty) {
        // Check if species already exists in journal
        final speciesName = identifiedSpecies.first.name;
        final alreadyExists = await JournalService.hasSpecies(speciesName);

        if (alreadyExists) {
          // Show "already discovered" dialog
          if (!mounted) return;
          _showAlreadyDiscoveredDialog(speciesName);
          return;
        }

        // Get location
        final location = await LocationService.getCurrentLocationString();
        final position = await LocationService.getCurrentPosition();

        // Save image to permanent storage instead of using temporary cache
        final permanentImagePath =
            await ImageStorageService.saveImagePermanently(_capturedImage!);

        // Auto-save to journal if species identified
        final journalEntryId = DateTime.now().millisecondsSinceEpoch.toString();
        final journalEntry = JournalEntry(
          id: journalEntryId,
          imagePath:
              permanentImagePath, // Use permanent path instead of temp cache
          captureDate: DateTime.now().toIso8601String(),
          identifiedSpecies: identifiedSpecies,
          confidence: aiConfidence,
          location: location,
          latitude: position?.latitude,
          longitude: position?.longitude,
          notes: '', // Auto-saved entries have no notes initially
        );

        await JournalService.saveJournalEntry(journalEntry);
        if (!mounted) return;

        // Show success popup with identified species
        _showSpeciesFoundDialog(identifiedSpecies, journalEntry, aiConfidence);
      } else {
        // No species identified - show popup with image
        if (!mounted) return;
        _showNoSpeciesFoundDialog();
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      String errorMessage = 'Could not analyze the image: ${e.toString()}';
      if (e.toString().contains('TensorFlow') ||
          e.toString().contains('model') ||
          e.toString().contains('Model not initialized')) {
        errorMessage =
            'AI model error: Please ensure the TensorFlow Lite model is properly loaded. Try restarting the app.';
      }

      if (mounted) {
        _showErrorDialog('Analysis Failed', errorMessage);
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade600, size: 32),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.red)),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNoSpeciesFoundDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          contentPadding: const EdgeInsets.all(0),
          content: Container(
            width: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.withOpacity(0.1),
                  Colors.red.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.8),
                        Colors.deepOrange.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Species Found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Image preview
                Container(
                  margin: const EdgeInsets.all(20),
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(
                      _capturedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),

                // Message with formative feedback
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const Text(
                        '🔍 Oops! Species Not Found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Don\'t worry, young explorer! Finding animals can be tricky. Here are some tips:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTipRow(
                              '💡',
                              'Make sure the animal is in focus',
                            ),
                            const SizedBox(height: 8),
                            _buildTipRow('☀️', 'Use good lighting'),
                            const SizedBox(height: 8),
                            _buildTipRow('📸', 'Get closer to your subject'),
                            const SizedBox(height: 8),
                            _buildTipRow(
                              '🎯',
                              'Center the animal in the frame',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Keep trying! Every great scientist learns from practice! 🌟',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Discard button
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog
                            _discardImage();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Try Again button
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4CAF50),
                                const Color(0xFF66BB6A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close dialog
                              _discardImage(); // Reset to camera view
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Try Again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAlreadyDiscoveredDialog(String speciesName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          contentPadding: const EdgeInsets.all(0),
          content: Container(
            width: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.purple.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.8),
                        Colors.purple.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.playlist_add_check,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Already Discovered!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Message with formative feedback
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        '🎉 Great Eye!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You spotted a',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        speciesName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bookmark_added,
                                  color: Colors.blue.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Already in Your Collection!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'You\'ve discovered this species before! That shows you\'re really good at spotting wildlife. 🌟',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Challenge: Can you find a NEW species?',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        _discardImage(); // Go back to camera
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _discardImage() {
    setState(() {
      _capturedImage = null;
    });
  }

  /// Helper to build tip rows for feedback
  Widget _buildTipRow(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Crop captured image to focus square area (224x224 pixels centered)
  Future<File> _cropImageToFocusArea(File originalImage) async {
    try {
      if (!mounted) return originalImage;
      // Capture screen dimensions BEFORE any async gap to avoid context-after-await lint
      final screenSize = MediaQuery.of(context).size;
      final screenWidth = screenSize.width;
      final screenHeight = screenSize.height;

      // Read bytes and decode image
      final bytes = await originalImage.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate the aspect ratio and actual image dimensions
      final imageWidth = decodedImage.width;
      final imageHeight = decodedImage.height;

      // Calculate scale factors between screen and actual image
      final scaleX = imageWidth / screenWidth;
      final scaleY = imageHeight / screenHeight;

      // Focus square is 224x224 centered on screen
      const focusSquareSize = 224.0;
      final focusSquareX = (screenWidth - focusSquareSize) / 2;
      final focusSquareY = (screenHeight - focusSquareSize) / 2;

      // Convert screen coordinates to image coordinates
      final cropX = (focusSquareX * scaleX).round();
      final cropY = (focusSquareY * scaleY).round();
      final cropWidth = (focusSquareSize * scaleX).round();
      final cropHeight = (focusSquareSize * scaleY).round();

      // Ensure crop area is within image bounds
      final validCropX = cropX.clamp(0, imageWidth - cropWidth);
      final validCropY = cropY.clamp(0, imageHeight - cropHeight);
      final validCropWidth = cropWidth.clamp(1, imageWidth - validCropX);
      final validCropHeight = cropHeight.clamp(1, imageHeight - validCropY);

      // Crop the image to focus square area
      final img.Image croppedImage = img.copyCrop(
        decodedImage,
        x: validCropX,
        y: validCropY,
        width: validCropWidth,
        height: validCropHeight,
      );

      // Resize to standard 224x224 for AI analysis
      final img.Image resizedImage = img.copyResize(
        croppedImage,
        width: 224,
        height: 224,
      );

      // Save cropped image
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'ecoquest_cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(appDir.path, fileName);

      final File croppedFile = File(filePath);
      await croppedFile.writeAsBytes(img.encodeJpg(resizedImage));

      developer.log(
        'Image cropped to focus area: ${validCropWidth}x$validCropHeight -> 224x224',
      );
      return croppedFile;
    } catch (e) {
      developer.log('Error cropping image: $e');
      // If cropping fails, return original image
      return originalImage;
    }
  }

  void _showSpeciesFoundDialog(
    List<Species> identifiedSpecies,
    JournalEntry journalEntry,
    double confidence,
  ) {
    // Get the first (most confident) species
    final Species species = identifiedSpecies.first;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          contentPadding: const EdgeInsets.all(0),
          content: Container(
            width: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4CAF50).withOpacity(0.1),
                  Colors.teal.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with success icon
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4CAF50).withOpacity(0.9),
                        const Color(0xFF66BB6A).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Species Identified!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Image preview
                Container(
                  margin: const EdgeInsets.all(20),
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(
                      _capturedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),

                // Species information
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Species common name
                      Text(
                        species.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      // Scientific name
                      Text(
                        species.scientificName,
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // XP Reward badge based on conservation status
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                species.conservationStatus
                                        .toLowerCase()
                                        .contains('critically endangered') ||
                                    species.conservationStatus
                                        .toLowerCase()
                                        .contains('critical')
                                ? [
                                    Colors.orange.shade600,
                                    Colors.orange.shade400,
                                  ] // Critically Endangered - 150 XP
                                : species.conservationStatus
                                          .toLowerCase()
                                          .contains('vulnerable') ||
                                      species.conservationStatus
                                          .toLowerCase()
                                          .contains('endangered')
                                ? [
                                    Colors.orange.shade600,
                                    Colors.orange.shade400,
                                  ] // Vulnerable/Endangered - 100 XP
                                : [
                                    Colors.orange.shade600,
                                    Colors.orange.shade400,
                                  ], // Other - 50 XP
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (species.conservationStatus
                                                  .toLowerCase()
                                                  .contains(
                                                    'critically endangered',
                                                  ) ||
                                              species.conservationStatus
                                                  .toLowerCase()
                                                  .contains('critical')
                                          ? Colors.red.shade600
                                          : species.conservationStatus
                                                    .toLowerCase()
                                                    .contains('vulnerable') ||
                                                species.conservationStatus
                                                    .toLowerCase()
                                                    .contains('endangered')
                                          ? Colors.orange.shade600
                                          : Colors.green.shade600)
                                      .withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              species.conservationStatus.toLowerCase().contains(
                                        'critically endangered',
                                      ) ||
                                      species.conservationStatus
                                          .toLowerCase()
                                          .contains('critical')
                                  ? '+150 XP & Points'
                                  : species.conservationStatus
                                            .toLowerCase()
                                            .contains('vulnerable') ||
                                        species.conservationStatus
                                            .toLowerCase()
                                            .contains('endangered')
                                  ? '+100 XP & Points'
                                  : '+50 XP & Points',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Formative feedback for new discovery
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withOpacity(0.1),
                              Colors.teal.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '🎉',
                                  style: TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'New Discovery!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Awesome work, young scientist! You\'ve added a new species to your collection. Every discovery helps us learn more about nature! 🌿',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '💡',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Check the journal to learn more fun facts!',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Close button
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog
                            // Navigate to home screen and refresh entire app
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MainContainer(initialIndex: 0),
                              ),
                              (route) =>
                                  false, // Clear all routes to force refresh
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // View in Journal button
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4CAF50),
                                const Color(0xFF66BB6A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close dialog
                              // Navigate to journal list and refresh entire app
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MainContainer(initialIndex: 1),
                                ),
                                (route) =>
                                    false, // Clear all routes to force refresh
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.menu_book, size: 18),
                                const SizedBox(width: 6),
                                const Text(
                                  'Open Journal',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
        ),
        title: const Text(
          'Catch \'em',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              onPressed: _flipCamera,
              icon: const Icon(
                Icons.flip_camera_ios,
                color: Colors.white,
                size: 28,
              ),
            ),
          if (_isBackCamera)
            AnimatedBuilder(
              animation: _flashAnimationController,
              builder: (context, child) {
                return IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: _isFlashOn
                        ? Colors.yellow
                        : Colors.white.withOpacity(
                            0.7 + 0.3 * _flashAnimationController.value,
                          ),
                    size: 28,
                  ),
                );
              },
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomControls(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4CAF50)),
            SizedBox(height: 20),
            Text(
              'Initializing Camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: Colors.white.withOpacity(0.5),
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              'Camera Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _initializeCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isCameraInitialized && _cameraController != null) {
      return Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),

          // Camera overlay UI
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
          ),

          // Semi-transparent overlay with cutout for focus frame
          Positioned.fill(
            child: CustomPaint(painter: OverlayPainter(), child: Container()),
          ),

          // Focus frame - 224x224 square
          Center(
            child: Container(
              width: 224,
              height: 224,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4CAF50), width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Corner indicators
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF4CAF50), width: 4),
                          left: BorderSide(color: Color(0xFF4CAF50), width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF4CAF50), width: 4),
                          right: BorderSide(color: Color(0xFF4CAF50), width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFF4CAF50),
                            width: 4,
                          ),
                          left: BorderSide(color: Color(0xFF4CAF50), width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFF4CAF50),
                            width: 4,
                          ),
                          right: BorderSide(color: Color(0xFF4CAF50), width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Text instruction below frame (outside the frame container)
          Positioned(
            top:
                MediaQuery.of(context).size.height / 2 +
                140, // 112 is half of 224 (frame height) + spacing
            left: 0,
            right: 0,
            child: Text(
              'Center species in frame\nAI will analyze this area only',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ), // Capture animation overlay
          AnimatedBuilder(
            animation: _captureAnimationController,
            builder: (context, child) {
              return _captureAnimationController.value > 0
                  ? Container(
                      color: Colors.white.withOpacity(
                        _captureAnimationController.value * 0.5,
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBottomControls() {
    return Container(
      height: 120,
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery button
          GestureDetector(
            onTap: _pickImageFromGallery,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.photo_library,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

          // Capture button
          GestureDetector(
            onTap: _takePicture,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AISpeciesIdentificationService.isInitialized
                    ? const Color(0xFF4CAF50)
                    : Colors.orange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        (AISpeciesIdentificationService.isInitialized
                                ? const Color(0xFF4CAF50)
                                : Colors.orange)
                            .withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.camera_alt, color: Colors.white, size: 40),
                  if (!AISpeciesIdentificationService.isInitialized)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Placeholder for symmetry
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.white54,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that creates a semi-transparent overlay with a cutout for the focus frame
class OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint overlayPaint = Paint()..color = Colors.black.withOpacity(0.3);

    // Calculate the center position for the 224x224 cutout
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double frameSize = 224.0;

    final Rect cutoutRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: frameSize,
      height: frameSize,
    );

    // Create a path for the entire screen
    final Path screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create a path for the cutout area (rounded rectangle)
    final Path cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutoutRect, const Radius.circular(12)),
      );

    // Subtract the cutout from the screen path
    final Path overlayPath = Path.combine(
      PathOperation.difference,
      screenPath,
      cutoutPath,
    );

    // Draw the overlay
    canvas.drawPath(overlayPath, overlayPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

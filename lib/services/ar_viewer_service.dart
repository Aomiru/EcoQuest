import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'dart:convert';

/// AR Viewer Service for displaying 3D GLB models
class ARViewerService {
  /// Get the GLB model path for a species
  static String? getModelPath(String speciesName) {
    // Map species names to their GLB model files
    final modelMap = {
      'Malayan Tiger': 'assets/ar/tiger.glb',
      'Parrot': 'assets/ar/parrot.glb',
      'Bamboo': 'assets/ar/bamboo.glb',
      'Betta': 'assets/ar/betta.glb',
      'Clownfish': 'assets/ar/clownfish.glb',
      'Honeybee': 'assets/ar/honeybee.glb',
      'Hibiscus': 'assets/ar/hibiscus.glb',
      // Add more species mappings here as you add more GLB files
    };

    // Check for exact match first (case-sensitive)
    if (modelMap.containsKey(speciesName)) {
      return modelMap[speciesName];
    }

    // Check for case-insensitive match
    final normalizedName = speciesName.toLowerCase();
    if (modelMap.containsKey(normalizedName)) {
      return modelMap[normalizedName];
    }

    // Check for partial match
    for (var entry in modelMap.entries) {
      final entryKeyLower = entry.key.toLowerCase();
      if (normalizedName.contains(entryKeyLower) ||
          entryKeyLower.contains(normalizedName)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Check if AR model is available for species
  static bool hasARModel(String speciesName) {
    return getModelPath(speciesName) != null;
  }

  /// Build AR viewer widget
  static Widget buildARViewer({
    required String speciesName,
    double? width,
    double? height,
    required BuildContext context,
  }) {
    final modelPath = getModelPath(speciesName);

    if (modelPath == null) {
      return _buildNoModelWidget();
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade100, Colors.blue.shade50],
        ),
      ),
      child: Stack(
        children: [
          FutureBuilder<String>(
            future: _getAssetAsDataUri(modelPath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return _buildErrorWidget();
              }

              return ModelViewer(
                backgroundColor: const Color(0xFF75A5D6),
                src: snapshot.data!,
                alt: '$speciesName 3D Model',
                ar: true,
                arModes: const ['scene-viewer', 'webxr', 'quick-look'],
                autoRotate: true,
                cameraControls: true,
                disableZoom: false,
                loading: Loading.auto,
                autoPlay: true,
                cameraOrbit: "0deg 75deg 2.5m",
                shadowIntensity: 1.0,
                shadowSoftness: 0.5,
                exposure: 1.0,
                fieldOfView: "30deg",
                minCameraOrbit: "auto auto 1m",
                maxCameraOrbit: "auto auto 10m",
                interpolationDecay: 200,
              );
            },
          ),
          // Fullscreen button
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openFullscreen(context, speciesName),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fullscreen,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Open AR viewer in fullscreen
  static void _openFullscreen(BuildContext context, String speciesName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenARViewer(speciesName: speciesName),
      ),
    );
  }

  /// Convert asset to data URI for ModelViewer
  static Future<String> _getAssetAsDataUri(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      final base64String = base64Encode(bytes);
      return 'data:model/gltf-binary;base64,$base64String';
    } catch (e) {
      throw Exception('Failed to load model: $e');
    }
  }

  /// Widget to show when model fails to load
  static Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.red.shade100, Colors.red.shade50],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error Loading 3D Model',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your internet connection',
              style: TextStyle(fontSize: 14, color: Colors.red.shade500),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget to show when no AR model is available
  static Widget _buildNoModelWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey.shade200, Colors.grey.shade100],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.view_in_ar, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'AR Model Not Available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '3D model coming soon!',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen AR Viewer Widget
class _FullscreenARViewer extends StatelessWidget {
  final String speciesName;

  const _FullscreenARViewer({required this.speciesName});

  @override
  Widget build(BuildContext context) {
    final modelPath = ARViewerService.getModelPath(speciesName);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // AR Viewer
          if (modelPath != null)
            FutureBuilder<String>(
              future: ARViewerService._getAssetAsDataUri(modelPath),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Error Loading 3D Model',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ModelViewer(
                  backgroundColor: Colors.black,
                  src: snapshot.data!,
                  alt: '$speciesName 3D Model',
                  ar: true,
                  arModes: const ['scene-viewer', 'webxr', 'quick-look'],
                  autoRotate: true,
                  cameraControls: true,
                  disableZoom: false,
                  loading: Loading.auto,
                  autoPlay: true,
                  cameraOrbit: "0deg 75deg 2.5m",
                  shadowIntensity: 1.0,
                  shadowSoftness: 0.5,
                  exposure: 1.0,
                  fieldOfView: "30deg",
                  minCameraOrbit: "auto auto 1m",
                  maxCameraOrbit: "auto auto 10m",
                  interpolationDecay: 200,
                );
              },
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.view_in_ar, size: 80, color: Colors.white54),
                  const SizedBox(height: 16),
                  const Text(
                    'AR Model Not Available',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No 3D model found for $speciesName',
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
          // Close button
          SafeArea(
            child: Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

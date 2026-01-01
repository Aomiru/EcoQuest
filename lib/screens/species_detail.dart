import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/journal_entry.dart';
import '../models/species.dart';
import '../services/journal_service.dart';
import '../services/gemini_service.dart';
import '../services/ar_viewer_service.dart';

class SpeciesDetailScreen extends StatefulWidget {
  final String imagePath;
  final List<Species> identifiedSpecies;
  final JournalEntry? journalEntry;

  const SpeciesDetailScreen({
    super.key,
    required this.imagePath,
    required this.identifiedSpecies,
    this.journalEntry,
  });

  @override
  State<SpeciesDetailScreen> createState() => _SpeciesDetailScreenState();
}

class _SpeciesDetailScreenState extends State<SpeciesDetailScreen> {
  List<Species> _identifiedSpecies = [];
  bool _isLoading = true;
  bool _showARImage = false;
  bool _isMapExpanded = false;
  bool _hasInternet = false;
  bool _isCheckingInternet = true;
  List<String> _userNotes = [];
  final TextEditingController _notesController = TextEditingController();
  bool _isGeneratingAIResponse = false;
  final GeminiService _gemini = GeminiService();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkInternetConnection();
    final notes = widget.journalEntry?.notes ?? '';
    if (notes.isNotEmpty) {
      // Handle both old format (single note) and new format (bullet-separated notes)
      if (notes.contains('\n•\n')) {
        _userNotes = notes
            .split('\n•\n')
            .where((n) => n.trim().isNotEmpty)
            .toList();
      } else {
        // Old format: treat entire notes as a single item
        _userNotes = [notes];
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _initializeData() {
    _identifiedSpecies = widget.identifiedSpecies;

    // Only show the first result
    if (_identifiedSpecies.isNotEmpty) {
      _identifiedSpecies = [_identifiedSpecies.first];
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkInternetConnection({
    bool showDialogOnFailure = false,
  }) async {
    setState(() {
      _isCheckingInternet = true;
    });

    try {
      final result = await InternetAddress.lookup(
        'tile.openstreetmap.org',
      ).timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _hasInternet =
              result.isNotEmpty && result.first.rawAddress.isNotEmpty;
          _isCheckingInternet = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasInternet = false;
          _isCheckingInternet = false;
        });

        // Show dialog if retry failed
        if (showDialogOnFailure) {
          _showMapNoInternetDialog();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
            ),
            title: Stack(
              children: [
                // White stroke for title
                Text(
                  'My Discovery!',
                  style: TextStyle(
                    fontSize: 32,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = Colors.white,
                  ),
                ),
                // Main title text
                const Text(
                  'My Discovery!',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 32,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              if (widget.journalEntry != null)
                IconButton(
                  onPressed: _showDeleteDialog,
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                )
              else
                const SizedBox(width: 56),
            ],
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                )
              : Column(
                  children: [
                    _buildImagePreview(),
                    Expanded(child: _buildSpeciesDetails()),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 0),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Show either Image or AR based on toggle
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: _showARImage && _identifiedSpecies.isNotEmpty
                ? ARViewerService.buildARViewer(
                    speciesName: _identifiedSpecies.first.name,
                    width: double.infinity,
                    height: double.infinity,
                    context: context,
                  )
                : Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
          ),
          // AR/Image toggle button
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildImageToggleButton(
                    icon: Icons.photo,
                    label: 'Image',
                    isSelected: !_showARImage,
                    onTap: () {
                      setState(() {
                        _showARImage = false;
                      });
                    },
                  ),
                  _buildImageToggleButton(
                    icon: Icons.view_in_ar,
                    label: 'AR',
                    isSelected: _showARImage,
                    onTap: () {
                      if (_identifiedSpecies.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No species identified for AR view'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      final hasModel = ARViewerService.hasARModel(
                        _identifiedSpecies.first.name,
                      );
                      setState(() {
                        _showARImage = true;
                      });

                      if (!hasModel) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'AR model not available for ${_identifiedSpecies.first.name}',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeciesDetails() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: _identifiedSpecies.isEmpty
          ? _buildNoResultsWidget()
          : ListView.builder(
              itemCount: 1, // Only show first result
              itemBuilder: (context, index) {
                return _buildSpeciesCard(_identifiedSpecies[0]);
              },
            ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'No Species Identified',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No identification data available',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesCard(Species species) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge above species name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(species.conservationStatus),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(species.conservationStatus),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    species.conservationStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Species name text
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          // White stroke
                          Text(
                            species.name,
                            style: TextStyle(
                              fontSize: 32,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w900,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 3
                                ..color = Colors.white.withOpacity(0.7),
                            ),
                          ),
                          // Main text
                          Text(
                            species.name,
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 32,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              species.scientificName,
              style: TextStyle(
                fontSize: 20,
                fontStyle: FontStyle.italic,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4CAF50),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              species.description,
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w400,
                color: Colors.black87,
                height: 1.6,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 20),
            if (species.category != null) ...[
              _buildInfoRow('Category', species.category!),
              const SizedBox(height: 12),
            ],
            _buildInfoRow('Habitat', species.habitat),
            if (species.characteristics.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Cool Features!',
                style: TextStyle(
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: species.characteristics.asMap().entries.map((entry) {
                  final index = entry.key;
                  final characteristic = entry.value;

                  // Define a variety of colors for rotation
                  final colors = [
                    [const Color(0xFF66BB6A), const Color(0xFF4CAF50)], // Green
                    [const Color(0xFF42A5F5), const Color(0xFF1E88E5)], // Blue
                    [
                      const Color(0xFFFF7043),
                      const Color(0xFFFF5722),
                    ], // Orange
                    [
                      const Color(0xFFAB47BC),
                      const Color(0xFF8E24AA),
                    ], // Purple
                    [const Color(0xFFEC407A), const Color(0xFFD81B60)], // Pink
                    [const Color(0xFFFFCA28), const Color(0xFFFFA000)], // Amber
                    [const Color(0xFF26A69A), const Color(0xFF00897B)], // Teal
                    [
                      const Color(0xFF5C6BC0),
                      const Color(0xFF3949AB),
                    ], // Indigo
                  ];

                  final colorPair = colors[index % colors.length];

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colorPair,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colorPair[0].withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      characteristic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            // Location Section
            if (widget.journalEntry != null) ...[
              const SizedBox(height: 20),
              _buildLocationSection(),
            ],
            // Notes Section
            const SizedBox(height: 20),
            _buildNotesSection(),
            if (widget.journalEntry != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Discovered: ${_formatDate(widget.journalEntry!.captureDate)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    // Select icon based on label
    IconData icon;
    Color iconColor;

    switch (label) {
      case 'Type':
        icon = Icons.category;
        iconColor = Colors.purple.shade600;
        break;
      case 'Category':
        icon = Icons.label;
        iconColor = Colors.orange.shade600;
        break;
      case 'Habitat':
        icon = Icons.terrain;
        iconColor = Colors.green.shade600;
        break;
      case 'Status':
        icon = Icons.shield;
        iconColor = Colors.blue.shade600;
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A5568),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    final DateTime date = DateTime.parse(dateString);
    final String formattedDate = '${date.day}/${date.month}/${date.year}';
    final String formattedTime =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$formattedDate at $formattedTime';
  }

  Widget _buildLocationSection() {
    final location = widget.journalEntry?.location ?? '';
    final hasLocation = location.isNotEmpty;
    final latitude = widget.journalEntry?.latitude;
    final longitude = widget.journalEntry?.longitude;
    final hasCoordinates = latitude != null && longitude != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.lightBlue.shade50],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Capture Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasLocation)
            Column(
              children: [
                // Address container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pin_drop,
                        size: 18,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Map Section
                if (hasCoordinates) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      children: [
                        // Map preview/expanded view with connectivity check
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                          child: SizedBox(
                            height: _isMapExpanded ? 300 : 150,
                            child: _isCheckingInternet
                                ? Container(
                                    color: Colors.blue.shade50,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            color: Colors.blue.shade600,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Loading map...',
                                            style: TextStyle(
                                              color: Colors.blue.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : !_hasInternet
                                ? Container(
                                    color: Colors.grey.shade100,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.wifi_off,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Map requires internet to load',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _checkInternetConnection(
                                                  showDialogOnFailure: true,
                                                ),
                                            icon: const Icon(
                                              Icons.refresh,
                                              size: 18,
                                            ),
                                            label: const Text('Retry'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.blue.shade600,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : FlutterMap(
                                    options: MapOptions(
                                      initialCenter: LatLng(
                                        latitude,
                                        longitude,
                                      ),
                                      initialZoom: _isMapExpanded ? 15.0 : 13.0,
                                      interactionOptions: InteractionOptions(
                                        flags: _isMapExpanded
                                            ? InteractiveFlag.all
                                            : InteractiveFlag.none,
                                      ),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName:
                                            'com.example.ecoquest',
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: LatLng(latitude, longitude),
                                            width: 40,
                                            height: 40,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade600,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 3,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.3),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.photo_camera,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        // Expand/Collapse button (only show when map is loaded)
                        if (_hasInternet && !_isCheckingInternet)
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isMapExpanded = !_isMapExpanded;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isMapExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: Colors.blue.shade600,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isMapExpanded
                                        ? 'Show Less'
                                        : 'Show Full Map',
                                    style: TextStyle(
                                      color: Colors.blue.shade600,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_off,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Location not available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.yellow.shade50, Colors.yellow.shade100],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.yellow.shade600, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.note_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'My Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.yellow.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Display saved notes as bullet points
          if (_userNotes.isNotEmpty)
            ...List.generate(_userNotes.length, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.yellow.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: Colors.yellow.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _userNotes[index],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Edit button
                    InkWell(
                      onTap: () => _showEditNoteDialog(index),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Delete button
                    InkWell(
                      onTap: () => _deleteNote(index),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (_userNotes.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.yellow.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note, size: 20, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'No notes added yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // Add note button and textbox
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.yellow.shade300),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add a new note...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.yellow.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.yellow.shade700,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Add Note',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    elevation: 4,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _isGeneratingAIResponse ? null : _showAskAIDialog,
                icon: _isGeneratingAIResponse
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 20),
                label: Text(
                  _isGeneratingAIResponse ? 'Asking...' : 'Ask AI',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF55AC6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addNote() async {
    final newNote = _notesController.text.trim();
    if (newNote.isEmpty) return;

    setState(() {
      _userNotes.add(newNote);
      _notesController.clear(); // Reset textbox
    });

    if (widget.journalEntry != null) {
      try {
        final notesString = _userNotes.join('\n•\n');
        await JournalService.updateJournalNotes(
          widget.journalEntry!.id,
          notesString,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Note added successfully!'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save note: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showEditNoteDialog(int index) {
    final editController = TextEditingController(text: _userNotes[index]);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Note',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: TextField(
            controller: editController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Write your observations here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                editController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedNote = editController.text.trim();
                if (updatedNote.isNotEmpty) {
                  setState(() {
                    _userNotes[index] = updatedNote;
                  });

                  if (widget.journalEntry != null) {
                    try {
                      final notesString = _userNotes.join('\n•\n');
                      await JournalService.updateJournalNotes(
                        widget.journalEntry!.id,
                        notesString,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Note updated successfully!'),
                              ],
                            ),
                            backgroundColor: Colors.green.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to update note: ${e.toString()}',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                }
                editController.dispose();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _deleteNote(int index) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Delete Note'),
          content: const Text('Are you sure you want to delete this note?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() {
                  _userNotes.removeAt(index);
                });

                if (widget.journalEntry != null) {
                  try {
                    final notesString = _userNotes.isEmpty
                        ? ''
                        : _userNotes.join('\n•\n');
                    await JournalService.updateJournalNotes(
                      widget.journalEntry!.id,
                      notesString,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Note deleted successfully!'),
                          backgroundColor: Colors.red.shade600,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to delete note: ${e.toString()}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showAskAIDialog() {
    if (_identifiedSpecies.isEmpty) return;

    final questionController = TextEditingController();
    final species = _identifiedSpecies.first;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ask AI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.purple.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ask anything about ${species.name}!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: questionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g., How does it hunt? Where does it live?',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.purple.shade400,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                // Dispose after the frame completes to avoid the disposed controller error
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  questionController.dispose();
                });
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final question = questionController.text.trim();
                if (question.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a question'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext);
                // Dispose after the frame completes to avoid the disposed controller error
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  questionController.dispose();
                });
                await _askAI(question);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ask',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _askAI(String question) async {
    if (_identifiedSpecies.isEmpty) return;

    // Quick connectivity check with user-friendly dialog
    bool hasInternet = false;
    try {
      final lookup = await InternetAddress.lookup('google.com');
      hasInternet = lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      hasInternet = false;
    }

    if (!hasInternet) {
      if (mounted) {
        _showNoInternetDialog();
      }
      return;
    }

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              backgroundColor: Colors.white,
              content: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade200,
                            Colors.pink.shade200,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.psychology,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFF55AC6),
                      ),
                      strokeWidth: 4,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '🤔 Thinking hard...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: Colors.purple.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AI is finding the best answer for you!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    setState(() {
      _isGeneratingAIResponse = true;
    });

    try {
      final species = _identifiedSpecies.first;
      final answer = await _gemini.askQuestion(species, question);

      if (!mounted) return;

      setState(() {
        _isGeneratingAIResponse = false;
      });

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        _showAIResponseDialog(question, answer);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isGeneratingAIResponse = false;
      });

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get answer: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAIResponseDialog(String question, String answer) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI Response',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 20,
                          color: Colors.purple.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            question,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.purple.shade50, Colors.pink.shade50],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lightbulb,
                          size: 48,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          answer,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade800,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Discard',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _saveAIResponseAsNote(question, answer);
              },
              icon: const Icon(Icons.save, size: 18),
              label: const Text(
                'Save to Notes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAIResponseAsNote(String question, String answer) async {
    final insertion = '$question\n   Answer: $answer';
    setState(() {
      _userNotes.add(insertion);
    });

    if (widget.journalEntry != null) {
      try {
        final notesString = _userNotes.join('\n•\n');
        await JournalService.updateJournalNotes(
          widget.journalEntry!.id,
          notesString,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('AI response saved to notes!'),
              backgroundColor: Colors.purple.shade600,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showMapNoInternetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'No Internet Connection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.lightBlue.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 56, color: Colors.blue.shade400),
                const SizedBox(height: 16),
                Text(
                  'Please connect to WiFi or mobile data to view the map.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'The map requires an active internet connection to load.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade600, Colors.orange.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'No Internet Connection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.withOpacity(0.1),
                  Colors.amber.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 56, color: Colors.orange.shade400),
                const SizedBox(height: 16),
                Text(
                  'Please connect to WiFi or mobile data to generate fun facts.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Fun facts require an internet connection to use AI.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.8),
                      Colors.redAccent.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_forever,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete Species Entry',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.withOpacity(0.05),
                  Colors.orange.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.red.withOpacity(0.2), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to delete this species identification?',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone and the entry will be permanently removed from your journal.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Delete button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.withOpacity(0.8),
                    Colors.redAccent.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _deleteEntry();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_forever, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteEntry() async {
    try {
      // Delete from journal database
      await JournalService.deleteJournalEntry(widget.journalEntry!.id);

      // Delete the image file
      final imageFile = File(widget.imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Species entry deleted successfully!',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back to journal list
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(
            context,
          ).pop('deleted'); // Always return to journal list with result
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete entry: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('critically endangered')) {
      return Colors.red.shade700;
    } else if (lowerStatus.contains('endangered')) {
      return Colors.red.shade500;
    } else if (lowerStatus.contains('vulnerable')) {
      return Colors.orange.shade600;
    } else if (lowerStatus.contains('near threatened')) {
      return Colors.orange.shade400;
    } else if (lowerStatus.contains('least concern')) {
      return Colors.green.shade600;
    } else {
      return Colors.blue.shade600;
    }
  }

  IconData _getStatusIcon(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('endangered')) {
      return Icons.warning;
    } else if (lowerStatus.contains('vulnerable') ||
        lowerStatus.contains('threatened')) {
      return Icons.error_outline;
    } else if (lowerStatus.contains('least concern')) {
      return Icons.check_circle;
    } else {
      return Icons.shield;
    }
  }
}

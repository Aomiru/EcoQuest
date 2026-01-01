import 'dart:io';
import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import '../services/journal_service.dart';
import '../services/badge_popup_manager.dart';
import '../services/image_storage_service.dart';
import 'species_detail.dart';
import 'camera.dart';
import '../main.dart';

class JournalListScreen extends StatefulWidget {
  const JournalListScreen({super.key});

  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

enum SortOption { timeNewest }

enum SpeciesFilter { all, flora, fauna }

class _JournalListScreenState extends State<JournalListScreen>
    with WidgetsBindingObserver {
  List<JournalEntry> _journalEntries = [];
  List<JournalEntry> _filteredEntries = [];
  bool _isLoading = true;
  SpeciesFilter _currentFilter = SpeciesFilter.all;
  String? _selectedStatus;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadJournalEntries();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh when app comes back to foreground
      _refreshJournalEntries();
      // Check for pending badge unlocks and show popups
      _checkBadgeUnlocks();
    }
  }

  Future<void> _checkBadgeUnlocks() async {
    // Wait a bit for the UI to settle
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await BadgePopupManager.checkAndShowPendingBadges(context);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when navigating back to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshJournalEntries();
    });
  }

  Future<void> _refreshJournalEntries() async {
    // Refresh the journal entries
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
      await _loadJournalEntries();
    }
  }

  Future<void> _loadJournalEntries() async {
    try {
      // First, migrate old temporary image paths to permanent storage
      final migratedCount = await JournalService.migrateOldImagePaths();

      if (migratedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Migrated $migratedCount images to permanent storage',
            ),
            backgroundColor: AppConstants.primaryGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final entries = await JournalService.getJournalEntries();

      // Clean up entries with missing images (after migration)
      await _cleanupMissingImages(entries);

      // Reload after cleanup
      final cleanedEntries = await JournalService.getJournalEntries();

      setState(() {
        _journalEntries = cleanedEntries;
        _applySorting();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load journal entries: ${e.toString()}');
    }
  }

  Future<void> _cleanupMissingImages(List<JournalEntry> entries) async {
    int removedCount = 0;

    for (var entry in entries) {
      // Check if image file exists
      final imageExists = await ImageStorageService.imageExists(
        entry.imagePath,
      );

      if (!imageExists) {
        // Remove entry with missing image
        await JournalService.deleteJournalEntry(entry.id);
        removedCount++;
      }
    }

    if (removedCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $removedCount entries with missing images'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _applySorting() {
    List<JournalEntry> sortedEntries = List.from(_journalEntries);

    // Apply search filter first
    if (_searchQuery.isNotEmpty) {
      sortedEntries = sortedEntries.where((entry) {
        if (entry.identifiedSpecies.isEmpty) return false;
        final speciesName = entry.identifiedSpecies.first.name.toLowerCase();
        final scientificName = entry.identifiedSpecies.first.scientificName
            .toLowerCase();
        final query = _searchQuery.toLowerCase();
        return speciesName.contains(query) || scientificName.contains(query);
      }).toList();
    }

    // Apply filter
    if (_currentFilter != SpeciesFilter.all) {
      sortedEntries = sortedEntries.where((entry) {
        if (entry.identifiedSpecies.isEmpty) return false;
        final speciesType = entry.identifiedSpecies.first.type.toLowerCase();
        return _currentFilter == SpeciesFilter.flora
            ? speciesType == 'flora'
            : speciesType == 'fauna';
      }).toList();
    }

    // Then apply sorting (always newest first)
    sortedEntries.sort((a, b) => b.captureDate.compareTo(a.captureDate));

    _filteredEntries = sortedEntries;
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSortDialog() {
    String? selectedCategory;
    String? selectedStatus = _selectedStatus;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.sort, color: AppConstants.primaryGreen, size: 32),
                  const SizedBox(width: 12),
                  const Text(
                    'Sort Journal Entries',
                    style: TextStyle(
                      color: AppConstants.primaryGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category filter section
                    Row(
                      children: [
                        Icon(
                          Icons.category,
                          color: AppConstants.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Filter by Category',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppConstants.primaryGreen.withOpacity(0.3),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedCategory,
                          hint: const Text('All Categories'),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: AppConstants.primaryGreen,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Categories'),
                            ),
                            ..._getAvailableCategories().map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category[0].toUpperCase() +
                                      category.substring(1),
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value;
                            });
                          },
                        ),
                      ),
                    ),
                    if (selectedCategory != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppConstants.primaryGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Showing only ${selectedCategory![0].toUpperCase()}${selectedCategory!.substring(1)} species',
                                style: TextStyle(
                                  color: AppConstants.primaryGreen,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Conservation Status filter section
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: AppConstants.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Filter by Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppConstants.primaryGreen.withOpacity(0.3),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedStatus,
                          hint: const Text('All Conservation Status'),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: AppConstants.primaryGreen,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Conservation Status'),
                            ),
                            ..._getAvailableStatuses().map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(
                                  status[0].toUpperCase() + status.substring(1),
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedStatus = value;
                            });
                          },
                        ),
                      ),
                    ),
                    if (selectedStatus != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppConstants.primaryGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Showing only ${selectedStatus![0].toUpperCase()}${selectedStatus!.substring(1)} species',
                                style: TextStyle(
                                  color: AppConstants.primaryGreen,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStatus = selectedStatus;
                    });
                    if (selectedCategory != null) {
                      _applyCategoryFilter(selectedCategory);
                    } else if (selectedStatus != null) {
                      _applyStatusFilter(selectedStatus);
                    } else {
                      _applySorting();
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      color: AppConstants.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _getAvailableCategories() {
    final categories = <String>{};
    for (var entry in _journalEntries) {
      if (entry.identifiedSpecies.isNotEmpty) {
        final category = entry.identifiedSpecies.first.category;
        if (category != null && category.isNotEmpty) {
          categories.add(category.toLowerCase());
        }
      }
    }
    return categories.toList()..sort();
  }

  void _applyCategoryFilter(String? category) {
    setState(() {
      if (category == null) {
        _applySorting();
      } else {
        List<JournalEntry> filteredByCategory = _journalEntries.where((entry) {
          if (entry.identifiedSpecies.isEmpty) return false;
          final entryCategory = entry.identifiedSpecies.first.category
              ?.toLowerCase();
          return entryCategory == category.toLowerCase();
        }).toList();

        // Apply current filter (flora/fauna) if set
        if (_currentFilter != SpeciesFilter.all) {
          filteredByCategory = filteredByCategory.where((entry) {
            final speciesType = entry.identifiedSpecies.first.type
                .toLowerCase();
            return _currentFilter == SpeciesFilter.flora
                ? speciesType == 'flora'
                : speciesType == 'fauna';
          }).toList();
        }

        // Apply current sorting
        _sortEntries(filteredByCategory);
        _filteredEntries = filteredByCategory;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              category == null
                  ? 'Showing all categories'
                  : 'Filtered by ${category[0].toUpperCase()}${category.substring(1)}',
            ),
          ],
        ),
        backgroundColor: AppConstants.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _sortEntries(List<JournalEntry> entries) {
    entries.sort((a, b) => b.captureDate.compareTo(a.captureDate));
  }

  List<String> _getAvailableStatuses() {
    final statuses = <String>{};
    for (var entry in _journalEntries) {
      if (entry.identifiedSpecies.isNotEmpty) {
        final status = entry.identifiedSpecies.first.conservationStatus;
        if (status.isNotEmpty) {
          statuses.add(status.toLowerCase());
        }
      }
    }
    return statuses.toList()..sort();
  }

  void _applyStatusFilter(String? status) {
    setState(() {
      if (status == null) {
        _applySorting();
      } else {
        List<JournalEntry> filteredByStatus = _journalEntries.where((entry) {
          if (entry.identifiedSpecies.isEmpty) return false;
          final entryStatus = entry.identifiedSpecies.first.conservationStatus
              .toLowerCase();
          return entryStatus == status.toLowerCase();
        }).toList();

        // Apply current filter (flora/fauna) if set
        if (_currentFilter != SpeciesFilter.all) {
          filteredByStatus = filteredByStatus.where((entry) {
            final speciesType = entry.identifiedSpecies.first.type
                .toLowerCase();
            return _currentFilter == SpeciesFilter.flora
                ? speciesType == 'flora'
                : speciesType == 'fauna';
          }).toList();
        }

        // Apply current sorting
        _sortEntries(filteredByStatus);
        _filteredEntries = filteredByStatus;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              status == null
                  ? 'Showing all conservation statuses'
                  : 'Filtered by ${status[0].toUpperCase()}${status.substring(1)}',
            ),
          ],
        ),
        backgroundColor: AppConstants.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 42), // Title - Perfectly centered
              Expanded(
                child: Center(
                  child: Stack(
                    children: [
                      // White shadow layer
                      Text(
                        'My Journal',
                        style: TextStyle(
                          fontSize: 42,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 4
                            ..color = Colors.white.withOpacity(0.5),
                        ),
                      ),
                      // Stroke layer
                      Text(
                        'My Journal',
                        style: TextStyle(
                          fontSize: 42,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 2
                            ..color = const Color.fromARGB(255, 7, 107, 11),
                        ),
                      ),
                      // Main text layer
                      Text(
                        'My Journal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search button
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        _searchQuery = '';
                        _applySorting();
                      }
                    });
                  },
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image - same as user screen but showing middle portion
          Container(
            height: 200, // Cover the header area
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.center, // Show middle portion of the image
              ),
            ),
          ),

          // Light gradient overlay for text readability
          Container(
            height: 400,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),

          // Main Content with overlapping structure like user.dart
          Stack(
            children: [
              // Header with extended background that overlaps (z-index +1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: _buildHeader()),
              ),
              // White card container positioned to allow overlap (z-index 0)
              Positioned.fill(
                top: 110, // Leave space for header overlap
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromARGB(26, 0, 0, 0),
                        blurRadius: 5,
                        offset: Offset(0, -3),
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Journal content
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppConstants.primaryGreen,
                                ),
                              )
                            : _filteredEntries.isEmpty
                            ? _buildEmptyState()
                            : _buildJournalList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.book_outlined,
                      size: 60,
                      color: AppConstants.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Discoveries Yet',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start capturing wildlife to build\nyour species journal!',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to camera screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CameraScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Start Exploring'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJournalList() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2), // Space for overlap
          // Search bar
          if (_isSearching)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppConstants.primaryGreen.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search species...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: AppConstants.primaryGreen),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applySorting();
                  });
                },
              ),
            ),
          // Filter buttons row
          Row(
            children: [
              Expanded(child: _buildFilterButtons()),
              const SizedBox(width: 8),
              // Filter dialog button
              InkWell(
                onTap: _showSortDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppConstants.primaryGreen.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.filter_list,
                    color: AppConstants.primaryGreen,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppConstants.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppConstants.primaryGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_filteredEntries.length} Species Discovered',
                  style: const TextStyle(
                    color: AppConstants.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Grid of entries (2 columns) with pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshJournalEntries,
              color: AppConstants.primaryGreen,
              child: GridView.builder(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ), // Add padding for navigation bar
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _filteredEntries.length,
                itemBuilder: (context, index) {
                  return _buildJournalGridCard(_filteredEntries[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalGridCard(JournalEntry entry) {
    final isEndangered =
        entry.identifiedSpecies.isNotEmpty &&
        (entry.identifiedSpecies.first.conservationStatus
                .toLowerCase()
                .contains('endangered') ||
            entry.identifiedSpecies.first.conservationStatus
                .toLowerCase()
                .contains('threatened'));

    final isRisk =
        entry.identifiedSpecies.isNotEmpty &&
        (entry.identifiedSpecies.first.conservationStatus
                .toLowerCase()
                .contains('vulnerable') ||
            entry.identifiedSpecies.first.conservationStatus
                .toLowerCase()
                .contains('near threatened'));

    // Determine border color based on conservation status
    Color borderColor = const Color(0xFF4CAF50); // Default green
    if (entry.identifiedSpecies.isNotEmpty) {
      final status = entry.identifiedSpecies.first.conservationStatus
          .toLowerCase();
      if (status.contains('endangered') || status.contains('critically')) {
        borderColor = Colors.red.shade600; // Red for endangered
      } else if (status.contains('vulnerable') ||
          status.contains('near threatened')) {
        borderColor = Colors.amber.shade600; // Yellow for near threatened
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpeciesDetailScreen(
                imagePath: entry.imagePath,
                identifiedSpecies: entry.identifiedSpecies,
                journalEntry:
                    entry, // Pass the full journal entry for deletion and display
              ),
            ),
          );
          // Refresh the list if something was deleted or changed
          if (result == 'deleted' || result == 'refresh') {
            _refreshJournalEntries();
          }
        },
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image (takes most of the space)
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                    child: _buildEntryImage(entry),
                  ),
                ),

                // Species name (compact at bottom)
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.identifiedSpecies.isNotEmpty
                              ? entry.identifiedSpecies.first.name
                              : 'Unknown Species',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Endangered badge in top-right corner
            if (isEndangered)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade600, Colors.red.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Endangered',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Risk badge for vulnerable/near threatened species
            if (isRisk && !isEndangered)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade600, Colors.amber.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Risk',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildFilterButton(
            label: 'All',
            icon: Icons.grid_view,
            filter: SpeciesFilter.all,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterButton(
            label: 'Flora',
            icon: Icons.local_florist,
            filter: SpeciesFilter.flora,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterButton(
            label: 'Fauna',
            icon: Icons.pets,
            filter: SpeciesFilter.fauna,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton({
    required String label,
    required IconData icon,
    required SpeciesFilter filter,
  }) {
    final isSelected = _currentFilter == filter;
    return InkWell(
      onTap: () {
        setState(() {
          _currentFilter = filter;
          _applySorting();
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppConstants.primaryGreen
                : AppConstants.primaryGreen.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppConstants.primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppConstants.primaryGreen,
              size: 18,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppConstants.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryImage(JournalEntry entry) {
    try {
      final imageFile = File(entry.imagePath);

      // Check if file exists synchronously (safe for UI)
      if (imageFile.existsSync()) {
        return Image.file(
          imageFile,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // If image fails to load, show placeholder
            return Container(
              color: Colors.grey.shade200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    color: Colors.grey.shade400,
                    size: 40,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Image not available',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        // File doesn't exist - show placeholder
        return Container(
          color: Colors.grey.shade200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                color: Colors.grey.shade400,
                size: 40,
              ),
              const SizedBox(height: 4),
              Text(
                'Image file not found',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Any error - show error placeholder
      return Container(
        color: Colors.grey.shade200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 40),
            const SizedBox(height: 4),
            Text(
              'Error loading image',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
            ),
          ],
        ),
      );
    }
  }
}

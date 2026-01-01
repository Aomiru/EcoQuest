import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/badge.dart' as badge_model;
import '../services/badge_service.dart';
import '../services/badge_tracking_service.dart';
import '../services/badge_popup_manager.dart';
import '../services/leaderboard_service.dart';
import '../services/supabase_auth_service.dart';
import '../widgets/badge_unlock_popup.dart';

class BadgeScreen extends StatefulWidget {
  const BadgeScreen({super.key});

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<badge_model.Badge> _badges = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  // Leaderboard data
  List<LeaderboardEntry> _allTimeLeaderboard = [];
  List<LeaderboardEntry> _weeklyLeaderboard = [];
  bool _isLoadingLeaderboard = false;
  String _leaderboardFilter = 'All Time';
  bool _hasInternet = false;
  bool _isCheckingInternet = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
    _checkInternetAndLoadLeaderboard();
    // Check for pending badge unlocks after screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBadgeUnlocks();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh badge cache from asset file to get latest changes
      await BadgeService.refreshBadgeCache();

      // Check for any new badge unlocks
      await BadgeTrackingService.checkAndUnlockBadges();

      // Load all badges
      final badges = await BadgeService.loadAllBadges();

      setState(() {
        _badges = badges;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkInternetConnection() async {
    setState(() {
      _isCheckingInternet = true;
    });

    try {
      final result = await InternetAddress.lookup(
        'google.com',
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
      }
    }
  }

  Future<void> _checkInternetAndLoadLeaderboard() async {
    await _checkInternetConnection();
    if (_hasInternet) {
      await _loadLeaderboard();
    }
  }

  Future<void> _loadLeaderboard() async {
    if (!SupabaseAuthService.isSignedIn) {
      return;
    }

    if (!_hasInternet) {
      return;
    }

    setState(() {
      _isLoadingLeaderboard = true;
    });

    try {
      final allTime = await LeaderboardService.getAllTimeLeaderboard();
      final weekly = await LeaderboardService.getWeeklyLeaderboard();

      setState(() {
        _allTimeLeaderboard = allTime;
        _weeklyLeaderboard = weekly;
        _isLoadingLeaderboard = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLeaderboard = false;
      });
    }
  }

  Future<void> _checkBadgeUnlocks() async {
    if (mounted) {
      await BadgePopupManager.checkAndShowPendingBadges(context);
    }
  }

  List<badge_model.Badge> _getFilteredBadges() {
    if (_selectedFilter == 'All') {
      return _badges;
    } else if (_selectedFilter == 'Unlocked') {
      return _badges.where((badge) => badge.isUnlocked).toList();
    } else if (_selectedFilter == 'Locked') {
      return _badges.where((badge) => !badge.isUnlocked).toList();
    }
    return _badges;
  }

  @override
  Widget build(BuildContext context) {
    final filteredBadges = _getFilteredBadges();
    final unlockedCount = _badges.where((b) => b.isUnlocked).length;
    final totalCount = _badges.length;

    return Scaffold(
      body: Stack(
        children: [
          // Background image - same as journal list and main screen
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
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

          // Main Content with PageView for swipeable tabs
          Stack(
            children: [
              // Header with tab indicators
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: _buildHeader(unlockedCount, totalCount)),
              ),

              // PageView content
              Positioned.fill(
                top: 175,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _buildBadgesPage(filteredBadges),
                    _buildLeaderboardPage(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int unlockedCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Title
          Center(
            child: Stack(
              children: [
                // White shadow layer
                Text(
                  _currentPage == 0 ? 'Badges' : 'Leaderboard',
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
                  _currentPage == 0 ? 'Badges' : 'Leaderboard',
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
                  _currentPage == 0 ? 'Badges' : 'Leaderboard',
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
          // Tab Indicator
          const SizedBox(height: 0),
          _buildTabIndicator(),
        ],
      ),
    );
  }

  Widget _buildTabIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentPage == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: _currentPage == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: _currentPage == 0
                          ? AppConstants.primaryGreen
                          : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Badges',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _currentPage == 0
                            ? AppConstants.primaryGreen
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentPage == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: _currentPage == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.leaderboard,
                      color: _currentPage == 1
                          ? AppConstants.primaryGreen
                          : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Leaderboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _currentPage == 1
                            ? AppConstants.primaryGreen
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
            filter: 'All',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterButton(
            label: 'Unlocked',
            icon: Icons.lock_open,
            filter: 'Unlocked',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFilterButton(
            label: 'Locked',
            icon: Icons.lock,
            filter: 'Locked',
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton({
    required String label,
    required IconData icon,
    required String filter,
  }) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
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

  Widget _buildBadgeCard(badge_model.Badge badge) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _showBadgeDetails(badge),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge image
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: badge.isUnlocked ? Colors.white : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Image.asset(
                    badge.isUnlocked ? badge.colorImage : badge.bwImage,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 60,
                            color: badge.isUnlocked
                                ? Colors.amber
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Image\nError',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Badge name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  badge.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: badge.isUnlocked
                        ? AppConstants.darkGreen
                        : Colors.grey[600],
                  ),
                ),
              ),

              // Lock/unlock indicator
              Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badge.isUnlocked
                        ? AppConstants.lightGreen
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badge.isUnlocked ? Icons.lock_open : Icons.lock,
                        size: 12,
                        color: badge.isUnlocked
                            ? AppConstants.darkGreen
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        badge.isUnlocked ? 'Unlocked' : 'Locked',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: badge.isUnlocked
                              ? AppConstants.darkGreen
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBadgeDetails(badge_model.Badge badge) async {
    await BadgeUnlockPopup.show(context, badge);
  }

  Widget _buildBadgesPage(List<badge_model.Badge> filteredBadges) {
    final unlockedCount = _badges.where((b) => b.isUnlocked).length;
    final totalCount = _badges.length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppConstants.primaryGreen,
              ),
            )
          : Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  _buildFilterButtons(),
                  const SizedBox(height: 12),
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
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.emoji_events,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$unlockedCount / $totalCount Badges Unlocked',
                              style: const TextStyle(
                                color: AppConstants.primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: totalCount > 0
                                ? unlockedCount / totalCount
                                : 0,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppConstants.primaryGreen,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredBadges.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.emoji_events_outlined,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No badges found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadBadges,
                            color: AppConstants.primaryGreen,
                            child: GridView.builder(
                              padding: const EdgeInsets.only(bottom: 10),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.75,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: filteredBadges.length,
                              itemBuilder: (context, index) {
                                return _buildBadgeCard(filteredBadges[index]);
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLeaderboardPage() {
    if (!SupabaseAuthService.isSignedIn) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.leaderboard, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Sign in to view leaderboard',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentLeaderboard = _leaderboardFilter == 'All Time'
        ? _allTimeLeaderboard
        : _weeklyLeaderboard;

    // Get current user entry
    final currentUserEntry = currentLeaderboard
        .where((entry) => entry.isCurrentUser)
        .firstOrNull;

    // Get other entries (excluding current user if found)
    final otherEntries = currentLeaderboard
        .where((entry) => !entry.isCurrentUser)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 2),
            _buildLeaderboardFilterButtons(),
            const SizedBox(height: 16),
            // Show current user card at the top if signed in
            if (currentUserEntry != null) ...[
              _buildCurrentUserCard(currentUserEntry),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(height: 1, color: Colors.grey[300]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Top Players',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(height: 1, color: Colors.grey[300]),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: _isLoadingLeaderboard || _isCheckingInternet
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppConstants.primaryGreen,
                      ),
                    )
                  : !_hasInternet
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Internet Connection',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please connect to the internet\nto view the leaderboard',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _checkInternetAndLoadLeaderboard,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : otherEntries.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _checkInternetAndLoadLeaderboard,
                      color: AppConstants.primaryGreen,
                      child: ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.leaderboard,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No players yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _checkInternetAndLoadLeaderboard,
                      color: AppConstants.primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 10),
                        itemCount: otherEntries.length,
                        itemBuilder: (context, index) {
                          return _buildLeaderboardItem(otherEntries[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardFilterButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildLeaderboardFilterButton(
            label: 'All Time',
            icon: Icons.emoji_events,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLeaderboardFilterButton(
            label: 'Weekly',
            icon: Icons.calendar_today,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardFilterButton({
    required String label,
    required IconData icon,
  }) {
    final isSelected = _leaderboardFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _leaderboardFilter = label;
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
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppConstants.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentUserCard(LeaderboardEntry entry) {
    IconData? medalIcon;
    Color? medalGradientStart;
    Color? medalGradientEnd;

    if (entry.rank == 1) {
      medalGradientStart = const Color(0xFFFFD700); // Gold
      medalGradientEnd = const Color(0xFFFFE55C);
      medalIcon = Icons.emoji_events;
    } else if (entry.rank == 2) {
      medalGradientStart = const Color(0xFFC0C0C0); // Silver
      medalGradientEnd = const Color(0xFFE8E8E8);
      medalIcon = Icons.emoji_events;
    } else if (entry.rank == 3) {
      medalGradientStart = const Color(0xFFCD7F32); // Bronze
      medalGradientEnd = const Color(0xFFE89C6C);
      medalIcon = Icons.emoji_events;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryGreen.withOpacity(0.2),
            AppConstants.lightGreen.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.primaryGreen.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryGreen.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppConstants.primaryGreen, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: entry.photoUrl != null && entry.photoUrl!.isNotEmpty
                ? CircleAvatar(
                    radius: 26,
                    backgroundImage: NetworkImage(entry.photoUrl!),
                    backgroundColor: Colors.grey[200],
                  )
                : CircleAvatar(
                    radius: 26,
                    backgroundColor: AppConstants.primaryGreen.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: AppConstants.primaryGreen,
                    ),
                  ),
          ),
          const SizedBox(width: 14),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'You',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.darkGreen,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Rank #${entry.rank}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Level badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.lightGreen.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: AppConstants.darkGreen,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Lv ${entry.level}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppConstants.darkGreen,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Points
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppConstants.primaryGreen,
                            AppConstants.darkGreen,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${entry.points} pts',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Medal icon for top 3
          if (medalIcon != null)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [medalGradientStart!, medalGradientEnd!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: medalGradientStart.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(medalIcon, color: Colors.white, size: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(LeaderboardEntry entry) {
    IconData? medalIcon;
    Color? medalGradientStart;
    Color? medalGradientEnd;

    if (entry.rank == 1) {
      medalGradientStart = const Color(0xFFFFD700); // Gold
      medalGradientEnd = const Color(0xFFFFE55C);
      medalIcon = Icons.emoji_events;
    } else if (entry.rank == 2) {
      medalGradientStart = const Color(0xFFC0C0C0); // Silver
      medalGradientEnd = const Color(0xFFE8E8E8);
      medalIcon = Icons.emoji_events;
    } else if (entry.rank == 3) {
      medalGradientStart = const Color(0xFFCD7F32); // Bronze
      medalGradientEnd = const Color(0xFFE89C6C);
      medalIcon = Icons.emoji_events;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: entry.isCurrentUser
            ? LinearGradient(
                colors: [
                  AppConstants.primaryGreen.withOpacity(0.15),
                  AppConstants.lightGreen.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: entry.isCurrentUser ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isCurrentUser
              ? AppConstants.primaryGreen
              : Colors.grey.shade200,
          width: entry.isCurrentUser ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: entry.isCurrentUser
                ? AppConstants.primaryGreen.withOpacity(0.15)
                : Colors.black.withOpacity(0.06),
            blurRadius: entry.isCurrentUser ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank or medal
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: medalGradientStart != null
                  ? LinearGradient(
                      colors: [medalGradientStart, medalGradientEnd!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: medalGradientStart == null
                  ? AppConstants.lightGreen.withOpacity(0.3)
                  : null,
              shape: BoxShape.circle,
              boxShadow: medalIcon != null
                  ? [
                      BoxShadow(
                        color: medalGradientStart!.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: medalIcon != null
                  ? Icon(medalIcon, color: Colors.white, size: 22)
                  : Text(
                      '#${entry.rank}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryGreen,
                        fontFamily: 'Poppins',
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Profile picture
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: entry.isCurrentUser
                    ? AppConstants.primaryGreen
                    : AppConstants.primaryGreen.withOpacity(0.2),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.primaryGreen.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: entry.photoUrl != null
                  ? Image.network(
                      entry.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppConstants.lightGreen,
                          child: Icon(
                            Icons.person,
                            color: AppConstants.darkGreen,
                            size: 24,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: AppConstants.lightGreen,
                      child: Icon(
                        Icons.person,
                        color: AppConstants.darkGreen,
                        size: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: entry.isCurrentUser
                              ? AppConstants.primaryGreen
                              : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.lightGreen.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 12,
                            color: AppConstants.darkGreen,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Lvl ${entry.level}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.darkGreen,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryGreen.withOpacity(0.2),
                      AppConstants.lightGreen.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${entry.points}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.darkGreen,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Text(
                      'points',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.darkGreen.withOpacity(0.7),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

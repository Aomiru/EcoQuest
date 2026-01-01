import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'screens/camera.dart';
import 'screens/splash_screen.dart';
import 'screens/main_container.dart';
import 'screens/journal_list.dart';
import 'screens/badge.dart';
import 'services/quest_service.dart';
import 'services/badge_popup_manager.dart';
import 'services/background_music_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/supabase_sync_service.dart';
import 'services/connectivity_sync_service.dart';
import 'widgets/quest_panel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;

// App Constants
class AppConstants {
  // Colors
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color secondaryGreen = Color(0xFF66BB6A);
  static const Color darkGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFC8E6C9);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentPink = Color(0xFFE91E63);
  static const Color backgroundBeige = Color(0xFFF5F5DC);
  static const Color backgroundTan = Color(0xFFE8DCC0);

  // Text Styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
  );

  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  // Animation Durations
  static const Duration shortDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 300);
  static const Duration longDuration = Duration(milliseconds: 500);

  // Layout Constants
  static const double borderRadius = 25.0;
  static const double cardMargin = 20.0;
  static const double defaultPadding = 20.0;
}

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.dotenv.load();
  } catch (e) {
    // Continue app initialization even if dotenv fails
  }

  // Initialize Supabase
  try {
    await SupabaseAuthService.initialize();

    // Load user data if already signed in
    if (SupabaseAuthService.isSignedIn) {
      // Check if user has existing data in database and load it
      final hasExistingData = await SupabaseSyncService.hasExistingData();

      if (hasExistingData) {
        await SupabaseSyncService.loadAllDataFromSupabase();
      }
    }
  } catch (e) {
    // Continue app initialization even if Supabase fails
  }

  // Initialize connectivity monitoring for auto-sync
  try {
    await ConnectivitySyncService.initialize();
  } catch (e) {
    // Continue app initialization even if connectivity monitoring fails
  }

  // Initialize background music service
  await BackgroundMusicService.init();
  await BackgroundMusicService.play();

  // Set up error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // In production, you might want to send this to a crash reporting service
  };

  runApp(const EcoQuest());
}

class EcoQuest extends StatelessWidget {
  const EcoQuest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoQuest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 18, 32, 47),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(0, 0, 0, 0),
          elevation: 0,
          iconTheme: IconThemeData(color: AppConstants.primaryGreen),
          titleTextStyle: TextStyle(
            color: AppConstants.darkGreen,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 0, 0, 0),
            foregroundColor: Colors.black,
            elevation: 2,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 8,
          shadowColor: Colors.black26,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const MainContainer(),
        '/camera': (context) => const CameraScreen(),
      },
    );
  }
}

class NatureAdventureScreen extends StatefulWidget {
  const NatureAdventureScreen({super.key});

  @override
  State<NatureAdventureScreen> createState() => _NatureAdventureScreenState();
}

class _NatureAdventureScreenState extends State<NatureAdventureScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  final PageController _verticalPageController = PageController();
  // int _currentVerticalSection = 0;
  late AnimationController _navAnimationController;
  bool _showSectionLabels = true;
  Timer? _labelTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _navAnimationController = AnimationController(
      duration: AppConstants.mediumDuration,
      vsync: this,
    );
    _navAnimationController.forward();
    _startLabelTimer();
    // Check for pending badge unlocks after screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBadgeUnlocks();
    });
  }

  Future<void> _checkBadgeUnlocks() async {
    if (mounted) {
      await BadgePopupManager.checkAndShowPendingBadges(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _verticalPageController.dispose();
    _navAnimationController.dispose();
    _labelTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Pause music when app goes to background
      BackgroundMusicService.pause();
    } else if (state == AppLifecycleState.resumed) {
      // Resume music when app comes back to foreground
      BackgroundMusicService.resume();
    }
  }

  void _startLabelTimer() {
    _labelTimer?.cancel();
    setState(() {
      _showSectionLabels = true;
    });
    _labelTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showSectionLabels = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full screen background image
          Container(
            width: 500,
            height: 350,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          SizedBox(
            height: 500,
            width: double.infinity,
            child: Stack(
              children: [
                // Chameleon mascot image
                Positioned(
                  right: -40,
                  top: 90,
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: Image.asset('assets/cham 1.PNG', fit: BoxFit.fill),
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Stack(
            children: [
              // Header with extended background that overlaps (z-index +1)
              Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),
              // White card container positioned to allow overlap (z-index 0)
              Positioned.fill(
                top: 300, // Leave space for header overlap
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
                  child: PageView(
                    controller: _verticalPageController,
                    scrollDirection: Axis.vertical,
                    onPageChanged: (index) {
                      // setState(() {
                      //   _currentVerticalSection = index;
                      // });
                      _startLabelTimer();
                    },
                    children: [
                      // Section 1: Quest Panel
                      SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: const QuestPanel(),
                            ),
                            const SizedBox(height: 10),
                            // Down arrow indicator
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 32,
                              color: AppConstants.primaryGreen,
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                      // Section 2: Horizontal Cards
                      SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 420,
                              child: _buildHorizontalCards(),
                            ),
                            _buildPageIndicator(),
                            const SizedBox(height: 110),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Vertical Section Indicator
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  opacity: _showSectionLabels ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  // child: _buildVerticalSectionIndicator(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 350, // Make header taller to create overlap
      child: SafeArea(
        child: GestureDetector(
          onLongPress: () async {
            // Debug feature: Clear quest cache to reload from text files
            await QuestService.clearQuestCache();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Quest cache cleared! Quests will reload.',
                  ),
                  backgroundColor: AppConstants.primaryGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
              setState(() {}); // Trigger rebuild
            }
          },
          child: Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              children: [
                // Header text
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Stack(
                              children: [
                                // White shadow layer
                                Text(
                                  'Hi, Explorer',
                                  style: TextStyle(
                                    fontSize: 50,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    height: 0.9,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 6
                                      ..color = Colors.white.withOpacity(0.5),
                                  ),
                                ),
                                // Stroke layer
                                Text(
                                  'Hi, Explorer',
                                  style: TextStyle(
                                    fontSize: 50,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    height: 0.9,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 3
                                      ..color = const Color.fromARGB(
                                        255,
                                        7,
                                        107,
                                        11,
                                      ),
                                  ),
                                ),
                                // Main text layer
                                Text(
                                  'Hi, Explorer',
                                  style: TextStyle(
                                    color: const Color.fromARGB(
                                      255,
                                      255,
                                      255,
                                      255,
                                    ),
                                    fontSize: 50,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    height: 0.9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            label: 'Welcome message for nature adventure',
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Stack(
                                children: [
                                  // White shadow for subtitle
                                  Text(
                                    'Ready for a Nature Adventure?',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontStyle: FontStyle.italic,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                      foreground: Paint()
                                        ..style = PaintingStyle.stroke
                                        ..strokeWidth = 3
                                        ..color = Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                  // Main subtitle text
                                  Text(
                                    'Ready for a Nature Adventure?',
                                    style: TextStyle(
                                      color: const Color.fromARGB(
                                        255,
                                        0,
                                        97,
                                        15,
                                      ),
                                      fontSize: 21,
                                      fontStyle: FontStyle.italic,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCards() {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      children: [_buildExploreCard(), _buildJournalCard(), _buildBadgeCard()],
    );
  }

  Widget _buildExploreCard() {
    return Hero(
      tag: "explore_card",
      child: AnimatedContainer(
        duration: AppConstants.mediumDuration,
        height: 250, // Reduced height to prevent overflow
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppConstants.accentOrange,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 3,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image container
            Positioned(
              left: -55, // Adjust horizontal position
              bottom: -10, // Adjust vertical position
              child: SizedBox(
                width: 310, // Adjust width
                height: 310, // Adjust height
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset('assets/cham 4.PNG', fit: BoxFit.cover),
                ),
              ),
            ),
            // Content overlay
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CameraScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              // White shadow/stroke layer
                              Text(
                                'Explore It!',
                                style: AppConstants.heading2.copyWith(
                                  fontSize: 56,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.36,
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 4
                                    ..color = Colors.white.withOpacity(0.7),
                                ),
                              ),
                              // Main text layer
                              Text(
                                'Explore It!',
                                style: AppConstants.heading2.copyWith(
                                  color: Colors.black,
                                  fontSize: 56,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.36,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 300,
                        height: 60,
                        child: Text(
                          'Use your camera to discover \nplants and animals!',
                          textAlign: TextAlign.right,
                          style: AppConstants.body2.copyWith(
                            color: Colors.black,
                            fontSize: 18,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.16,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Enhanced button area
                      Row(
                        children: [
                          // Spacer for layout balance
                          Expanded(
                            flex: 2,
                            child: Container(), // Empty container for spacing
                          ),

                          // Enhanced button
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Column(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const CameraScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      elevation: 4,
                                      shadowColor: Colors.black26,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        50,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt, size: 48),
                                        SizedBox(width: 8),
                                        Text(
                                          'Open\nCamera',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJournalCard() {
    return Hero(
      tag: "journal_card",
      child: AnimatedContainer(
        duration: AppConstants.mediumDuration,
        height: 250, // Reduced height to prevent overflow
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF49B3FF),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 3,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image container
            Positioned(
              left: 80, // Adjust horizontal position
              bottom: 30, // Adjust vertical position
              child: SizedBox(
                width: 320, // Adjust width
                height: 320, // Adjust height
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset('assets/cham 2.PNG', fit: BoxFit.cover),
                ),
              ),
            ),
            // Content overlay
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JournalListScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              // White shadow/stroke layer
                              Text(
                                'My Nature\nJournal',
                                style: AppConstants.heading2.copyWith(
                                  fontSize: 46,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.36,
                                  height: 1.1,
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 4
                                    ..color = Colors.white.withOpacity(0.7),
                                ),
                              ),

                              // Main text layer
                              Text(
                                'My Nature\nJournal',
                                style: AppConstants.heading2.copyWith(
                                  color: Colors.black,
                                  fontSize: 46,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.36,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: 300,
                        height: 150,
                        child: Text(
                          'View, \nwrite, or \ntalk about \nwhat you \nfound!',
                          textAlign: TextAlign.left,
                          style: AppConstants.body2.copyWith(
                            color: Colors.black,
                            fontSize: 18,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.16,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Enhanced button area
                      Row(
                        children: [
                          // Enhanced button (moved to left)
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Column(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const JournalListScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      elevation: 4,
                                      shadowColor: Colors.black26,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        50,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.menu_book, size: 48),
                                        SizedBox(width: 8),
                                        Text(
                                          'Open\nJournal',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Spacer for layout balance (moved to right)
                          Expanded(
                            flex: 2,
                            child: Container(), // Empty container for spacing
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard() {
    return Hero(
      tag: "badge_card",
      child: AnimatedContainer(
        duration: AppConstants.mediumDuration,
        height: 250, // Reduced height to prevent overflow
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF55AC6),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 3,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image container
            Positioned(
              left: -68, // Adjust horizontal position
              bottom: 0, // Adjust vertical position
              child: SizedBox(
                width: 340, // Adjust width
                height: 340, // Adjust height
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset('assets/cham 3.PNG', fit: BoxFit.cover),
                ),
              ),
            ),
            // Content overlay
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BadgeScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Stack(
                            children: [
                              // White shadow/stroke layer
                              Text(
                                'Earn & Shine!',
                                style: AppConstants.heading2.copyWith(
                                  fontSize: 52,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.36,
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 4
                                    ..color = Colors.white.withOpacity(0.7),
                                ),
                              ),
                              // Main text layer
                              Text(
                                'Earn & Shine!',
                                style: AppConstants.heading2.copyWith(
                                  color: Colors.black,
                                  fontSize: 52,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.36,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(
                        width: 300,
                        height: 100,
                        child: Text(
                          'Collect badges and \ncelebrate your \nadventures!',
                          textAlign: TextAlign.right,
                          style: AppConstants.body2.copyWith(
                            color: Colors.black,
                            fontSize: 18,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.16,
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Enhanced button area
                      Row(
                        children: [
                          // Spacer for layout balance
                          Expanded(
                            flex: 2,
                            child: Container(), // Empty container for spacing
                          ),

                          // Enhanced button
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: Column(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const BadgeScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      elevation: 4,
                                      shadowColor: Colors.black26,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        50,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.emoji_events, size: 52),
                                        SizedBox(width: 6),
                                        Text(
                                          'View\nAwards',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedContainer(
            duration: AppConstants.mediumDuration,
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentIndex == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentIndex == index
                  ? AppConstants.primaryGreen
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
              boxShadow: _currentIndex == index
                  ? [
                      BoxShadow(
                        color: AppConstants.primaryGreen.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  // Widget _buildVerticalSectionIndicator() {
  //   final sectionIcons = [Icons.assignment, Icons.home];
  //   final sectionLabels = ['Quests', 'Home'];

  //   return Container(
  //     padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
  //     decoration: BoxDecoration(
  //       color: Colors.white.withOpacity(0.95),
  //       borderRadius: BorderRadius.circular(20),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.15),
  //           blurRadius: 10,
  //           offset: const Offset(0, 3),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: List.generate(2, (index) {
  //         final isActive = _currentVerticalSection == index;
  //         return AnimatedContainer(
  //           duration: AppConstants.mediumDuration,
  //           margin: const EdgeInsets.symmetric(vertical: 5),
  //           padding: const EdgeInsets.all(10),
  //           decoration: BoxDecoration(
  //             color: isActive ? AppConstants.primaryGreen : Colors.transparent,
  //             borderRadius: BorderRadius.circular(12),
  //             boxShadow: isActive
  //                 ? [
  //                     BoxShadow(
  //                       color: AppConstants.primaryGreen.withOpacity(0.3),
  //                       blurRadius: 6,
  //                       offset: const Offset(0, 2),
  //                     ),
  //                   ]
  //                 : null,
  //           ),
  //           child: Row(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               Icon(
  //                 sectionIcons[index],
  //                 size: 24,
  //                 color: isActive ? Colors.white : Colors.grey.shade400,
  //               ),
  //               Padding(
  //                 padding: const EdgeInsets.only(left: 8),
  //                 child: Text(
  //                   sectionLabels[index],
  //                   style: TextStyle(
  //                     fontSize: 13,
  //                     fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
  //                     color: isActive ? Colors.white : Colors.grey.shade400,
  //                     fontFamily: 'Poppins',
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         );
  //       }),
  //     ),
  //   );
  // }
}

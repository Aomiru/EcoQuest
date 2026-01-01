import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import the constants from main.dart
import '../main.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // FAQ data
  final List<Map<String, dynamic>> _faqData = [
    {
      'category': 'Getting Started',
      'icon': Icons.rocket_launch,
      'color': Colors.blue,
      'questions': [
        {
          'question': 'How do I start using EcoQuest?',
          'answer':
              'Simply open the app and tap the camera button to start exploring nature! Point your camera at plants, animals, or natural objects to learn about them.',
        },
        {
          'question': 'Do I need an internet connection?',
          'answer':
              'An internet connection is recommended for the best experience and most accurate species identification, but basic camera functionality works offline.',
        },
        {
          'question': 'How accurate is the species identification?',
          'answer':
              'Our AI-powered identification system is constantly improving. For best results, take clear, well-lit photos and try different angles if needed.',
        },
      ],
    },
    {
      'category': 'Camera & Photos',
      'icon': Icons.camera_alt,
      'color': Colors.green,
      'questions': [
        {
          'question': 'How do I take the best nature photos?',
          'answer':
              'Hold your phone steady, ensure good lighting, get close to your subject, and try to fill the frame. Avoid shadows and blurry images for best identification results.',
        },
        {
          'question': 'Can I upload photos from my gallery?',
          'answer':
              'Yes! You can upload existing photos from your gallery using the gallery option in the camera screen.',
        },
        {
          'question': 'Where are my photos saved?',
          'answer':
              'Photos are automatically saved to your device gallery if auto-save is enabled in settings. You can also find them in your nature journal.',
        },
      ],
    },
    {
      'category': 'Profile & Settings',
      'icon': Icons.person,
      'color': Colors.purple,
      'questions': [
        {
          'question': 'How do I change my profile picture?',
          'answer':
              'Go to your profile, tap the edit button, then tap on your profile picture. You can choose from preset images or upload from your gallery.',
        },
        {
          'question': 'Can I change my age and gender?',
          'answer':
              'Yes! All profile information can be updated by tapping the edit button on your profile screen.',
        },
        {
          'question': 'How do I enable notifications?',
          'answer':
              'Go to Settings > App Settings > Notifications and toggle the options you want to receive.',
        },
      ],
    },
    {
      'category': 'Wildlife & Nature',
      'icon': Icons.pets,
      'color': Colors.orange,
      'questions': [
        {
          'question': 'What types of wildlife can EcoQuest identify?',
          'answer':
              'EcoQuest can identify a wide variety of flora (plants) and fauna (animals). Our database is constantly expanding!',
        },
        {
          'question': 'How do I learn more about identified species?',
          'answer':
              'After identification, tap on the result to see detailed information including habitat, behavior, conservation status, and fun facts.',
        },
        {
          'question': 'Can I report rare species sightings?',
          'answer':
              'Yes! Rare species sightings are automatically flagged and can contribute to conservation efforts and scientific research.',
        },
      ],
    },
    {
      'category': 'Troubleshooting',
      'icon': Icons.build,
      'color': Colors.red,
      'questions': [
        {
          'question': 'The app is running slowly, what should I do?',
          'answer':
              'Try closing other apps, ensure you have enough storage space, and restart the app. If problems persist, restart your device.',
        },
        {
          'question': 'Species identification is not working properly',
          'answer':
              'Ensure you have a stable internet connection, take clear well-lit photos, and try different angles. Update the app if a new version is available.',
        },
        {
          'question': 'How do I report a bug or issue?',
          'answer':
              'Use the "Contact Support" option below to report bugs or issues. Include as much detail as possible about what happened.',
        },
      ],
    },
  ];

  int _selectedCategoryIndex = 0;
  List<bool> _expandedStates = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppConstants.mediumDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Initialize expanded states
    _expandedStates = List.generate(
      _faqData[_selectedCategoryIndex]['questions'].length,
      (index) => false,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      _expandedStates = List.generate(
        _faqData[_selectedCategoryIndex]['questions'].length,
        (index) => false,
      );
    });
  }

  void _toggleExpanded(int index) {
    setState(() {
      _expandedStates[index] = !_expandedStates[index];
    });
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.email, color: AppConstants.primaryGreen, size: 32),
              const SizedBox(width: 12),
              const Text(
                'Contact Support',
                style: TextStyle(color: AppConstants.primaryGreen),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get in touch with our support team:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 15),
              Row(
                children: [
                  Icon(Icons.email, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('support@ecoquest.com'),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.phone, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('+1 (555) 123-4567'),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('Mon-Fri, 9AM-5PM EST'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Beautiful gradient header background
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.primaryGreen,
                  AppConstants.darkGreen,
                  const Color.fromARGB(255, 34, 139, 34),
                ],
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Content
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            // Category tabs
                            _buildCategoryTabs(),
                            const SizedBox(height: 20),
                            // FAQ content
                            Expanded(child: _buildFAQContent()),
                            // Contact support button
                            _buildContactButton(),
                            const SizedBox(height: 20),
                          ],
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
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          // Back button
          Container(
            // decoration: BoxDecoration(
            //   color: Colors.black.withOpacity(0.3),
            //   borderRadius: BorderRadius.circular(50),
            // ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),

          // Title
          Expanded(
            child: Center(
              child: Stack(
                children: [
                  // White shadow layer
                  Text(
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 38,
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
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 38,
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
                    'Help & Support',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
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

          // Invisible spacer for balance
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: _faqData.length,
        itemBuilder: (context, index) {
          final category = _faqData[index];
          final isSelected = index == _selectedCategoryIndex;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _selectCategory(index);
            },
            child: AnimatedContainer(
              duration: AppConstants.shortDuration,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(16),
              width: 100,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          category['color'].withOpacity(0.8),
                          category['color'].withOpacity(0.6),
                        ],
                      )
                    : null,
                color: isSelected ? null : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? category['color'] : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: category['color'].withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    category['icon'],
                    color: isSelected ? Colors.white : category['color'],
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category['category'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFAQContent() {
    final questions = _faqData[_selectedCategoryIndex]['questions'] as List;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        final isExpanded = _expandedStates[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _faqData[_selectedCategoryIndex]['color'].withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _toggleExpanded(index);
                },
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _faqData[_selectedCategoryIndex]['color']
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.help_outline,
                    color: _faqData[_selectedCategoryIndex]['color'],
                    size: 20,
                  ),
                ),
                title: Text(
                  question['question'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    fontFamily: 'Poppins',
                  ),
                ),
                trailing: AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: AppConstants.shortDuration,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: _faqData[_selectedCategoryIndex]['color'],
                  ),
                ),
              ),
              AnimatedContainer(
                duration: AppConstants.shortDuration,
                height: isExpanded ? null : 0,
                child: isExpanded
                    ? Container(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Text(
                          question['answer'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.5,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _showContactDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contact_support, size: 24),
            SizedBox(width: 12),
            Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

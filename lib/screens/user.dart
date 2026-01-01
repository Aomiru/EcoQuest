import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';

// Import the constants from main.dart
import '../main.dart';
import 'setting.dart';
import '../services/progress_service.dart';
import '../services/badge_popup_manager.dart';
import '../services/user_profile_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_sync_service.dart';
import '../models/user_progress.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  // User profile data loaded from txt file
  Map<String, dynamic> _userProfile = {};
  bool _isLoading = true;
  StreamSubscription? _authSubscription;

  // Available profile images
  final List<String> _profileImages = [
    'assets/profile1.jpg',
    'assets/profile2.jpg',
    'assets/profile3.jpg',
    'assets/profile4.jpg',
  ];

  // Custom profile image from gallery
  File? _customProfileImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Check for pending badge unlocks after screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBadgeUnlocks();
    });

    // Listen to auth state changes
    _authSubscription = SupabaseAuthService.authStateChanges.listen((data) async {
      if (mounted) {
        // Reload profile when auth state changes
        await _loadUserProfile();
        setState(() {});
      }
    });
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfileService.getUserProfile();
    final customPath = await UserProfileService.getCustomImagePath();

    setState(() {
      _userProfile = profile;
      if (customPath != null && customPath.isNotEmpty) {
        _customProfileImage = File(customPath);
      }
      _isLoading = false;
    });
  }

  Future<void> _loadUserProfile() async {
    final profile = await UserProfileService.getUserProfile();
    final customPath = await UserProfileService.getCustomImagePath();

    if (mounted) {
      setState(() {
        _userProfile = profile;
        if (customPath != null && customPath.isNotEmpty) {
          _customProfileImage = File(customPath);
        }
      });
    }
  }

  Future<void> _checkBadgeUnlocks() async {
    if (mounted) {
      await BadgePopupManager.checkAndShowPendingBadges(context);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // Image picker methods
  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _customProfileImage = File(image.path);
          _userProfile['profileImage'] = 'custom'; // Mark as custom image
        });

        // Save to UserProfileService
        await UserProfileService.saveCustomImagePath(image.path);
        await UserProfileService.saveUserProfile(_userProfile);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Profile picture updated from gallery!'),
              ],
            ),
            backgroundColor: AppConstants.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Failed to pick image from gallery'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.photo, color: AppConstants.primaryGreen, size: 32),
              const SizedBox(width: 12),
              const Text(
                'Choose Profile Picture',
                style: TextStyle(
                  color: AppConstants.primaryGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gallery Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: AppConstants.darkGreen,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Upload from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Select from your photo library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),

              const SizedBox(height: 10),

              // Predefined Options
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.apps,
                    color: AppConstants.darkGreen,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Choose from Presets',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Select from available profile images'),
                onTap: () {
                  Navigator.pop(context);
                  _showPresetSelectionDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPresetSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.apps, color: AppConstants.primaryGreen, size: 32),
              const SizedBox(width: 12),
              const Text(
                'Select Profile Picture',
                style: TextStyle(
                  color: AppConstants.primaryGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.0,
              ),
              itemCount: _profileImages.length,
              itemBuilder: (context, index) {
                String imagePath = _profileImages[index];
                bool isSelected = _userProfile['profileImage'] == imagePath;

                return GestureDetector(
                  onTap: () async {
                    setState(() {
                      _userProfile['profileImage'] = imagePath;
                      _customProfileImage = null; // Clear custom image
                    });

                    // Save to UserProfileService
                    await UserProfileService.saveCustomImagePath('');
                    await UserProfileService.saveUserProfile(_userProfile);

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Profile picture updated to ${imagePath.split('/').last.split('.').first}!',
                            ),
                          ],
                        ),
                        backgroundColor: AppConstants.primaryGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppConstants.primaryGreen
                            : Colors.grey.shade300,
                        width: isSelected ? 4 : 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppConstants.primaryGreen.withOpacity(
                                  0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppConstants.lightGreen,
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: AppConstants.darkGreen,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
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
          ],
        );
      },
    );
  }

  void _showEditProfileDialog() {
    // Create temporary variables for editing
    String tempName = _userProfile['name'];
    String tempAge = _userProfile['age'];
    String tempGender = _userProfile['gender'];
    String tempHobby = _userProfile['hobby'];
    String tempFavoriteAnimal = _userProfile['favoriteAnimal'];
    String tempProfileImage = _userProfile['profileImage'];

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxHeight: 600),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(
                            Icons.edit,
                            color: AppConstants.primaryGreen,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: AppConstants.primaryGreen,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Profile Image Selection
                      Column(
                        children: [
                          const Text(
                            'Profile Picture',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppConstants.primaryGreen,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: _buildCurrentProfileImage(
                                  tempProfileImage,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Quick action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Gallery button
                              _buildImageSourceButton(
                                icon: Icons.photo_library,
                                label: 'Upload Gallery',
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImageFromGallery();
                                },
                              ),
                              // Preset button
                              _buildImageSourceButton(
                                icon: Icons.apps,
                                label: 'Choose Preset',
                                onTap: () {
                                  Navigator.pop(context);
                                  _showPresetSelectionDialog();
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),
                        ],
                      ),

                      // Name Field
                      TextField(
                        controller: TextEditingController(text: tempName),
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppConstants.primaryGreen,
                            ),
                          ),
                        ),
                        onChanged: (value) => tempName = value,
                      ),
                      const SizedBox(height: 15),

                      // Age and Gender Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: tempAge),
                              decoration: InputDecoration(
                                labelText: 'Age',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: AppConstants.primaryGreen,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => tempAge = value,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: tempGender,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: AppConstants.primaryGreen,
                                  ),
                                ),
                              ),
                              items: ['Male', 'Female', 'Other'].map((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  tempGender = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Hobby Field
                      TextField(
                        controller: TextEditingController(text: tempHobby),
                        decoration: InputDecoration(
                          labelText: 'Hobby',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppConstants.primaryGreen,
                            ),
                          ),
                        ),
                        onChanged: (value) => tempHobby = value,
                      ),
                      const SizedBox(height: 15),

                      // Favorite Animal Field
                      TextField(
                        controller: TextEditingController(
                          text: tempFavoriteAnimal,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Favorite Animal',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: AppConstants.primaryGreen,
                            ),
                          ),
                        ),
                        onChanged: (value) => tempFavoriteAnimal = value,
                      ),
                      const SizedBox(height: 25),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.grey.shade400),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Save changes
                                setState(() {
                                  _userProfile['name'] = tempName;
                                  _userProfile['age'] = tempAge;
                                  _userProfile['gender'] = tempGender;
                                  _userProfile['hobby'] = tempHobby;
                                  _userProfile['favoriteAnimal'] =
                                      tempFavoriteAnimal;
                                  _userProfile['profileImage'] =
                                      tempProfileImage;
                                  // Custom image is already set in _customProfileImage
                                });

                                // Save to UserProfileService
                                await UserProfileService.saveUserProfile(
                                  _userProfile,
                                );

                                Navigator.of(context).pop();

                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Profile updated successfully!',
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppConstants.primaryGreen,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToSettings() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image - same as main screen but showing middle portion
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

          // Gradient overlay to ensure text readability
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

          // Main Content with overlapping structure like main.dart
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
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppConstants.primaryGreen,
                          ),
                        )
                      : Column(
                          children: [
                            // Profile content
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(25),
                                child: Column(children: [_buildProfileCard()]),
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
                        'My Profile',
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
                        'My Profile',
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
                        'My Profile',
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

              // Settings button with low opacity background
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _navigateToSettings,
                  icon: const Icon(
                    Icons.settings,
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

  Widget _buildProfileCard() {
    return Hero(
      tag: "profile_card",
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF66BB6A),
              const Color(0xFF66BB6A),
              const Color.fromARGB(255, 84, 221, 169),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background chameleon image
            Positioned(
              right: -100,
              top: -20,
              child: Opacity(
                opacity: 0.15,
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: Image.asset('assets/cham 1.PNG', fit: BoxFit.contain),
                ),
              ),
            ),

            // Edit button in top-right corner
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                child: IconButton(
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.edit, color: Colors.white, size: 24),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Picture and Name Column (centered)
                  Column(
                    children: [
                      // Profile Picture with fun decorations
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Main profile picture
                          Container(
                            width: 140,
                            height: 140,
                            padding: const EdgeInsets.all(5),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _userProfile['gender'] == 'Male'
                                      ? Colors.blue
                                      : _userProfile['gender'] == 'Female'
                                      ? Colors.pinkAccent
                                      : Colors.white,
                                  width: 4,
                                ),
                              ),
                              child: ClipOval(
                                child: _buildCurrentProfileImage(
                                  _userProfile['profileImage'],
                                ),
                              ),
                            ),
                          ),
                          // Fun sparkle decorations
                          Positioned(
                            top: -5,
                            right: 5,
                            child: Text('✨', style: TextStyle(fontSize: 28)),
                          ),
                          Positioned(
                            top: 10,
                            left: -5,
                            child: Text('🌟', style: TextStyle(fontSize: 24)),
                          ),
                          Positioned(
                            bottom: 0,
                            right: -5,
                            child: Text('⭐', style: TextStyle(fontSize: 20)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Name with fun emojis
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('👋', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _userProfile['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Poppins',
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                      color: Colors.black26,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // EXP & Level Section - Improved Design
                  FutureBuilder<UserProgress>(
                    future: ProgressService.getUserProgress(),
                    builder: (context, snapshot) {
                      final progress =
                          snapshot.data ?? const UserProgress(exp: 0);
                      final cap = progress.expForCurrentLevelCap;
                      final pct = cap == 0 ? 0.0 : progress.expIntoLevel / cap;
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color.fromARGB(255, 90, 128, 233),
                              const Color.fromARGB(255, 145, 136, 194),
                              const Color.fromARGB(255, 173, 143, 244),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Level icon with gradient
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.orange.withOpacity(0.8),
                                        Colors.deepOrange.withOpacity(0.6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '🏆',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Level ${progress.level}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 20,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // EXP badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    '${progress.expIntoLevel} / $cap XP',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Clean progress bar
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Progress to Level ${progress.level + 1}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${(pct * 100).round()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: pct.clamp(0.0, 1.0),
                                      backgroundColor: Colors.transparent,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Color(0xFF8BC34A),
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 15),

                  // Age and Gender Row
                  Row(
                    children: [
                      // Age Badge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🎂', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Text(
                                '${_userProfile['age']} years old',
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
                      ),

                      const SizedBox(width: 12),

                      // Gender Badge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _userProfile['gender'] == 'Male'
                                    ? '👦'
                                    : _userProfile['gender'] == 'Female'
                                    ? '👧'
                                    : '😊',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _userProfile['gender'],
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
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Hobby Section - Colorful Design
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.pink.withOpacity(0.35),
                          Colors.purple.withOpacity(0.25),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.pink.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.pinkAccent.withOpacity(0.6),
                                Colors.pinkAccent.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withOpacity(0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Hobby:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _userProfile['hobby'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Favorite Animal Section - Colorful Design
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.teal.withOpacity(0.35),
                          Colors.cyan.withOpacity(0.25),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.teal.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.tealAccent.withOpacity(0.6),
                                Colors.tealAccent.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.pets,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Favorite Animal:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _userProfile['favoriteAnimal'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Google Sign-In / Cloud Backup Section
                  _buildGoogleSignInSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Google Sign-In Section
  Widget _buildGoogleSignInSection() {
    final isSignedIn = SupabaseAuthService.isSignedIn;
    final userEmail = SupabaseAuthService.userEmail;
    final userName = SupabaseAuthService.userDisplayName;
    final userPhotoUrl = SupabaseAuthService.userPhotoUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.35),
            Colors.indigo.withOpacity(0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Image.asset('assets/google.png', width: 22, height: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Google Sign In',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isSignedIn) ...[
            // Signed in state - Google profile picture, user info and logout button
            Row(
              children: [
                // Google profile picture
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: userPhotoUrl != null
                        ? Image.network(
                            userPhotoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.white,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.blue,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.white,
                            child: const Icon(Icons.person, color: Colors.blue),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (userName != null)
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (userEmail != null)
                        Text(
                          userEmail,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await SupabaseAuthService.signOut();
                      if (mounted) {
                        setState(() {});
                        
                        // Update local profile to reflect disconnection
                        _userProfile['isConnectedToGoogle'] = false;
                        await UserProfileService.saveUserProfile(_userProfile);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.logout, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Signed out - Your local data is safe'),
                              ],
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sign out failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Not signed in state - simple button
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        final response =
                            await SupabaseAuthService.signInWithGoogle();

                        if (response != null && response.user != null) {
                          // Check if user has existing data in database
                          final hasExistingData = await SupabaseSyncService.hasExistingData();

                          if (hasExistingData) {
                            // User has logged in before - load their data from database
                            await SupabaseSyncService.loadAllDataFromSupabase();
                            
                            // Then sync any new local data to database
                            await SupabaseSyncService.syncAllDataToSupabase();
                          } else {
                            // New user - upload local data to database
                            await SupabaseSyncService.syncAllDataToSupabase();
                          }

                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(hasExistingData 
                                        ? 'Welcome back! Data restored successfully!' 
                                        : 'Successfully signed in!'),
                                  ],
                                ),
                                backgroundColor: AppConstants.primaryGreen,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );

                            // Reload user profile to reflect changes
                            await _loadUserProfile();
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.error, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Sign in failed: $e')),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      }
                    },
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF3C4043),
                        ),
                      ),
                    )
                  : const Icon(Icons.login, size: 18),
              label: Text(_isLoading ? 'Signing in...' : 'Sign in with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF3C4043),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to build current profile image
  Widget _buildCurrentProfileImage(String imagePath) {
    // Check if user is signed in with Google and has a photo URL
    final googlePhotoUrl = SupabaseAuthService.userPhotoUrl;
    final hasCustomImage = imagePath == 'custom' && _customProfileImage != null;

    // Priority: Custom image > Google photo > Asset image
    if (hasCustomImage) {
      return Image.file(
        _customProfileImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppConstants.lightGreen,
            child: Icon(Icons.person, size: 40, color: AppConstants.darkGreen),
          );
        },
      );
    } else if (googlePhotoUrl != null && imagePath == 'google') {
      // Use Google profile picture
      return Image.network(
        googlePhotoUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppConstants.lightGreen,
            child: Icon(Icons.person, size: 40, color: AppConstants.darkGreen),
          );
        },
      );
    } else if (imagePath.startsWith('assets/')) {
      // Use asset image
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppConstants.lightGreen,
            child: Icon(Icons.person, size: 40, color: AppConstants.darkGreen),
          );
        },
      );
    } else {
      // Fallback icon
      return Container(
        color: AppConstants.lightGreen,
        child: Icon(Icons.person, size: 40, color: AppConstants.darkGreen),
      );
    }
  }

  // Helper method to build image source buttons
  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: AppConstants.lightGreen,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppConstants.primaryGreen.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppConstants.darkGreen, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppConstants.darkGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

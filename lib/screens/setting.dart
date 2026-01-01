import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import the constants from main.dart
import '../main.dart';
import '../services/background_music_service.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Settings state
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoSaveEnabled = true;
  bool _locationEnabled = true;
  bool _musicEnabled = true;
  String _selectedLanguage = 'English';

  final List<String> _availableLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
  ];

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

    _loadSettings();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
        _autoSaveEnabled = prefs.getBool('auto_save_enabled') ?? true;
        _locationEnabled = prefs.getBool('location_enabled') ?? true;
        _musicEnabled = BackgroundMusicService.isMusicEnabled;
        _selectedLanguage = prefs.getString('selected_language') ?? 'English';
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
      await prefs.setBool('auto_save_enabled', _autoSaveEnabled);
      await prefs.setBool('location_enabled', _locationEnabled);
      await BackgroundMusicService.setMusicEnabled(_musicEnabled);
      await prefs.setString('selected_language', _selectedLanguage);

      _showSuccessMessage('Settings saved successfully!');
    } catch (e) {
      _showErrorMessage('Failed to save settings. Please try again.');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppConstants.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 32),
              const SizedBox(width: 12),
              const Text(
                'Reset Settings',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to reset all settings to default values? This action cannot be undone.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performReset();
              },
              child: const Text(
                'Reset',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performReset() {
    setState(() {
      _notificationsEnabled = true;
      _darkModeEnabled = false;
      _autoSaveEnabled = true;
      _locationEnabled = true;
      _selectedLanguage = 'English';
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Beautiful gradient header background
          Container(
            height: 200, // Cover the header area
            width: double.infinity,
            decoration: BoxDecoration(color: AppConstants.primaryGreen),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Settings Content
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
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              _buildNotificationSettings(),
                              const SizedBox(height: 30),
                              _buildAudioSettings(),
                              const SizedBox(height: 30),
                              _buildAppSettings(),
                              const SizedBox(height: 30),
                              _buildLanguageSettings(),
                              const SizedBox(height: 40),
                              _buildActionButtons(),
                              const SizedBox(
                                height: 30,
                              ), // Space for navigation
                            ],
                          ),
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
                    'Settings',
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
                    'Settings',
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
                    'Settings',
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

          // Invisible spacer with same width as back button to balance layout
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return _buildSettingsSection(
      title: 'Notifications',
      icon: Icons.notifications,
      children: [
        _buildSwitchTile(
          title: 'Push Notifications',
          subtitle: 'Receive app notifications',
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildAudioSettings() {
    return _buildSettingsSection(
      title: 'Audio & Sound',
      icon: Icons.volume_up,
      children: [
        _buildSwitchTile(
          title: 'Background Music',
          subtitle: 'Play background music',
          value: _musicEnabled,
          onChanged: (value) async {
            setState(() {
              _musicEnabled = value;
            });
            await BackgroundMusicService.setMusicEnabled(value);
          },
        ),
      ],
    );
  }

  Widget _buildAppSettings() {
    return _buildSettingsSection(
      title: 'App Preferences',
      icon: Icons.settings_applications,
      children: [
        _buildSwitchTile(
          title: 'Dark Mode',
          subtitle: 'Use dark theme (Coming Soon)',
          value: _darkModeEnabled,
          onChanged: (value) {
            setState(() {
              _darkModeEnabled = value;
            });
          },
        ),
        _buildSwitchTile(
          title: 'Auto Save',
          subtitle: 'Automatically save captured photos',
          value: _autoSaveEnabled,
          onChanged: (value) {
            setState(() {
              _autoSaveEnabled = value;
            });
          },
        ),
        _buildSwitchTile(
          title: 'Location Services',
          subtitle: 'Use location for wildlife identification',
          value: _locationEnabled,
          onChanged: (value) {
            setState(() {
              _locationEnabled = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildLanguageSettings() {
    return _buildSettingsSection(
      title: 'Language & Region',
      icon: Icons.language,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Language',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                items: _availableLanguages.map((String language) {
                  return DropdownMenuItem<String>(
                    value: language,
                    child: Text(language),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedLanguage = newValue;
                    });
                  }
                },
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
                dropdownColor: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Reset Settings Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _resetSettings,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh, size: 24),
                SizedBox(width: 12),
                Text(
                  'Reset to Default',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.lightGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppConstants.darkGreen, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppConstants.darkGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (newValue) {
              HapticFeedback.lightImpact();
              onChanged(newValue);
            },
            activeColor: AppConstants.primaryGreen,
            activeTrackColor: AppConstants.primaryGreen.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

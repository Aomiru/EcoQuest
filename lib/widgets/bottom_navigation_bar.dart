import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import the constants and screens
import '../main.dart';
import '../screens/camera.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  void _handleNavigation(BuildContext context, int index) {
    HapticFeedback.lightImpact();

    // Only navigate away for camera
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );
    } else {
      // For other tabs, just update the selected index
      onItemTapped(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5DC),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 3,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildNavItem(Icons.home, 'Home', 0, context),
          _buildNavItem(Icons.menu_book, 'Journal', 1, context),
          Transform.translate(
            offset: const Offset(0, -3), // Move it up by 3 pixels
            child: _buildCameraNavItem(context),
          ),
          _buildNavItem(Icons.emoji_events, 'Award', 3, context),
          _buildNavItem(Icons.person, 'User', 4, context),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    BuildContext context,
  ) {
    bool isActive = selectedIndex == index;
    return Semantics(
      button: true,
      enabled: true,
      label: '$label navigation button',
      hint: isActive ? 'Currently selected' : 'Tap to navigate to $label',
      child: GestureDetector(
        onTap: () => _handleNavigation(context, index),
        child: AnimatedContainer(
          duration: AppConstants.shortDuration,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppConstants.primaryGreen.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppConstants.shortDuration,
                transform: Matrix4.identity()..scale(isActive ? 1.1 : 1.0),
                child: Icon(
                  icon,
                  color: isActive
                      ? AppConstants.primaryGreen
                      : const Color(0xFF757575),
                  size: 34,
                  semanticLabel: label,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedDefaultTextStyle(
                duration: AppConstants.shortDuration,
                style: TextStyle(
                  color: isActive
                      ? AppConstants.primaryGreen
                      : const Color(0xFF757575),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraNavItem(BuildContext context) {
    bool isActive = selectedIndex == 2;
    return Semantics(
      button: true,
      enabled: true,
      label: 'Camera navigation button',
      hint: 'Tap to open camera and explore nature - Main feature',
      child: GestureDetector(
        onTap: () => _handleNavigation(context, 2),
        child: AnimatedContainer(
          duration: AppConstants.shortDuration,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Camera icon in green circle (main feature styling)
              AnimatedContainer(
                duration: AppConstants.shortDuration,
                width: isActive ? 60 : 52,
                height: isActive ? 60 : 52,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppConstants.primaryGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppConstants.primaryGreen.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 32,
                  semanticLabel: 'Camera',
                ),
              ),
              // No label text for camera (main feature doesn't need label)
            ],
          ),
        ),
      ),
    );
  }
}

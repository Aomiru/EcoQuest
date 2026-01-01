import 'package:flutter/material.dart';
import '../main.dart';
import '../models/badge.dart' as badge_model;

class BadgeUnlockPopup extends StatelessWidget {
  final badge_model.Badge badge;
  final VoidCallback? onClose;

  const BadgeUnlockPopup({super.key, required this.badge, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badge.isUnlocked ? const Color(0xFFFFD700) : Colors.grey,
            width: 6,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppConstants.lightGreen.withOpacity(0.95),
              Colors.white,
              AppConstants.lightGreen.withOpacity(0.9),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppConstants.primaryGreen.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Congratulations header for unlocked badges
                  if (badge.isUnlocked) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFD700), // Gold
                            Color(0xFFFFD700), // Gold
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 8),
                          Text(
                            'CONGRATULATION!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 0.5,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(width: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Locked badge header
                  if (!badge.isUnlocked) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey.shade400,
                            Colors.grey.shade500,
                            Colors.grey.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'LOCKED BADGE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 0.5,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(width: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Unlock status with celebration message
                  if (badge.isUnlocked) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryGreen,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '⭐ You earned this Badge! ⭐',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    // Message for locked badges
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '🔒 Complete to unlock',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Badge image with animation and sparkle effect for unlocked
                  Stack(
                      alignment: Alignment.center,
                      children: [
                        // Main badge container
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: badge.isUnlocked
                                ? Colors.white
                                : Colors.grey[200],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: badge.isUnlocked
                                  ? const Color(0xFFFFD700)
                                  : Colors.grey[400]!,
                              width: badge.isUnlocked ? 4 : 2,
                            ),
                          ),
                          child: Image.asset(
                            badge.isUnlocked ? badge.colorImage : badge.bwImage,
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.emoji_events,
                                size: 120,
                                color: badge.isUnlocked
                                    ? Colors.amber
                                    : Colors.grey[400],
                              );
                            },
                          ),
                        ),
                        // Star decorations for unlocked badges
                        if (badge.isUnlocked) ...[
                          Positioned(
                            top: 0,
                            right: 10,
                            child: Icon(
                              Icons.star,
                              color: const Color(0xFFFFD700),
                              size: 30,
                            ),
                          ),
                          Positioned(
                            top: 20,
                            left: 5,
                            child: Icon(
                              Icons.star,
                              color: const Color(0xFFFFA500),
                              size: 24,
                            ),
                          ),
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Icon(
                              Icons.star,
                              color: const Color(0xFFFFD700),
                              size: 20,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Badge name with extra emphasis for unlocked
                    Text(
                      badge.name,
                      style: TextStyle(
                        fontSize: badge.isUnlocked ? 24 : 22,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.darkGreen,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // Badge description
                    Text(
                      badge.description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Requirement
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.backgroundBeige,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppConstants.primaryGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.task_alt,
                                size: 18,
                                color: AppConstants.darkGreen,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Requirement:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.darkGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            badge.requirement,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // XP Reward display
                    const SizedBox(height: 12),
                    Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: !badge.isUnlocked
                            ? [Colors.grey.shade300, Colors.grey.shade200]
                            : [Colors.amber.shade100, Colors.amber.shade50],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !badge.isUnlocked ? Colors.grey.shade500 : Colors.amber.shade300,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: !badge.isUnlocked ? Colors.grey.shade600 : Colors.amber.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reward: ${badge.expReward} XP',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: !badge.isUnlocked ? Colors.grey.shade700 : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              // Close button at top right corner
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onClose != null) onClose!();
                  },
                  icon: const Icon(Icons.close),
                  color: AppConstants.darkGreen,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// Static method to show the popup
  static Future<void> show(
    BuildContext context,
    badge_model.Badge badge,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BadgeUnlockPopup(badge: badge),
    );
  }
}

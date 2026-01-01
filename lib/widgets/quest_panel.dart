import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/quest.dart';
import '../services/quest_service.dart';
import '../services/progress_service.dart';
import '../services/point_service.dart';
import '../services/user_profile_service.dart';
import '../services/quest_tracking_service.dart';
import '../services/supabase_auth_service.dart';
import '../models/user_progress.dart';

class QuestPanel extends StatefulWidget {
  const QuestPanel({super.key});

  @override
  State<QuestPanel> createState() => _QuestPanelState();
}

class _QuestPanelState extends State<QuestPanel> with WidgetsBindingObserver {
  late Future<List<Quest>> _dailyFuture;
  late Future<List<Quest>> _weeklyFuture;
  late Future<UserProgress> _progressFuture;
  Timer? _timer;
  Duration _dailyTimeLeft = Duration.zero;
  Duration _weeklyTimeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshData();
    _updateTimers();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _updateTimers();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh quest data when app resumes
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _refreshData();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimers() {
    setState(() {
      _dailyTimeLeft = QuestService.getTimeUntilDailyReset();
      _weeklyTimeLeft = QuestService.getTimeUntilWeeklyReset();
    });
  }

  void _refreshData() {
    _dailyFuture = QuestService.getDailyQuests();
    _weeklyFuture = QuestService.getWeeklyQuests();
    _progressFuture = ProgressService.getUserProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<UserProgress>(
          future: _progressFuture,
          builder: (context, snapshot) {
            final progress = snapshot.data ?? const UserProgress(exp: 0);
            return _buildUserPanel(progress.level);
          },
        ),
        const SizedBox(height: 12),
        _buildSectionTitle(
          'Daily Quest',
          QuestService.formatDuration(_dailyTimeLeft),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Quest>>(
          future: _dailyFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return Column(
              children: snapshot.data!.map((q) => _buildQuestTile(q)).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildSectionTitle(
          'Weekly Quest',
          QuestService.formatDuration(_weeklyTimeLeft),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Quest>>(
          future: _weeklyFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return Column(
              children: snapshot.data!.map((q) => _buildQuestTile(q)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String timeRemaining) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryGreen,
                      AppConstants.secondaryGreen,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  title.contains('Daily')
                      ? Icons.wb_sunny
                      : Icons.calendar_today,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppConstants.darkGreen,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.accentOrange.withOpacity(0.3),
                  AppConstants.accentOrange.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppConstants.accentOrange.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: AppConstants.accentOrange,
                ),
                const SizedBox(width: 4),
                Text(
                  timeRemaining,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppConstants.accentOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestTile(Quest quest) {
    final bool isDaily = quest.questType == QuestType.daily;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: quest.isCompleted
              ? [
                  AppConstants.primaryGreen.withOpacity(0.15),
                  AppConstants.secondaryGreen.withOpacity(0.1),
                ]
              : [
                  Colors.white,
                  isDaily
                      ? AppConstants.lightGreen.withOpacity(0.3)
                      : const Color(0xFFEBE0FF).withOpacity(0.3),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: quest.isCompleted
              ? AppConstants.primaryGreen.withOpacity(0.4)
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: quest.isCompleted
                ? AppConstants.primaryGreen.withOpacity(0.1)
                : Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Quest icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDaily
                      ? [
                          AppConstants.accentOrange,
                          AppConstants.accentOrange.withOpacity(0.7),
                        ]
                      : [
                          AppConstants.accentPink,
                          AppConstants.accentPink.withOpacity(0.7),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDaily
                                ? AppConstants.accentOrange
                                : AppConstants.accentPink)
                            .withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isDaily ? Icons.wb_sunny : Icons.event_available,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Quest details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.description,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      color: quest.isCompleted
                          ? AppConstants.darkGreen
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        size: 16,
                        color: AppConstants.accentOrange.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${quest.expReward} EXP',
                        style: TextStyle(
                          color: AppConstants.accentOrange.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: Colors.purple.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+${quest.pointReward} pts',
                        style: TextStyle(
                          color: Colors.purple.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Show progress for multi-step quests or completion badge
                      FutureBuilder<String>(
                        future: QuestTrackingService.getQuestProgressDisplay(
                          quest.id,
                        ),
                        builder: (context, snapshot) {
                          final progress = snapshot.data ?? '';

                          // Show completion badge when quest is completed
                          if (quest.isCompleted) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryGreen.withOpacity(
                                  0.2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppConstants.primaryGreen.withOpacity(
                                    0.4,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: AppConstants.darkGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Complete',
                                    style: TextStyle(
                                      color: AppConstants.darkGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Show progress badge for multi-step quests
                          if (progress.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDaily
                                  ? AppConstants.lightGreen.withOpacity(0.5)
                                  : const Color(0xFFEBE0FF).withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              progress,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPanel(int level) {
    return FutureBuilder<Map<String, dynamic>>(
      future: UserProfileService.getUserProfile(),
      builder: (context, profileSnapshot) {
        final profile =
            profileSnapshot.data ??
            {'name': 'Explorer', 'profileImage': 'assets/profile1.jpg'};
        final userName = profile['name'] as String;
        final profileImage = profile['profileImage'] as String;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: profileSnapshot.data?['gender'] == 'Male'
                  ? Colors.blue.withOpacity(0.3)
                  : profileSnapshot.data?['gender'] == 'Female'
                  ? Colors.pink.withOpacity(0.3)
                  : AppConstants.primaryGreen.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Picture
              FutureBuilder<String?>(
                future: UserProfileService.getCustomImagePath(),
                builder: (context, customPathSnapshot) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: profile['gender'] == 'Male'
                            ? Colors.blue
                            : profile['gender'] == 'Female'
                            ? Colors.pink
                            : AppConstants.primaryGreen,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _buildProfileImage(
                        profileImage,
                        customPathSnapshot.data,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Eco Explorer',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Level Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppConstants.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppConstants.accentOrange,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      color: AppConstants.accentOrange,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$level',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        color: AppConstants.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Points Badge with Info
              FutureBuilder<int>(
                future: PointService.getPoints(),
                builder: (context, pointSnapshot) {
                  final points = pointSnapshot.data ?? 0;
                  return GestureDetector(
                    onTap: () {
                      final weeklyTimeLeft =
                          QuestService.getTimeUntilWeeklyReset();
                      final resetTime = QuestService.formatDuration(
                        weeklyTimeLeft,
                      );

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Row(
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: AppConstants.primaryGreen,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Weekly Points',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Points: $points',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.primaryGreen,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'What are Weekly Points?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Weekly points are earned by completing quests and reset every week. Compete with others for the highest score!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppConstants.lightGreen.withOpacity(
                                    0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppConstants.primaryGreen
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      color: AppConstants.accentOrange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Resets in: $resetTime',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.accentOrange,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Tip: Complete more quests to earn points!',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Got it!',
                                style: TextStyle(
                                  color: AppConstants.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppConstants.primaryGreen,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: AppConstants.primaryGreen,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$points',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                              color: AppConstants.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileImage(String profileImage, String? customImagePath) {
    // Priority: custom image > Google photo > asset image
    if (profileImage == 'custom' && customImagePath != null) {
      return Image.file(
        File(customImagePath),
        fit: BoxFit.cover,
        width: 48,
        height: 48,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, size: 28, color: AppConstants.darkGreen);
        },
      );
    } else if (profileImage == 'google') {
      // Use Google profile picture
      final googlePhotoUrl = SupabaseAuthService.userPhotoUrl;
      if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
        return Image.network(
          googlePhotoUrl,
          fit: BoxFit.cover,
          width: 48,
          height: 48,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/profile1.jpg',
              fit: BoxFit.cover,
              width: 48,
              height: 48,
            );
          },
        );
      } else {
        // Fallback to default asset if no Google photo
        return Image.asset(
          'assets/profile1.jpg',
          fit: BoxFit.cover,
          width: 48,
          height: 48,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.person, size: 28, color: AppConstants.darkGreen);
          },
        );
      }
    } else {
      // Use asset image
      return Image.asset(
        profileImage,
        fit: BoxFit.cover,
        width: 48,
        height: 48,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, size: 28, color: AppConstants.darkGreen);
        },
      );
    }
  }
}

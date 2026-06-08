import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/achievement.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  List<Achievement> _pinned = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Load both endpoints independently so one failure can't hide the other.
    // We always flip `_isLoading` off in a finally so the screen can't get
    // wedged on the skeleton.
    UserProfile? profile;
    List<Achievement> pinned = const [];
    String? error;
    try {
      profile = await ApiService.getProfile();
    } catch (e) {
      error = 'profile: $e';
    }
    try {
      final all = await ApiService.getAchievements();
      pinned = all.where((a) => a.isPinned).toList();
    } catch (e) {
      error = error == null ? 'achievements: $e' : '$error; achievements: $e';
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _pinned = pinned;
      _isLoading = false;
    });
    if (error != null) {
      AppSnackBar.error(context, 'Profile load failed — $error');
    }
  }

  Future<void> _logout() async {
    try {
      await ApiService.logout();
    } catch (_) {
      // Even if the server call fails, clear local creds below.
    }
    if (mounted) context.go('/login');
  }

  Future<void> _openAchievements() async {
    await context.push('/profile/achievements');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const _ProfileSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (_profile != null) _LevelCard(profile: _profile!),
                  const SizedBox(height: 16),
                  if (_profile != null) _StatsRow(profile: _profile!),
                  const SizedBox(height: 24),
                  _PinnedHeader(onTapSeeAll: _openAchievements),
                  const SizedBox(height: 12),
                  _PinnedRow(
                    pinned: _pinned,
                    onTapSlot: _openAchievements,
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Log out',
                      style: TextStyle(color: AppColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final UserProfile profile;
  const _LevelCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  profile.username.isEmpty
                      ? '?'
                      : profile.username[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.tier} · Lv. ${profile.level}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: profile.progressFraction,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${profile.xpIntoLevel} / ${profile.xpForNextLevel} XP to Lv. ${profile.level + 1}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final UserProfile profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: Icons.local_fire_department_rounded,
            iconColor: AppColors.amber,
            label: '${profile.currentStreak}-day streak',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            icon: Icons.emoji_events_rounded,
            iconColor: AppColors.primary,
            label:
                '${profile.achievementsUnlocked} / ${profile.achievementsTotal} badges',
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedHeader extends StatelessWidget {
  final VoidCallback onTapSeeAll;
  const _PinnedHeader({required this.onTapSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Pinned achievements',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        GestureDetector(
          onTap: onTapSeeAll,
          child: const Row(
            children: [
              Text(
                'See all',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinnedRow extends StatelessWidget {
  static const int slotCount = 3;
  final List<Achievement> pinned;
  final VoidCallback onTapSlot;

  const _PinnedRow({required this.pinned, required this.onTapSlot});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < slotCount; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: i < pinned.length
                ? _PinnedTile(achievement: pinned[i], onTap: onTapSlot)
                : _EmptySlot(onTap: onTapSlot),
          ),
        ],
      ],
    );
  }
}

class _PinnedTile extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;
  const _PinnedTile({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = achievement.tierColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(achievement.iconData, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptySlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.cardBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.add_rounded,
            color: AppColors.textMuted,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: const [
        SkeletonBox(height: 132, radius: 20),
        SizedBox(height: 16),
        SkeletonBox(height: 50, radius: 14),
        SizedBox(height: 24),
        SkeletonBox(width: 200, height: 22, radius: 8),
        SizedBox(height: 12),
        SkeletonBox(height: 104, radius: 14),
      ],
    );
  }
}

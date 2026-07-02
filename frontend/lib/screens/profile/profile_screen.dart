import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/achievement.dart';
import '../../models/medal_series.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/medal.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/tier_frame.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  List<Achievement> _pinned = [];
  List<MedalSeries> _series = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Load both endpoints independently so one failure can't hide the other.
    UserProfile? profile;
    List<Achievement> pinned = const [];
    String? error;
    try {
      profile = await ApiService.getProfile();
    } catch (e) {
      error = 'profile: $e';
    }
    List<MedalSeries> series = const [];
    try {
      final all = await ApiService.getAchievements();
      pinned = all.where((a) => a.isPinned).toList();
      series = MedalSeries.fromAchievements(all);
    } catch (e) {
      error = error == null ? 'achievements: $e' : '$error; achievements: $e';
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _pinned = pinned;
      _series = series;
      _isLoading = false;
    });
    if (error != null) {
      AppSnackBar.error(context, 'Profile load failed — $error');
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/profile/settings'),
          ),
        ],
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
                  if (_profile != null) ...[
                    _HeroCard(profile: _profile!),
                    const SizedBox(height: 16),
                    _StatsGrid(profile: _profile!),
                    const SizedBox(height: 12),
                    _ShopRow(
                      seeds: _profile!.seeds,
                      onTap: () async {
                        await context.push('/profile/shop');
                        _load(); // seeds may have been spent
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  _SectionHeader(
                    title: 'Medal showcase',
                    actionLabel: 'Medal book',
                    onAction: _openAchievements,
                  ),
                  const SizedBox(height: 12),
                  _ShowcaseRow(
                    pinned: _pinned,
                    series: _series,
                    onTapSlot: _openAchievements,
                  ),
                ],
              ),
            ),
    );
  }
}

/// Gradient identity card: framed avatar, name, tier pill, XP ring of
/// progress toward the next level.
class _HeroCard extends StatelessWidget {
  final UserProfile profile;
  const _HeroCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tierColor = TierFrame.tierColor(profile.tier);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientSoftStart, AppColors.gradientSoftEnd],
        ),
        borderRadius: BorderRadius.circular(24),
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
              TierFrame(
                tier: profile.tier,
                size: 84,
                child: Container(
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
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Tier pill — dot tinted with the tier's frame color so
                    // the label visually links to the avatar frame.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: tierColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${profile.tier} · Lv. ${profile.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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

/// 2×2 grid of soft stat tiles — same tinted-icon language as the plant
/// detail status card and the Tasks screen.
class _StatsGrid extends StatelessWidget {
  final UserProfile profile;
  const _StatsGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.amber,
                label: 'CURRENT STREAK',
                value: '${profile.currentStreak} days',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.bolt_rounded,
                color: const Color(0xFF4F9FD9),
                label: 'LONGEST STREAK',
                value: '${profile.longestStreak} days',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFE5A722),
                label: 'MEDALS',
                value:
                    '${profile.achievementsUnlocked} / ${profile.achievementsTotal}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.primary,
                label: 'TOTAL XP',
                value: '${profile.xp}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width Seed Shop entry: balance on the left, chevron to the shop.
class _ShopRow extends StatelessWidget {
  final int seeds;
  final VoidCallback onTap;
  const _ShopRow({required this.seeds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.spa_rounded,
                color: AppColors.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seed Shop',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Spend seeds on skins for your companion',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$seeds',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        GestureDetector(
          onTap: onAction,
          child: Row(
            children: [
              Text(
                actionLabel,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
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

/// The three pinned medals on one soft shelf card, rendered with the
/// ribboned [Medal] widget so they match the medal book.
class _ShowcaseRow extends StatelessWidget {
  static const int slotCount = 3;
  final List<Achievement> pinned;
  final List<MedalSeries> series;
  final VoidCallback onTapSlot;

  const _ShowcaseRow({
    required this.pinned,
    required this.series,
    required this.onTapSlot,
  });

  /// The series a pinned achievement belongs to (for stars/metal display).
  MedalSeries? _seriesFor(Achievement a) {
    for (final s in series) {
      if (s.levels.any((l) => l.code == a.code)) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < slotCount; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: i < pinned.length
                      ? _ShowcaseMedal(
                          achievement: pinned[i],
                          series: _seriesFor(pinned[i]),
                          onTap: onTapSlot,
                        )
                      : _EmptyMedalSlot(onTap: onTapSlot),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Shelf line under the medals, echoing the medal book pages.
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseMedal extends StatelessWidget {
  final Achievement achievement;
  final MedalSeries? series;
  final VoidCallback onTap;
  const _ShowcaseMedal({
    required this.achievement,
    required this.series,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = series;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: s != null
                ? Medal.series(s, size: 56)
                : Medal(
                    metal: MedalMetal.bronze,
                    icon: achievement.iconData,
                    level: 1,
                    maxLevel: 1,
                    size: 56,
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            s?.name ?? achievement.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMedalSlot extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyMedalSlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
              border: Border.all(color: AppColors.cardBorder, width: 1.6),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Pin a medal',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        SkeletonBox(height: 170, radius: 20),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
          ],
        ),
        SizedBox(height: 24),
        SkeletonBox(width: 180, height: 22, radius: 8),
        SizedBox(height: 12),
        SkeletonBox(height: 130, radius: 16),
        SizedBox(height: 24),
        SkeletonBox(width: 120, height: 22, radius: 8),
        SizedBox(height: 12),
        SkeletonBox(height: 110, radius: 16),
      ],
    );
  }
}

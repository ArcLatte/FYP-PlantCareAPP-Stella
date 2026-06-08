import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/achievement.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';

/// Full grid of every achievement, with pin/unpin action via bottom sheet.
/// Reached from the Profile tab's "See all" link.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _all = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.getAchievements();
      if (!mounted) return;
      setState(() {
        _all = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.error(context, 'Failed to load: $e');
    }
  }

  int get _unlockedCount => _all.where((a) => a.unlocked).length;

  Future<void> _openSheet(Achievement a) async {
    if (!a.unlocked) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BadgeSheet(
        achievement: a,
        onToggle: () async {
          try {
            final updated = a.isPinned
                ? await ApiService.unpinAchievement(a.code)
                : await ApiService.pinAchievement(a.code);
            if (!mounted) return;
            setState(() {
              final idx = _all.indexWhere((x) => x.code == a.code);
              if (idx != -1) _all[idx] = updated;
            });
            Navigator.pop(context);
          } catch (e) {
            if (!mounted) return;
            Navigator.pop(context);
            AppSnackBar.error(context, e.toString().replaceFirst('Exception: ', ''));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const _GridSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.95,
                    ),
                itemCount: _all.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return _StatsHeader(
                      unlocked: _unlockedCount,
                      total: _all.length,
                    );
                  }
                  final a = _all[i - 1];
                  return _BadgeTile(
                    achievement: a,
                    onTap: () => _openSheet(a),
                  );
                },
              ),
            ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final int unlocked;
  final int total;
  const _StatsHeader({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.primary,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            '$unlocked / $total',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'unlocked',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;
  const _BadgeTile({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final color = unlocked ? achievement.tierColor : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked ? color.withValues(alpha: 0.4) : AppColors.cardBorder,
            width: unlocked ? 1.4 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: unlocked ? 0.18 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(achievement.iconData, color: color, size: 28),
                ),
                if (achievement.isPinned)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.push_pin_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              achievement.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: unlocked
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unlocked ? achievement.tierLabel : 'Locked',
              style: TextStyle(
                color: unlocked ? color : AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeSheet extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onToggle;
  const _BadgeSheet({required this.achievement, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final color = achievement.tierColor;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(achievement.iconData, color: color, size: 42),
            ),
            const SizedBox(height: 16),
            Text(
              achievement.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${achievement.tierLabel} · +${achievement.xpReward} XP',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  achievement.isPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                ),
                label: Text(achievement.isPinned ? 'Unpin' : 'Pin to profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: achievement.isPinned
                      ? AppColors.textMuted
                      : AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemCount: 8,
      itemBuilder: (_, _) => const SkeletonBox(radius: 16),
    );
  }
}

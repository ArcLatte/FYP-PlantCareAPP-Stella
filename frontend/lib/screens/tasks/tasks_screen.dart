import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../models/streak.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';
import 'care_activity.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Plant> _plants = [];
  Streak? _streak;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getPlants(),
        ApiService.getStreak(),
      ]);
      if (!mounted) return;
      setState(() {
        _plants = results[0] as List<Plant>;
        _streak = results[1] as Streak;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.error(context, 'Failed to load tasks: $e');
    }
  }

  int _dueCount(CareActivity a) => _plants.where(a.isDue).length;

  /// Activities to show as cards: water + fertilize always, mist only when
  /// at least one plant's species supports it.
  List<CareActivity> get _visibleActivities {
    final list = <CareActivity>[CareActivity.water, CareActivity.fertilize];
    if (_plants.any(CareActivity.mist.appliesTo)) {
      list.add(CareActivity.mist);
    }
    return list;
  }

  bool get _allCaughtUp =>
      _visibleActivities.every((a) => _dueCount(a) == 0);

  Future<void> _openActivity(CareActivity a) async {
    await context.push('/tasks/${a.key}');
    _load(); // refresh counts + streak on return
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const _TasksSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _StreakHeader(streak: _streak),
                  const SizedBox(height: 24),
                  Text(
                    "Today's tasks",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (_allCaughtUp)
                    const _AllCaughtUp()
                  else
                    for (final a in _visibleActivities)
                      if (_dueCount(a) > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TaskCard(
                            activity: a,
                            count: _dueCount(a),
                            onTap: () => _openActivity(a),
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}

// ─── Streak header ─────────────────────────────────────────────

class _StreakHeader extends StatelessWidget {
  final Streak? streak;
  const _StreakHeader({required this.streak});

  @override
  Widget build(BuildContext context) {
    final current = streak?.currentStreak ?? 0;
    final longest = streak?.longestStreak ?? 0;
    final activeToday = streak?.activeToday ?? false;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBB040), AppColors.amber],
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
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              current > 0
                  ? Icons.local_fire_department_rounded
                  : Icons.local_fire_department_outlined,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$current',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      current == 1 ? 'day streak' : 'days streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activeToday
                      ? "You've cared for a plant today ✓"
                      : current > 0
                          ? 'Care for a plant to keep it going'
                          : 'Complete a task to start your streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (longest > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Longest: $longest ${longest == 1 ? 'day' : 'days'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Task category card ────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final CareActivity activity;
  final int count;
  final VoidCallback onTap;
  const _TaskCard({
    required this.activity,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: activity.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(activity.icon, color: activity.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? 'plant' : 'plants'} need attention',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: activity.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─── All-caught-up state ───────────────────────────────────────

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'No plants need care right now. Nice work.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ─── Loading skeleton ──────────────────────────────────────────

class _TasksSkeleton extends StatelessWidget {
  const _TasksSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: const [
        SkeletonBox(height: 104, radius: 20),
        SizedBox(height: 24),
        SkeletonBox(width: 140, height: 20, radius: 6),
        SizedBox(height: 16),
        SkeletonBox(height: 80, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 80, radius: 16),
      ],
    );
  }
}

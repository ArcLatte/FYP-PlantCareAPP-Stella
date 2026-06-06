import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';
import 'care_activity.dart';

/// Lists every plant for which a single care activity (water / fertilize /
/// mist) is currently due, each with a "Done" action.
class TaskDetailScreen extends StatefulWidget {
  final String activity;
  const TaskDetailScreen({super.key, required this.activity});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  CareActivity? _activity;
  List<Plant> _plants = [];
  bool _isLoading = true;
  final Set<int> _busy = {}; // plant ids with an in-flight action

  @override
  void initState() {
    super.initState();
    _activity = CareActivity.fromKey(widget.activity);
    _load();
  }

  Future<void> _load() async {
    final activity = _activity;
    if (activity == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final plants = await ApiService.getPlants();
      if (!mounted) return;
      setState(() {
        _plants = plants.where(activity.isDue).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.error(context, 'Failed to load: $e');
    }
  }

  Future<void> _markDone(Plant plant) async {
    final activity = _activity!;
    if (_busy.contains(plant.id)) return;
    setState(() => _busy.add(plant.id));
    try {
      await activity.performOn(plant.id);
      if (!mounted) return;
      setState(() {
        _plants.removeWhere((p) => p.id == plant.id);
        _busy.remove(plant.id);
      });
      AppSnackBar.success(context, '${plant.name} — ${activity.label} done');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(plant.id));
      AppSnackBar.error(context, 'Failed: $e');
    }
  }

  String _dueLabel(Plant plant) {
    final d = _activity!.daysUntil(plant);
    if (d == null) return 'Due now';
    if (d >= 0) return 'Due today';
    final overdue = -d;
    return 'Overdue by $overdue ${overdue == 1 ? 'day' : 'days'}';
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    return Scaffold(
      appBar: AppBar(
        title: Text(activity?.title ?? 'Tasks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: activity == null
          ? const Center(child: Text('Unknown task'))
          : _isLoading
              ? const _ListSkeleton()
              : _plants.isEmpty
                  ? _EmptyState(activity: activity)
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _plants.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final plant = _plants[i];
                        return _TaskPlantRow(
                          plant: plant,
                          activity: activity,
                          dueLabel: _dueLabel(plant),
                          busy: _busy.contains(plant.id),
                          onDone: () => _markDone(plant),
                        );
                      },
                    ),
    );
  }
}

class _TaskPlantRow extends StatelessWidget {
  final Plant plant;
  final CareActivity activity;
  final String dueLabel;
  final bool busy;
  final VoidCallback onDone;
  const _TaskPlantRow({
    required this.plant,
    required this.activity,
    required this.dueLabel,
    required this.busy,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: plant.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: plant.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const SkeletonBox(radius: 0),
                      errorWidget: (_, _, _) => _thumbFallback(),
                    )
                  : _thumbFallback(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dueLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Done button
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: busy ? null : onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: activity.color,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 18),
                        SizedBox(width: 4),
                        Text('Done'),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 24),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final CareActivity activity;
  const _EmptyState({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.celebration_rounded,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing left to ${activity.label.toLowerCase()}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Every plant here is taken care of.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: const [
        SkeletonBox(height: 72, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 72, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 72, radius: 16),
      ],
    );
  }
}

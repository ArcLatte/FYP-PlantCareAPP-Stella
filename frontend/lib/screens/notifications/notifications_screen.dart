import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Plant> _plants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plants = await ApiService.getPlants();
      if (!mounted) return;
      setState(() {
        _plants = plants;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.error(context, e, fallback: 'Could not load care alerts.');
    }
  }

  List<Plant> get _due => _plants
      .where((p) => p.needsWater || p.needsFertilizer || p.needsMisting)
      .toList();

  int get _actionCount => _due.fold(
    0,
    (sum, p) =>
        sum +
        (p.needsWater ? 1 : 0) +
        (p.needsFertilizer ? 1 : 0) +
        (p.needsMisting ? 1 : 0),
  );

  @override
  Widget build(BuildContext context) {
    final due = _due;
    return Scaffold(
      appBar: AppBar(title: const Text('Care alerts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _SummaryCard(
                    plantCount: due.length,
                    actionCount: _actionCount,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Today's care",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (due.isEmpty)
                    const _CaughtUpCard()
                  else
                    for (final plant in due) ...[
                      _CareAlertCard(
                        plant: plant,
                        onTap: () async {
                          await context.push('/plants/${plant.id}');
                          _load();
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int plantCount;
  final int actionCount;

  const _SummaryCard({required this.plantCount, required this.actionCount});

  @override
  Widget build(BuildContext context) {
    final clear = actionCount == 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (clear ? AppColors.primary : const Color(0xFF4F9FD9)).withValues(
          alpha: 0.11,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            clear
                ? Icons.check_circle_rounded
                : Icons.notifications_active_rounded,
            color: clear ? AppColors.primary : const Color(0xFF4F9FD9),
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clear
                      ? 'You are all caught up'
                      : '$actionCount care ${actionCount == 1 ? 'task' : 'tasks'} due',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  clear
                      ? 'Your garden has nothing urgent today.'
                      : 'Across $plantCount ${plantCount == 1 ? 'plant' : 'plants'} in your garden.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CareAlertCard extends StatelessWidget {
  final Plant plant;
  final VoidCallback onTap;

  const _CareAlertCard({required this.plant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, Color, String)>[
      if (plant.needsWater)
        (Icons.water_drop_rounded, const Color(0xFF4F9FD9), 'Water'),
      if (plant.needsFertilizer)
        (Icons.compost_rounded, AppColors.amber, 'Fertilize'),
      if (plant.needsMisting)
        (Icons.cloud_rounded, const Color(0xFF26A69A), 'Mist'),
    ];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.eco_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final action in actions) _ActionChip(action: action),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final (IconData, Color, String) action;
  const _ActionChip({required this.action});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: action.$2.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(action.$1, size: 14, color: action.$2),
        const SizedBox(width: 5),
        Text(
          action.$3,
          style: TextStyle(
            color: action.$2,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _CaughtUpCard extends StatelessWidget {
  const _CaughtUpCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: const Column(
      children: [
        Icon(Icons.spa_rounded, color: AppColors.primary, size: 42),
        SizedBox(height: 10),
        Text(
          'Nothing needs attention right now',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

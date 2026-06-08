import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton.dart';
import '../tasks/care_activity.dart';
import 'history_timeline.dart';

/// Per-day activity timeline. Each day groups same-type events into one row
/// ("Watered 3 plants — last 3:42 PM") so a busy day doesn't drown the page.
/// Tap a row → per-day-per-activity detail at `/history/{activity}/{date}`.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ActivityEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await ApiService.getActivity();
      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ─── Grouping ────────────────────────────────────────────────

  /// Returns a list of (date label, list of activity groups for that day).
  /// Outer order is reverse-chronological (newest day first); inner groups
  /// are reverse-chronological by their latest event timestamp.
  List<_DayBuckets> get _days {
    // First, bucket events by local date in arrival order (newest first).
    final byDate = <DateTime, List<ActivityEvent>>{};
    final dateOrder = <DateTime>[];
    for (final e in _events) {
      final local = e.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (!byDate.containsKey(day)) {
        dateOrder.add(day);
        byDate[day] = [];
      }
      byDate[day]!.add(e);
    }

    // Then within each day, group by activity key.
    return [
      for (final day in dateOrder)
        _DayBuckets(date: day, groups: _groupDay(byDate[day]!)),
    ];
  }

  List<_ActivityGroup> _groupDay(List<ActivityEvent> dayEvents) {
    final byKey = <String, List<ActivityEvent>>{};
    final keyOrder = <String>[];
    for (final e in dayEvents) {
      final key = e.isCare ? (e.activity ?? '') : 'scan';
      if (!byKey.containsKey(key)) {
        keyOrder.add(key);
        byKey[key] = [];
      }
      byKey[key]!.add(e);
    }
    return [for (final k in keyOrder) _ActivityGroup(key: k, events: byKey[k]!)];
  }

  // ─── Per-group styling ──────────────────────────────────────

  _Style _styleFor(_ActivityGroup g) {
    if (g.key == 'scan') {
      // Pending wins (muted), else any diseased → amber, else all healthy → success.
      final pending = g.events.any((e) => e.label == null);
      final anyDiseased = g.events.any((e) => e.health == 'diseased');
      if (pending) {
        return _Style(
          color: AppColors.textMuted,
          icon: Icons.hourglass_empty_rounded,
        );
      }
      if (anyDiseased) {
        return _Style(
          color: AppColors.amber,
          icon: Icons.warning_amber_rounded,
        );
      }
      return _Style(color: AppColors.success, icon: Icons.favorite_rounded);
    }
    final a = CareActivity.fromKey(g.key);
    return _Style(
      color: a?.color ?? AppColors.primary,
      icon: a?.icon ?? Icons.eco_rounded,
    );
  }

  String _titleFor(_ActivityGroup g) {
    final n = g.events.length;
    final unit = n == 1 ? 'plant' : 'plants';
    if (g.key == 'scan') return 'Scanned $n $unit';
    final pastTense = CareActivity.fromKey(g.key)?.pastTense ?? 'Cared for';
    return '$pastTense $n $unit';
  }

  String _subtitleFor(_ActivityGroup g) {
    // Events arrive newest-first within the day; `.first` is the latest.
    final latest = timeLabel(g.events.first.createdAt);
    return g.events.length == 1 ? latest : 'last $latest';
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final days = _days;
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const _LandingSkeleton()
          : days.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  for (final day in days) ...[
                    DateHeader(label: dateBucket(day.date)),
                    for (int i = 0; i < day.groups.length; i++)
                      _buildTile(
                        day,
                        day.groups[i],
                        isFirst: i == 0,
                        isLast: i == day.groups.length - 1,
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTile(
    _DayBuckets day,
    _ActivityGroup g, {
    required bool isFirst,
    required bool isLast,
  }) {
    final style = _styleFor(g);
    return TimelineTile(
      isFirst: isFirst,
      isLast: isLast,
      color: style.color,
      icon: style.icon,
      title: _titleFor(g),
      subtitle: _subtitleFor(g),
      trailingCount: g.events.length > 1 ? '${g.events.length}' : null,
      showChevron: true,
      onTap: () async {
        await context.push('/history/${g.key}/${isoDate(day.date)}');
        _load();
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history_rounded,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Watering, fertilizing and scans will show up here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DayBuckets {
  final DateTime date;
  final List<_ActivityGroup> groups;
  const _DayBuckets({required this.date, required this.groups});
}

class _ActivityGroup {
  final String key; // 'water' | 'fertilize' | 'mist' | 'scan'
  final List<ActivityEvent> events; // newest-first
  const _ActivityGroup({required this.key, required this.events});
}

class _Style {
  final Color color;
  final IconData icon;
  const _Style({required this.color, required this.icon});
}

class _LandingSkeleton extends StatelessWidget {
  const _LandingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const SkeletonBox(width: 80, height: 14, radius: 6),
        const SizedBox(height: 16),
        for (int i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: const [
                SkeletonBox(width: 28, height: 28, radius: 14),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 56, radius: 14)),
              ],
            ),
          ),
      ],
    );
  }
}

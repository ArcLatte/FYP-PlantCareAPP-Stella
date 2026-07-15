import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton.dart';
import '../tasks/care_activity.dart';
import 'history_timeline.dart';

/// Per-day, per-activity detail: every event of a single activity on one
/// calendar day. Reached from the History landing via `/history/{activity}/{date}`.
class HistoryDetailScreen extends StatefulWidget {
  final String activity; // 'water' | 'fertilize' | 'mist' | 'scan'
  final DateTime date; // local date (year/month/day only matters)

  const HistoryDetailScreen({
    super.key,
    required this.activity,
    required this.date,
  });

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  List<ActivityEvent> _events = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final all = await ApiService.getActivity();
      if (!mounted) return;
      setState(() {
        _events = all.where(_matches).toList();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load this activity. Please try again.';
      });
    }
  }

  bool _matches(ActivityEvent e) {
    final typeOk = widget.activity == 'scan'
        ? e.isScan
        : (e.isCare && e.activity == widget.activity);
    if (!typeOk) return false;
    final local = e.createdAt.toLocal();
    return local.year == widget.date.year &&
        local.month == widget.date.month &&
        local.day == widget.date.day;
  }

  String get _title {
    final bucket = dateBucket(widget.date);
    if (widget.activity == 'scan') {
      // "Today's scans" / "10 Jun · Scans"
      if (bucket == 'Today') return "Today's scans";
      if (bucket == 'Yesterday') return "Yesterday's scans";
      return '$bucket · Scans';
    }
    final a = CareActivity.fromKey(widget.activity);
    final gerund = a?.title.toLowerCase() ?? widget.activity;
    if (bucket == 'Today') return "Today's $gerund";
    if (bucket == 'Yesterday') return "Yesterday's $gerund";
    final past = a?.pastTense ?? widget.activity;
    return '$bucket · $past';
  }

  // ─── Per-event presentation ─────────────────────────────────

  _EventStyle _styleFor(ActivityEvent e) {
    if (e.isCare) {
      final a = CareActivity.fromKey(e.activity ?? '');
      return _EventStyle(
        color: a?.color ?? AppColors.primary,
        icon: a?.icon ?? Icons.eco_rounded,
        title: e.plantName ?? 'plant',
      );
    }
    final pending = e.label == null;
    final healthy = e.health == 'healthy';
    return _EventStyle(
      color: pending
          ? AppColors.textMuted
          : (healthy ? AppColors.success : AppColors.amber),
      icon: pending
          ? Icons.hourglass_empty_rounded
          : (healthy ? Icons.favorite_rounded : Icons.warning_amber_rounded),
      title: pending
          ? '${e.plantName ?? 'Plant'} — pending'
          : '${e.plantName ?? 'Plant'} — ${formatScanLabel(e.label!)}',
    );
  }

  void _onTap(ActivityEvent e) {
    if (e.isScan && e.scanId != null) {
      context.push('/result/${e.scanId}');
    } else if (e.plantId != null) {
      context.push('/plants/${e.plantId}');
    }
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const _DetailSkeleton()
          : _errorMessage != null
              ? _buildError()
              : _events.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing on this day',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        itemCount: _events.length,
                        itemBuilder: (context, i) {
                          final e = _events[i];
                          final s = _styleFor(e);
                          return TimelineTile(
                            isFirst: i == 0,
                            isLast: i == _events.length - 1,
                            color: s.color,
                            icon: s.icon,
                            title: s.title,
                            subtitle: timeLabel(e.createdAt),
                            showChevron: e.isScan,
                            onTap: () => _onTap(e),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventStyle {
  final Color color;
  final IconData icon;
  final String title;
  const _EventStyle({
    required this.color,
    required this.icon,
    required this.title,
  });
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        for (int i = 0; i < 5; i++)
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

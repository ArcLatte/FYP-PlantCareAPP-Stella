import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../models/plant_stage.dart';
import '../../models/streak.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stage_image.dart';
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

  Future<void> _openHistory() async {
    await context.push('/history');
    if (mounted) _load(); // a logged action there may change counts/streak
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const _TasksSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Full-bleed plant-growth backdrop (like the home weather
                  // header — fills the top, sits behind the status bar).
                  _StreakBackdrop(streak: _streak),
                  // Tasks panel sits on top of the backdrop, overlapping upward
                  // with rounded top corners.
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Today's tasks",
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              _HistoryButton(onTap: _openHistory),
                            ],
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
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Streak card (plant growth) ────────────────────────────────

// Plant-growth palette: colored plant illustration + water-blue activity dots
// on a soft green backdrop. The streak grows a plant (seed → bloom); each
// cared-for day is a water drop.
const Color _kWater = Color(0xFF4F9FD9); // water-blue for active days
const Color _kBackdropTop = Color(0xFFEAF6EF); // soft mint (top)
const Color _kBackdropBottom = Color(0xFFCFE8DA); // deeper mint (bottom)
const String _kStageSeenKey = 'tasks_last_plant_stage';

// Eye positions for the blink overlay, as fractions of the (square) stage box —
// they mirror the dot-eyes baked into the corresponding `<stage>.svg` (drawn on
// a 0..100 canvas). Eyes are symmetric about the centre, so only the half-spacing
// `dx`, vertical `cy`, and radius `r` are stored. Stages absent here (seed is
// asleep, bloom has `^^` eyes) don't blink.
const Map<String, ({double dx, double cy, double r})> _eyeGeometry = {
  'sprout': (dx: 0.07, cy: 0.68, r: 0.032),
  'seedling': (dx: 0.075, cy: 0.62, r: 0.033),
  'young': (dx: 0.08, cy: 0.58, r: 0.034),
  'leafy': (dx: 0.08, cy: 0.58, r: 0.035),
};

/// Paints two short rounded "closed eyelid" strokes over the baked-in dot-eyes
/// during a blink. The stroke is the same dark tone as the eyes and thickens
/// with [amount] (0 = open/invisible, 1 = fully closed), so it reads as the eye
/// squeezing shut. At full close it covers the dot and its highlight.
class _EyelidPainter extends CustomPainter {
  final ({double dx, double cy, double r}) geo;
  final double amount;
  const _EyelidPainter(this.geo, this.amount);

  @override
  void paint(Canvas canvas, Size size) {
    if (amount <= 0.01) return;
    final r = geo.r * size.width;
    final cy = geo.cy * size.height;
    final cxL = size.width * (0.5 - geo.dx);
    final cxR = size.width * (0.5 + geo.dx);
    final half = 1.2 * r;
    final paint = Paint()
      ..color = const Color(0xFF2E3D30)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2 * r * amount;
    canvas.drawLine(Offset(cxL - half, cy), Offset(cxL + half, cy), paint);
    canvas.drawLine(Offset(cxR - half, cy), Offset(cxR + half, cy), paint);
  }

  @override
  bool shouldRepaint(_EyelidPainter old) =>
      old.amount != amount || old.geo != geo;
}

/// Full-bleed streak backdrop (home-weather style): the plant for the current
/// growth stage (with an idle sway and a grow-pop when it advances a stage),
/// the stage name + day count, a "next stage" hint, then the current week's
/// water-day strip. The tasks panel overlaps it from above.
class _StreakBackdrop extends StatefulWidget {
  final Streak? streak;
  const _StreakBackdrop({required this.streak});

  @override
  State<_StreakBackdrop> createState() => _StreakBackdropState();
}

class _StreakBackdropState extends State<_StreakBackdrop>
    with TickerProviderStateMixin {
  late final AnimationController _sway;
  late final AnimationController _grow;
  late final AnimationController _bob; // slow vertical bob, layered with sway
  late final AnimationController _blink; // periodic eye blink
  SharedPreferences? _prefs;
  int? _lastSeen; // last stage index the user has already seen
  int? _fromIndex; // stage to cross-fade *from* during a grow-pop

  int get _currentIndex =>
      PlantStage.all.indexOf(PlantStage.forStreak(widget.streak?.currentStreak ?? 0));

  @override
  void initState() {
    super.initState();
    _sway = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    _grow = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900), value: 1);
    // Bob runs at a different period than sway so the two don't beat in sync —
    // gives the idle a more organic, breathing feel.
    _bob = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3100))
      ..repeat();
    // One blink near the end of each cycle (see [_blinkAmount]).
    _blink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4400))
      ..repeat();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _lastSeen = _prefs!.getInt(_kStageSeenKey);
    if (mounted) _evaluate();
  }

  @override
  void didUpdateWidget(covariant _StreakBackdrop old) {
    super.didUpdateWidget(old);
    if (old.streak?.currentStreak != widget.streak?.currentStreak) {
      _evaluate();
    }
  }

  /// Celebrate with a grow-pop if the plant has advanced past the last seen
  /// stage; otherwise just remember the current stage.
  void _evaluate() {
    if (_prefs == null || widget.streak == null) return;
    final cur = _currentIndex;
    if (_lastSeen != null && cur > _lastSeen!) {
      setState(() => _fromIndex = _lastSeen);
      _grow.forward(from: 0).whenComplete(() {
        _prefs!.setInt(_kStageSeenKey, cur);
        _lastSeen = cur;
        if (mounted) setState(() => _fromIndex = null);
      });
    } else {
      _prefs!.setInt(_kStageSeenKey, cur);
      _lastSeen = cur;
    }
  }

  @override
  void dispose() {
    _sway.dispose();
    _grow.dispose();
    _bob.dispose();
    _blink.dispose();
    super.dispose();
  }

  /// Blink curve: 0 (eyes open) most of the cycle, ramping up to 1 (closed) and
  /// back down in a brief window near the end. Derived from [_blink].value.
  double _blinkAmount() {
    const start = 0.94; // last ~6% of the cycle is the blink (~264ms)
    final v = _blink.value;
    if (v < start) return 0;
    final t = (v - start) / (1 - start); // 0→1 across the window
    return t < 0.5 ? t / 0.5 : (1 - t) / 0.5; // close then open
  }

  /// Which days of the current week (Mon→Sun) fall inside the current streak.
  List<bool> _litDays() {
    final lit = List<bool>.filled(7, false);
    final s = widget.streak;
    final current = s?.currentStreak ?? 0;
    if (s == null || current <= 0) return lit;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? end;
    if (s.activeToday) {
      end = today;
    } else if (s.lastCareDate != null) {
      final l = s.lastCareDate!;
      end = DateTime(l.year, l.month, l.day);
    }
    if (end == null) return lit;
    final start = end.subtract(Duration(days: current - 1));
    final monday = today.subtract(Duration(days: today.weekday - 1));

    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      if (!day.isBefore(start) && !day.isAfter(end)) lit[i] = true;
    }
    return lit;
  }

  String _caption(int current) {
    if (current == 0) return 'Care for a plant to start growing';
    final stage = PlantStage.forStreak(current);
    final next = PlantStage.next(stage);
    if (next == null) return 'Fully grown — keep it going';
    final d = next.minDays - current;
    return 'Grows to ${next.name.toLowerCase()} in $d ${d == 1 ? 'day' : 'days'}';
  }

  Widget _plantArea(PlantStage stage) {
    return SizedBox(
      height: 148,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_sway, _grow, _bob, _blink]),
          builder: (context, _) {
            // Soft vertical bob applied to whichever state is showing.
            final bob = math.sin(_bob.value * 2 * math.pi) * 3.0;

            Widget content;
            if (_fromIndex != null) {
              final from = PlantStage.all[_fromIndex!];
              final g = _grow.value.clamp(0.0, 1.0);
              final eased = Curves.easeOutBack.transform(g);
              content = Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Opacity(
                    opacity: 1 - g,
                    child: StageImage(image: from.image, size: from.size),
                  ),
                  Opacity(
                    opacity: g,
                    child: Transform.scale(
                      scale: 0.5 + 0.5 * eased,
                      alignment: Alignment.bottomCenter,
                      child: StageImage(image: stage.image, size: stage.size),
                    ),
                  ),
                ],
              );
            } else {
              final sway = math.sin(_sway.value * 2 * math.pi) * 0.05;
              Widget creature = StageImage(image: stage.image, size: stage.size);
              // Overlay blinking eyelids for stages that have dot-eyes.
              final geo = _eyeGeometry[stage.image];
              if (geo != null) {
                creature = Stack(
                  alignment: Alignment.center,
                  children: [
                    creature,
                    SizedBox(
                      width: stage.size,
                      height: stage.size,
                      child: CustomPaint(
                        painter: _EyelidPainter(geo, _blinkAmount()),
                      ),
                    ),
                  ],
                );
              }
              content = Transform.rotate(
                angle: sway,
                alignment: Alignment.bottomCenter,
                child: creature,
              );
            }

            return Transform.translate(
              offset: Offset(0, bob),
              child: content,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.streak?.currentStreak ?? 0;
    final lit = _litDays();
    final stage = PlantStage.forStreak(current);
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      // Sits behind the status bar (no app bar); pad content clear of it.
      // Extra bottom padding so the overlapping tasks panel doesn't clip it.
      padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBackdropTop, _kBackdropBottom],
        ),
      ),
      child: Column(
        children: [
          _plantArea(stage),
          const SizedBox(height: 8),
          Text(
            stage.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$current ${current == 1 ? 'day' : 'days'} streak',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _caption(current),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          _WeekStrip(lit: lit),
        ],
      ),
    );
  }
}

/// Current week (Mon→Sun): a day initial above a circle. Each cared-for day is
/// a blue water drop; consecutive cared-for days are joined by a blue bar.
class _WeekStrip extends StatelessWidget {
  final List<bool> lit;
  const _WeekStrip({required this.lit});

  // Monday-first initials.
  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return Row(
      children: List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final isToday = day == today;
        final litHere = lit[i];
        final litLeft = i > 0 && litHere && lit[i - 1];
        final litRight = i < 6 && litHere && lit[i + 1];
        return Expanded(
          child: _DayCell(
            label: _initials[i],
            lit: litHere,
            isToday: isToday,
            litLeft: litLeft,
            litRight: litRight,
          ),
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String label;
  final bool lit;
  final bool isToday;
  final bool litLeft;
  final bool litRight;

  static const double _d = 28; // circle diameter
  static const double _barH = 10; // connector thickness

  const _DayCell({
    required this.label,
    required this.lit,
    required this.isToday,
    required this.litLeft,
    required this.litRight,
  });

  // Blue connecting line, shown only between two adjacent cared-for days.
  Widget _bar(bool on) => Expanded(
        child: on
            ? Container(height: _barH, color: _kWater)
            : const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isToday ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _d,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(children: [_bar(litLeft), _bar(litRight)]),
              Container(
                width: _d,
                height: _d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lit ? _kWater : Colors.white,
                  border: Border.all(
                    color: lit
                        ? _kWater
                        : (isToday ? _kWater : AppColors.cardBorder),
                    width: isToday && !lit ? 2 : 1,
                  ),
                ),
                child: lit
                    ? const Icon(Icons.water_drop_rounded,
                        color: Colors.white, size: 15)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── History header button ─────────────────────────────────────

/// Tinted pill in the "Today's tasks" header that opens the care history.
/// Mirrors the "Filter" pill on the home garden header for consistency.
class _HistoryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HistoryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.history_rounded, color: AppColors.primary, size: 16),
            SizedBox(width: 4),
            Text(
              'History',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
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
    final topInset = MediaQuery.of(context).padding.top;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, topInset + 24, 20, 24),
      children: const [
        SkeletonBox(height: 200, radius: 20),
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

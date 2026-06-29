import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../models/plant_stage.dart';
import '../../models/streak.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/streak_plant.dart';
import '../../widgets/weather_backdrop.dart';
import '../../widgets/weather_scene_art.dart';
import 'care_activity.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Plant> _plants = [];
  Streak? _streak;
  Weather? _weather;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadWeather();
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

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    final cachedWeather = await WeatherService.getCachedWeather(
      ignoreAge: !forceRefresh,
    );
    if (mounted && cachedWeather != null) {
      setState(() => _weather = cachedWeather);
    }

    final cached = await LocationService.getCached();
    if (cached != null) {
      final w = await WeatherService.getWeather(cached.lat, cached.lon);
      if (mounted && w != null) setState(() => _weather = w);
    }

    final loc = await LocationService.getCurrent(forceRefresh: forceRefresh);
    if (loc == null) return;
    final fresh = await WeatherService.getWeather(
      loc.lat,
      loc.lon,
      forceRefresh: forceRefresh,
    );
    if (mounted && fresh != null) setState(() => _weather = fresh);
  }

  Future<void> _onRefresh() async {
    await Future.wait([_load(), _loadWeather(forceRefresh: true)]);
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

  bool get _allCaughtUp => _visibleActivities.every((a) => _dueCount(a) == 0);

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
              onRefresh: _onRefresh,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Full-bleed plant-growth backdrop (like the home weather
                  // header — fills the top, sits behind the status bar).
                  _StreakBackdrop(streak: _streak, weather: _weather),
                  // Tasks panel sits on top of the backdrop, overlapping upward
                  // with rounded top corners.
                  Transform.translate(
                    offset: const Offset(0, -44),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
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
const String _kPlantStageAssets = 'assets/plant_stages';
const String _kStageSeenKey = 'tasks_last_plant_stage';

String _streakSceneIcon(DateTime now) {
  if (now.hour < 7 || now.hour >= 18) return '02n';
  return '02d';
}

bool _streakUsesLightText(String iconCode, DateTime now) =>
    iconCode.endsWith('n') || now.hour >= 17 || now.hour < 8;

/// Full-bleed streak backdrop (home-weather style): the plant for the current
/// growth stage (with an idle sway and a grow-pop when it advances a stage),
/// the stage name + day count, a "next stage" hint, then the current week's
/// water-day strip. The tasks panel overlaps it from above.
class _StreakBackdrop extends StatefulWidget {
  final Streak? streak;
  final Weather? weather;
  const _StreakBackdrop({required this.streak, required this.weather});

  @override
  State<_StreakBackdrop> createState() => _StreakBackdropState();
}

class _StreakBackdropState extends State<_StreakBackdrop>
    with TickerProviderStateMixin {
  // Grow-pop when the plant advances a stage. The per-part idle animation
  // (sway, leaf flutter, breathe, blink) lives inside [StreakPlant].
  late final AnimationController _grow;
  SharedPreferences? _prefs;
  int? _lastSeen; // last stage index the user has already seen
  int? _fromIndex; // stage to cross-fade *from* during a grow-pop

  int get _currentIndex => PlantStage.all.indexOf(
    PlantStage.forStreak(widget.streak?.currentStreak ?? 0),
  );

  @override
  void initState() {
    super.initState();
    _grow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: 1,
    );
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
    _grow.dispose();
    super.dispose();
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

  Widget _groundAsset(String name) =>
      SvgPicture.asset('$_kPlantStageAssets/$name.svg', fit: BoxFit.fill);

  Widget _frozenPlant(PlantStage stage, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: streakSoilBack(size)),
          Positioned.fill(
            child: streakCreatureLayers(
              stage: stage,
              size: size,
              sway: 0,
              leaf: 0,
              breathe: 1,
              blink: 0,
            ),
          ),
          Positioned.fill(child: streakSoilFront(size)),
        ],
      ),
    );
  }

  Widget _plantForScene(PlantStage stage, double plantSize) {
    // Idle: the self-animating layered plant (soil static, body sways with
    // cooldown, side leaves flutter, eyes blink). On stage-up: a grow-pop
    // crossfade between frozen poses, both scaled into this planted scene.
    if (_fromIndex == null) {
      return StreakPlant(
        key: ValueKey('${stage.image}-$plantSize'),
        stage: stage,
        size: plantSize,
      );
    }

    return AnimatedBuilder(
      animation: _grow,
      builder: (context, _) {
        final from = PlantStage.all[_fromIndex!];
        final g = _grow.value.clamp(0.0, 1.0);
        final eased = Curves.easeOutBack.transform(g);
        final fromSize = plantSize * (from.size / stage.size);
        return SizedBox(
          width: plantSize,
          height: plantSize,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Opacity(opacity: 1 - g, child: _frozenPlant(from, fromSize)),
              Opacity(
                opacity: g,
                child: Transform.scale(
                  scale: 0.5 + 0.5 * eased,
                  alignment: Alignment.bottomCenter,
                  child: _frozenPlant(stage, plantSize),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _plantedScene(PlantStage stage) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxPlantSize = math.min(190.0, constraints.maxWidth * 0.5);
        final plantSize = math.min(stage.size * 1.38, maxPlantSize);

        return SizedBox(
          height: 198,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -20,
                right: -20,
                bottom: 18,
                height: 132,
                child: _groundAsset('streak_ground_back'),
              ),
              Positioned(
                left: -20,
                right: -20,
                bottom: 0,
                height: 110,
                child: _groundAsset('streak_ground_front'),
              ),
              Positioned(bottom: 62, child: _plantForScene(stage, plantSize)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.streak?.currentStreak ?? 0;
    final lit = _litDays();
    final stage = PlantStage.forStreak(current);
    final topInset = MediaQuery.of(context).padding.top;
    final now = DateTime.now();
    final iconCode = widget.weather?.iconCode ?? _streakSceneIcon(now);
    final gradientColors = WeatherBackdrop.gradientColors(iconCode, now);
    final lightText = _streakUsesLightText(iconCode, now);
    final titleColor = lightText ? Colors.white : AppColors.textPrimary;
    final secondaryColor = lightText
        ? Colors.white.withValues(alpha: 0.84)
        : AppColors.textSecondary;
    final mutedColor = lightText
        ? Colors.white.withValues(alpha: 0.68)
        : AppColors.textMuted;

    return ClipRect(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            WeatherSceneArt(iconCode: iconCode),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: lightText ? 0.12 : 0.03),
                      Colors.black.withValues(alpha: lightText ? 0.08 : 0.0),
                      const Color(0xFFD8EFD8).withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              // Sits behind the status bar (no app bar); pad content clear of it.
              // Extra bottom padding lets the task panel overlap the planted ground.
              padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 34),
              child: Column(
                children: [
                  Text(
                    stage.name,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$current ${current == 1 ? 'day' : 'days'} streak',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _caption(current),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: mutedColor, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _WeekStrip(
                    lit: lit,
                    labelColor: mutedColor,
                    todayLabelColor: titleColor,
                  ),
                  const SizedBox(height: 8),
                  _plantedScene(stage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Current week (Mon→Sun): a day initial above a circle. Each cared-for day is
/// a blue water drop; consecutive cared-for days are joined by a blue bar.
class _WeekStrip extends StatelessWidget {
  final List<bool> lit;
  final Color labelColor;
  final Color todayLabelColor;

  const _WeekStrip({
    required this.lit,
    this.labelColor = AppColors.textSecondary,
    this.todayLabelColor = AppColors.textPrimary,
  });

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
            labelColor: labelColor,
            todayLabelColor: todayLabelColor,
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
  final Color labelColor;
  final Color todayLabelColor;

  static const double _d = 28; // circle diameter
  static const double _barH = 10; // connector thickness

  const _DayCell({
    required this.label,
    required this.lit,
    required this.isToday,
    required this.litLeft,
    required this.litRight,
    required this.labelColor,
    required this.todayLabelColor,
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
            color: isToday ? todayLabelColor : labelColor,
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
                    ? const Icon(
                        Icons.water_drop_rounded,
                        color: Colors.white,
                        size: 15,
                      )
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 36,
            ),
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

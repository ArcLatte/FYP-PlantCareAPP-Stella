import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../models/plant_stage.dart';
import '../../models/streak.dart';
import '../../models/weekly_challenge.dart';
import '../../services/api_service.dart';
import '../../services/app_refresh_bus.dart';
import '../../services/weather_controller.dart';
import '../../services/weather_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/pot.dart';
import '../../widgets/scene_effects.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/streak_plant.dart';
import '../../widgets/weather_backdrop.dart';
import '../../widgets/weather_scene_art.dart';
import '../../widgets/weekly_challenge_card.dart';
import 'care_activity.dart';
import 'streak_calendar_sheet.dart';

const _kStreakTextShadow = [
  Shadow(color: Color(0x660B1424), blurRadius: 8, offset: Offset(0, 1)),
];

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Plant> _plants = [];
  Streak? _streak;
  WeeklyChallenge? _weekly;
  Weather? _weather;
  final WeatherController _weatherController = WeatherController.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _weather = _weatherController.weather;
    _weatherController.addListener(_onWeatherChanged);
    AppRefreshBus.plants.addListener(_onPlantsChanged);
    _weatherController.start();
    _load();
    _loadWeather();
  }

  @override
  void dispose() {
    AppRefreshBus.plants.removeListener(_onPlantsChanged);
    _weatherController.removeListener(_onWeatherChanged);
    super.dispose();
  }

  void _onPlantsChanged() {
    if (mounted) _load();
  }

  void _onWeatherChanged() {
    if (mounted) setState(() => _weather = _weatherController.weather);
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
      AppSnackBar.error(
        context,
        e,
        fallback: 'Could not load your tasks. Please try again.',
      );
    }
    // Loaded separately so a challenge hiccup can't take down the task list.
    try {
      final weekly = await ApiService.getWeeklyChallenge();
      if (mounted) setState(() => _weekly = weekly);
    } catch (_) {
      // Card simply stays hidden.
    }
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    await _weatherController.refresh(forceRefresh: forceRefresh);
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
    final iconCode = _weather?.iconCode ?? _streakSceneIcon(DateTime.now());
    return Scaffold(
      body: _isLoading
          ? const _TasksSkeleton()
          : Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 620,
                  child: ColoredBox(
                    color: WeatherBackdrop.gradientColors(iconCode).first,
                  ),
                ),
                RefreshIndicator(
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
                              // Weekly Challenge sits above Today's tasks: it's a
                              // week-scoped goal, not a today-only task.
                              if (_weekly != null) ...[
                                _Entrance(
                                  index: 0,
                                  child: WeeklyChallengeCard(
                                    challenge: _weekly!,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              _Entrance(
                                index: 1,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Today's tasks",
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    _HistoryButton(onTap: _openHistory),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_allCaughtUp)
                                const _Entrance(index: 2, child: _AllCaughtUp())
                              else ...[
                                for (final (i, a) in _visibleActivities.indexed)
                                  if (_dueCount(a) > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _Entrance(
                                        index: 2 + i,
                                        child: _TaskCard(
                                          activity: a,
                                          count: _dueCount(a),
                                          onTap: () => _openActivity(a),
                                        ),
                                      ),
                                    ),
                              ],
                            ],
                          ),
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

// ─── Streak card (plant growth) ────────────────────────────────

// Plant-growth palette: colored plant illustration + water-blue activity dots
// on a soft green backdrop. The streak grows a plant (seed → bloom); each
// cared-for day is a water drop.
const Color _kWater = Color(0xFF4F9FD9); // water-blue for active days
const String _kPlantStageAssets = 'assets/plant_stages';
const String _kStageSeenKey = 'tasks_last_plant_stage';

String _streakSceneIcon(DateTime now) {
  if (now.hour < 5 || now.hour >= 21) return '02n';
  return '02d';
}

bool _streakUsesLightText(String iconCode, DateTime now) =>
    iconCode.endsWith('n') || now.hour >= 17 || now.hour < 8;

bool _streakUsesRain(String iconCode) {
  final group = iconCode.length >= 2 ? iconCode.substring(0, 2) : '';
  return group == '09' || group == '10' || group == '11';
}

enum _StreakLightPhase { sunrise, day, noon, sunset, night }

class _StreakScenePalette {
  final ColorFilter creatureFilter;
  final ColorFilter soilFilter;
  final ColorFilter groundBackFilter;
  final ColorFilter groundFrontFilter;

  const _StreakScenePalette({
    required this.creatureFilter,
    required this.soilFilter,
    required this.groundBackFilter,
    required this.groundFrontFilter,
  });

  factory _StreakScenePalette.forTime(DateTime now) {
    switch (_phaseFor(now)) {
      case _StreakLightPhase.sunrise:
        return _StreakScenePalette(
          creatureFilter: _filter(const Color(0xFFFFEBDD), 0.09),
          soilFilter: _filter(const Color(0xFFFFD0A6), 0.12),
          groundBackFilter: _filter(const Color(0xFF9EAE91), 0.08),
          groundFrontFilter: _filter(const Color(0xFF668575), 0.16),
        );
      case _StreakLightPhase.day:
        return _StreakScenePalette(
          creatureFilter: _filter(Colors.white, 0.0),
          soilFilter: _filter(const Color(0xFFFFF4D8), 0.05),
          groundBackFilter: _filter(const Color(0xFF829B86), 0.10),
          groundFrontFilter: _filter(const Color(0xFF557D72), 0.18),
        );
      case _StreakLightPhase.noon:
        return _StreakScenePalette(
          creatureFilter: _filter(const Color(0xFFFFFAE8), 0.03),
          soilFilter: _filter(const Color(0xFFFFE2A8), 0.08),
          groundBackFilter: _filter(const Color(0xFF8DA17D), 0.10),
          groundFrontFilter: _filter(const Color(0xFF5D8270), 0.18),
        );
      case _StreakLightPhase.sunset:
        return _StreakScenePalette(
          creatureFilter: _filter(const Color(0xFFD99572), 0.18),
          soilFilter: _filter(const Color(0xFFEFA36C), 0.18),
          groundBackFilter: _filter(const Color(0xFF9B9474), 0.14),
          groundFrontFilter: _filter(const Color(0xFF657C69), 0.22),
        );
      case _StreakLightPhase.night:
        return _StreakScenePalette(
          creatureFilter: _filter(const Color(0xFF53688F), 0.32),
          soilFilter: _filter(const Color(0xFF7C88AA), 0.28),
          groundBackFilter: _filter(const Color(0xFF506982), 0.30),
          groundFrontFilter: _filter(const Color(0xFF3E5D67), 0.36),
        );
    }
  }

  factory _StreakScenePalette.rainDay() {
    return _StreakScenePalette(
      creatureFilter: _filter(const Color(0xFF78909A), 0.22),
      soilFilter: _filter(const Color(0xFFA9B8BC), 0.18),
      groundBackFilter: _filter(const Color(0xFF738C91), 0.18),
      groundFrontFilter: _filter(const Color(0xFF4D6E73), 0.24),
    );
  }

  static _StreakLightPhase _phaseFor(DateTime now) {
    final h = now.hour;
    if (h < 5 || h >= 21) return _StreakLightPhase.night;
    if (h < 8) return _StreakLightPhase.sunrise;
    if (h >= 17) return _StreakLightPhase.sunset;
    if (h >= 11 && h < 15) return _StreakLightPhase.noon;
    return _StreakLightPhase.day;
  }

  static ColorFilter _filter(Color target, double amount) {
    final a = amount.clamp(0.0, 1.0);
    final keep = 1 - a;
    return ColorFilter.matrix(<double>[
      keep,
      0,
      0,
      0,
      target.r * 255 * a,
      0,
      keep,
      0,
      0,
      target.g * 255 * a,
      0,
      0,
      keep,
      0,
      target.b * 255 * a,
      0,
      0,
      0,
      1,
      0,
    ]);
  }
}

/// Full-bleed streak backdrop (home-weather style): the plant for the current
/// growth stage (with an idle sway and a grow-pop when it advances a stage),
/// the stage name + day count, a "next stage" hint, then a 7-day water strip
/// centered on today. The tasks panel overlaps it from above.
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
  late final AnimationController _rain;
  // Gentle glow on today's empty week-strip dot, inviting the day's care.
  late final AnimationController _pulse;
  // Ambient life around the plant (fireflies / motes / butterflies) — one
  // shared loop so the whole scene rides a single ticker.
  late final AnimationController _ambient;
  Timer? _clock;
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
    _rain = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _syncRainAnimation();
    _clock = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) setState(() {});
    });
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
    if (old.weather?.iconCode != widget.weather?.iconCode) {
      _syncRainAnimation();
    }
  }

  void _syncRainAnimation() {
    final iconCode =
        widget.weather?.iconCode ?? _streakSceneIcon(DateTime.now());
    if (_streakUsesRain(iconCode)) {
      if (!_rain.isAnimating) _rain.repeat();
    } else {
      _rain.stop();
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
    _clock?.cancel();
    _grow.dispose();
    _rain.dispose();
    _pulse.dispose();
    _ambient.dispose();
    super.dispose();
  }

  /// The reference "today" for the strip: the server's date when available
  /// (care days are dated on the server clock), else the device date.
  DateTime _today() {
    final t = widget.streak?.today;
    if (t != null) return DateTime(t.year, t.month, t.day);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// First day of the strip's rolling 7-day window: 3 days before today, so
  /// today always sits in the middle cell (index 3), Duolingo-style.
  DateTime _stripStart() => _today().subtract(const Duration(days: 3));

  /// Which days of the strip window were actually cared for.
  List<bool> _litDays() {
    final lit = List<bool>.filled(7, false);
    final s = widget.streak;
    if (s == null) return lit;

    final today = _today();
    final start = _stripStart();

    // Preferred: the real care days the backend sends. Counting back from
    // the streak length (fallback below) drifts once a save bridges a
    // missed day — the count is smaller than the calendar span, so the lit
    // chain shifts and days that were lit yesterday go dark.
    final recent = s.recentCareDays;
    if (recent != null) {
      for (int i = 0; i < 7; i++) {
        final day = start.add(Duration(days: i));
        // Future cells (right of today) can never hold a streak — the day
        // hasn't happened yet. Guard against a care date leaking into the
        // right half (e.g. device/server clock skew or a timezone-boundary
        // care action) and lighting a day that's still ahead.
        if (day.isAfter(today)) continue;
        lit[i] = recent.contains(day);
      }
      return lit;
    }

    final current = s.currentStreak;
    if (current <= 0) return lit;
    DateTime? end;
    if (s.activeToday) {
      end = today;
    } else if (s.lastCareDate != null) {
      final l = s.lastCareDate!;
      end = DateTime(l.year, l.month, l.day);
    }
    if (end == null) return lit;
    final runStart = end.subtract(Duration(days: current - 1));

    for (int i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      if (!day.isBefore(runStart) && !day.isAfter(end)) lit[i] = true;
    }
    return lit;
  }

  /// Days of the strip window sitting inside a save-shielded gap: after the
  /// last care day but before today, while `freezeActive`. Rendered as ice
  /// dots so the user sees the save holding the line.
  List<bool> _frozenDays() {
    final frozen = List<bool>.filled(7, false);
    final s = widget.streak;
    if (s == null || !s.freezeActive || s.lastCareDate == null) return frozen;

    final today = _today();
    final start = _stripStart();
    final l = s.lastCareDate!;
    final last = DateTime(l.year, l.month, l.day);

    for (int i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      if (day.isAfter(last) && day.isBefore(today)) frozen[i] = true;
    }
    return frozen;
  }

  Widget _groundAsset(String name, {ColorFilter? colorFilter}) =>
      SvgPicture.asset(
        '$_kPlantStageAssets/$name.svg',
        fit: BoxFit.fill,
        colorFilter: colorFilter,
      );

  /// Week strip wrapped in the pulse driver: while today is still uncared,
  /// its dot glows softly to invite the day's first action.
  Widget _buildWeekStrip(
    List<bool> lit,
    List<bool> frozen,
    Color labelColor,
    Color titleColor,
  ) {
    // Today's weekday letter pops in water-blue; on dark scenes (white
    // title text) a lighter blue keeps it readable.
    final todayBlue = titleColor.computeLuminance() > 0.65
        ? const Color(0xFF9AD4F7)
        : _kWater;
    final start = _stripStart();
    final activeToday = widget.streak?.activeToday ?? false;
    if (activeToday || widget.streak == null) {
      return _WeekStrip(
        lit: lit,
        frozen: frozen,
        start: start,
        labelColor: labelColor,
        todayLabelColor: todayBlue,
      );
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => _WeekStrip(
        lit: lit,
        frozen: frozen,
        start: start,
        labelColor: labelColor,
        todayLabelColor: todayBlue,
        todayPulse: 0.5 + 0.5 * math.sin(_pulse.value * 2 * math.pi),
      ),
    );
  }

  /// The pot the companion sits in: the equipped shop pot, or the default
  /// terracotta when nothing is equipped.
  PotStyle get _potStyle => PotStyle.fromPayload(widget.streak?.equippedPot);

  Widget _frozenPlant(
    PlantStage stage,
    double size,
    _StreakScenePalette palette,
  ) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: streakPotBack(
              size,
              _potStyle,
              colorFilter: palette.soilFilter,
            ),
          ),
          Positioned.fill(
            child: streakCreatureLayers(
              stage: stage,
              size: size,
              sway: 0,
              leaf: 0,
              breathe: 1,
              blink: 0,
              colorFilter: palette.creatureFilter,
            ),
          ),
          Positioned.fill(
            child: streakPotFront(
              size,
              _potStyle,
              colorFilter: palette.soilFilter,
            ),
          ),
        ],
      ),
    );
  }

  Widget _plantForScene(
    PlantStage stage,
    double plantSize,
    _StreakScenePalette palette,
  ) {
    // Idle: the self-animating layered plant (soil static, body sways with
    // cooldown, side leaves flutter, eyes blink). On stage-up: a grow-pop
    // crossfade between frozen poses, both scaled into this planted scene.
    if (_fromIndex == null) {
      return StreakPlant(
        key: ValueKey('${stage.image}-$plantSize'),
        stage: stage,
        size: plantSize,
        colorFilter: palette.creatureFilter,
        soilColorFilter: palette.soilFilter,
        potStyle: _potStyle,
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
              Opacity(
                opacity: 1 - g,
                child: _frozenPlant(from, fromSize, palette),
              ),
              Opacity(
                opacity: g,
                child: Transform.scale(
                  scale: 0.5 + 0.5 * eased,
                  alignment: Alignment.bottomCenter,
                  child: _frozenPlant(stage, plantSize, palette),
                ),
              ),
              // Level-up sparkle celebration flung out with the pop.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: SparkleBurstPainter(
                      p: g,
                      seed: _fromIndex! + 5,
                      count: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _plantedScene(
    PlantStage stage,
    _StreakScenePalette palette, {
    required Widget weekStrip,
    required bool lightText,
    required bool night,
    required bool raining,
    required double rainT,
    required double rainIntensity,
  }) {
    final stageIndex = PlantStage.all.indexOf(stage);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxPlantSize = math.min(205.0, constraints.maxWidth * 0.56);
        final plantSize = math.min(stage.size * 1.46, maxPlantSize);

        return SizedBox(
          height: 268,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -20,
                right: -20,
                bottom: 0,
                height: 238,
                child: _groundAsset(
                  'streak_ground_back',
                  colorFilter: palette.groundBackFilter,
                ),
              ),
              Positioned(
                left: -24,
                right: -24,
                bottom: 0,
                height: 232,
                child: _groundAsset(
                  'streak_ground_front',
                  colorFilter: palette.groundFrontFilter,
                ),
              ),
              Positioned(
                left: -24,
                right: -24,
                bottom: 0,
                height: 232,
                child: _groundAsset(
                  'streak_ground_front_ovals',
                  colorFilter: palette.groundFrontFilter,
                ),
              ),
              Positioned(
                // Lift the creature and pot toward the ground ovals, leaving
                // the larger illustrated grass backdrop in place.
                bottom: 146,
                child: _plantForScene(stage, plantSize, palette),
              ),
              // Ambient life around the plant: fireflies after dark; pollen
              // motes — plus butterflies once the plant is grown — by day.
              // Rain keeps the scene to just the weather.
              if (!raining)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 88,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _ambient,
                      builder: (context, _) => CustomPaint(
                        painter: night
                            ? FirefliesPainter(_ambient.value, count: 7)
                            : MotesPainter(_ambient.value, count: 10),
                        foregroundPainter: !night && stageIndex >= 3
                            ? ButterfliesPainter(_ambient.value, flapCycles: 48)
                            : null,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              if (raining)
                Positioned(
                  left: -20,
                  right: -20,
                  top: 0,
                  bottom: 70,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _StreakRainPainter(
                        t: rainT,
                        lightText: lightText,
                        intensity: rainIntensity,
                      ),
                    ),
                  ),
                ),
              // Tapping the day strip pops up the full streak calendar.
              Positioned(
                left: 8,
                right: 8,
                bottom: 64,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showStreakCalendarSheet(context),
                  child: Container(
                    // A soft frosted panel behind the whole strip lifts the
                    // day labels + dots off the busy weather art so they stay
                    // legible. Translucent (not solid) so the scene reads
                    // through it; a hairline border defines the edge.
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                    decoration: BoxDecoration(
                      color: lightText
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: lightText
                            ? Colors.white.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: weekStrip,
                  ),
                ),
              ),
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
    final frozen = _frozenDays();
    final freezes = widget.streak?.freezes ?? 0;
    final shielded = widget.streak?.freezeActive ?? false;
    final stage = PlantStage.forStreak(current);
    final headline = current == 0 ? 'Start your streak' : '$current day streak';
    final topInset = MediaQuery.of(context).padding.top;
    final now = DateTime.now();
    final iconCode = widget.weather?.iconCode ?? _streakSceneIcon(now);
    final gradientColors = WeatherBackdrop.gradientColors(iconCode, now);
    final lightText = _streakUsesLightText(iconCode, now);
    final night = iconCode.endsWith('n') || now.hour < 5 || now.hour >= 21;
    final raining = _streakUsesRain(iconCode);
    var palette = _StreakScenePalette.forTime(now);
    if (raining && !night) {
      palette = _StreakScenePalette.rainDay();
    }
    final rainIntensity = widget.weather?.rainIntensity ?? 1.0;
    final titleColor = lightText ? Colors.white : AppColors.textPrimary;
    final secondaryColor = lightText
        ? Colors.white.withValues(alpha: 0.84)
        : AppColors.textSecondary;

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
            WeatherSceneArt(iconCode: iconCode, rainIntensity: rainIntensity),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: lightText ? 0.34 : 0.10),
                      Colors.black.withValues(alpha: lightText ? 0.18 : 0.04),
                      Colors.transparent,
                      const Color(0xFFD8EFD8).withValues(alpha: 0.22),
                    ],
                    stops: const [0.0, 0.30, 0.58, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              // Sits behind the status bar (no app bar); pad content clear of it.
              // Extra bottom padding lets the task panel overlap the planted ground.
              padding: EdgeInsets.fromLTRB(20, topInset + 26, 20, 0),
              child: Column(
                children: [
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: current == 0 ? 30 : 34,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      shadows: lightText ? _kStreakTextShadow : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lv ${PlantStage.all.indexOf(stage) + 1} · ${stage.name}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      shadows: lightText ? _kStreakTextShadow : null,
                    ),
                  ),
                  if (freezes > 0 || shielded) ...[
                    const SizedBox(height: 8),
                    _FreezeChip(
                      count: freezes,
                      shielded: shielded,
                      lightText: lightText,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // XP-style bar to the next growth stage.
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => _StageProgress(
                      streak: current,
                      stage: stage,
                      lightText: lightText,
                      shine: _pulse.value,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (raining)
                    AnimatedBuilder(
                      animation: _rain,
                      builder: (context, _) => _plantedScene(
                        stage,
                        palette,
                        lightText: lightText,
                        night: night,
                        raining: true,
                        rainT: _rain.value,
                        rainIntensity: rainIntensity,
                        weekStrip: _buildWeekStrip(
                          lit,
                          frozen,
                          secondaryColor,
                          titleColor,
                        ),
                      ),
                    )
                  else
                    _plantedScene(
                      stage,
                      palette,
                      lightText: lightText,
                      night: night,
                      raining: false,
                      rainT: 0,
                      rainIntensity: rainIntensity,
                      weekStrip: _buildWeekStrip(
                        lit,
                        frozen,
                        secondaryColor,
                        titleColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rain that falls through the planted streak scene and stops at the grass.
class _StreakRainPainter extends CustomPainter {
  final double t;
  final bool lightText;
  final double intensity;

  const _StreakRainPainter({
    required this.t,
    required this.lightText,
    required this.intensity,
  });

  static const List<Offset> _puddles = [
    Offset(0.24, 0.86),
    Offset(0.48, 0.91),
    Offset(0.70, 0.86),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Shared parallax rain sheets, with splash rings blipping at the grass.
    paintRain(canvas, size, t, intensity, splashLine: 0.88);

    final puddlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: lightText ? 0.20 : 0.16);
    final shimmerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFD9F3FF).withValues(alpha: 0.18);

    for (var i = 0; i < _puddles.length; i++) {
      final p = _puddles[i];
      final pulse = 0.5 + 0.5 * math.sin((t * 2 * math.pi) + i * 1.7);
      final center = Offset(size.width * p.dx, size.height * p.dy);
      final width = 24 + pulse * 8;
      final height = 5 + pulse * 2;
      final rect = Rect.fromCenter(
        center: center,
        width: width,
        height: height,
      );
      canvas.drawOval(rect, puddlePaint);
      canvas.drawArc(
        rect.deflate(3),
        math.pi * 0.08,
        math.pi * 0.72,
        false,
        shimmerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_StreakRainPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.lightText != lightText ||
      oldDelegate.intensity != intensity;
}

/// Rolling 7-day strip centered on today (index 3): a two-letter weekday
/// label above a circle. Each cared-for day is a blue water drop; consecutive
/// cared-for days are joined by a blue bar. Days in a save-shielded gap render
/// as ice dots.
class _WeekStrip extends StatelessWidget {
  final List<bool> lit;
  final List<bool> frozen;
  final Color labelColor;
  final Color todayLabelColor;

  /// First day of the 7-day window (today − 3), so today lands at index 3.
  /// Derived from the server date by the parent so labels and lit dots stay
  /// aligned with the care days.
  final DateTime start;

  /// 0–1 glow strength for today's uncared dot (0 = no pulse).
  final double todayPulse;

  const _WeekStrip({
    required this.lit,
    required this.start,
    this.frozen = const [false, false, false, false, false, false, false],
    this.labelColor = AppColors.textSecondary,
    this.todayLabelColor = AppColors.textPrimary,
    this.todayPulse = 0,
  });

  // Two-letter weekday labels, indexed by DateTime.weekday - 1 (Mon = 0).
  static const _initials = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  @override
  Widget build(BuildContext context) {
    // Rolling window with today centered (index 3), Duolingo-style: the
    // three days just lived on the left, the three ahead on the right.
    return Row(
      children: List.generate(7, (i) {
        final day = start.add(Duration(days: i));
        final isToday = i == 3;
        final litHere = lit[i];
        // Frozen days count as part of the chain, so connectors span them.
        bool inChain(int j) => lit[j] || frozen[j];
        final chainHere = inChain(i);
        final litLeft = i > 0 && chainHere && inChain(i - 1);
        final litRight = i < 6 && chainHere && inChain(i + 1);
        return Expanded(
          child: _DayCell(
            label: _initials[day.weekday - 1],
            index: i,
            lit: litHere,
            frozen: frozen[i],
            isToday: isToday,
            litLeft: litLeft,
            litRight: litRight,
            labelColor: labelColor,
            todayLabelColor: todayLabelColor,
            pulse: isToday ? todayPulse : 0,
          ),
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String label;
  final int index; // Mon = 0 … Sun = 6, staggers the pop-in entrance
  final bool lit;
  final bool frozen;
  final bool isToday;
  final bool litLeft;
  final bool litRight;
  final Color labelColor;
  final Color todayLabelColor;

  /// 0–1 breathing-glow strength for an uncared today dot.
  final double pulse;

  static const double _d = 26; // circle diameter
  static const double _barH = 7; // connector thickness
  // Lighter ice tint for shielded days, distinct from the cared water-blue.
  static const Color _iceFill = Color(0xFF9CCFEE);

  const _DayCell({
    required this.label,
    required this.index,
    required this.lit,
    this.frozen = false,
    required this.isToday,
    required this.litLeft,
    required this.litRight,
    required this.labelColor,
    required this.todayLabelColor,
    this.pulse = 0,
  });

  // Blue connecting line, shown only between two adjacent cared-for days.
  Widget _bar(bool on) => Expanded(
    child: on
        ? Container(height: _barH, color: _kWater)
        : const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    final textColor = isToday ? todayLabelColor : labelColor;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 11.5,
            // Heavier weight + wider tracking reads clearly against the sky;
            // today stays boldest as the strip's anchor.
            fontWeight: isToday ? FontWeight.w900 : FontWeight.w800,
            letterSpacing: 0.3,
            shadows: textColor.computeLuminance() > 0.65
                ? _kStreakTextShadow
                : null,
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: _d,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(children: [_bar(litLeft), _bar(litRight)]),
              // Dots pop in left→right with a small overshoot on first build.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Interval(
                  math.min(index * 0.09, 0.6),
                  1,
                  curve: Curves.easeOutBack,
                ),
                builder: (context, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: Container(
                  width: _d,
                  height: _d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lit ? _kWater : (frozen ? _iceFill : Colors.white),
                    border: Border.all(
                      color: lit
                          ? _kWater
                          : frozen
                          ? _iceFill
                          : (isToday ? _kWater : AppColors.cardBorder),
                      width: isToday && !lit ? 2 : 0.8,
                    ),
                    // Soft breathing glow inviting today's first care action.
                    boxShadow: (isToday && !lit && pulse > 0)
                        ? [
                            BoxShadow(
                              color: _kWater.withValues(alpha: 0.45 * pulse),
                              blurRadius: 6 + 6 * pulse,
                              spreadRadius: 1 + 1.5 * pulse,
                            ),
                          ]
                        : null,
                  ),
                  child: lit
                      ? const Icon(
                          Icons.water_drop_rounded,
                          color: Colors.white,
                          size: 15,
                        )
                      : frozen
                      ? const Icon(
                          Icons.ac_unit_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small pill under the streak headline showing banked streak saves, and —
/// while a save is actively holding a gap — a "shielded" callout.
class _FreezeChip extends StatelessWidget {
  final int count;
  final bool shielded;
  final bool lightText;
  const _FreezeChip({
    required this.count,
    required this.shielded,
    required this.lightText,
  });

  static const Color _ice = Color(0xFF9CCFEE);

  @override
  Widget build(BuildContext context) {
    final label = shielded
        ? 'Streak shielded · $count ${count == 1 ? 'save' : 'saves'} left'
        : '$count streak ${count == 1 ? 'save' : 'saves'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: lightText
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _ice.withValues(alpha: 0.7), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.ac_unit_rounded, color: Color(0xFF4F9FD9), size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: lightText ? Colors.white : AppColors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              shadows: lightText ? _kStreakTextShadow : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress bar to the next growth stage: an animated fill with a periodic
/// shine sweep, labelled "streak / threshold days to `stage`" (or a bloomed
/// callout at max stage). Counts total streak days — not days within the
/// current stage — so evolving never resets it to empty. [shine] is a
/// repeating 0–1 driver.
class _StageProgress extends StatelessWidget {
  final int streak;
  final PlantStage stage;
  final bool lightText;
  final double shine;

  const _StageProgress({
    required this.streak,
    required this.stage,
    required this.lightText,
    required this.shine,
  });

  static const double _w = 190;
  static const double _h = 10;

  @override
  Widget build(BuildContext context) {
    final next = PlantStage.next(stage);
    // Cumulative count (total streak days vs the next stage's threshold), so
    // the bar never snaps back to empty on the day the creature evolves —
    // `done` always matches the headline day count.
    final done = next == null ? 1 : streak;
    final span = next == null ? 1 : next.minDays;
    final frac = (done / span).clamp(0.0, 1.0);
    final label = next == null
        ? 'Fully bloomed!'
        : '$done / $span days to ${next.name}';
    final trackColor = lightText
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.10);
    final textColor = lightText
        ? Colors.white.withValues(alpha: 0.9)
        : AppColors.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _w,
          height: _h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_h),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: trackColor),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: frac),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, f, child) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: f,
                    child: child,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6FCF6A), Color(0xFFB9E88B)],
                      ),
                      borderRadius: BorderRadius.circular(_h),
                    ),
                    // The shine sweeps across the filled part, then rests
                    // for the remainder of the pulse cycle.
                    child: frac > 0.05 && shine < 0.45
                        ? Align(
                            alignment: Alignment(
                              -1.3 + 2.6 * (shine / 0.45),
                              0,
                            ),
                            child: Container(
                              width: 12,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (next == null) ...[
              Icon(Icons.auto_awesome, size: 12, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                shadows: lightText ? _kStreakTextShadow : null,
              ),
            ),
          ],
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

// ─── Staggered entrance ────────────────────────────────────────

/// One-shot slide-up + fade for panel content on first build. Later items
/// start slightly after earlier ones via an [Interval], giving the panel a
/// gentle cascade instead of popping in all at once.
class _Entrance extends StatelessWidget {
  final int index;
  final Widget child;
  const _Entrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.14).clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Interval(delay, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ─── Task category card ────────────────────────────────────────

class _TaskCard extends StatefulWidget {
  final CareActivity activity;
  final int count;
  final VoidCallback onTap;
  const _TaskCard({
    required this.activity,
    required this.count,
    required this.onTap,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _pressed = false;

  CareActivity get activity => widget.activity;
  int get count => widget.count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
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
          // The check pops in with an elastic overshoot — a small celebration
          // for having tended the whole garden.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: Container(
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

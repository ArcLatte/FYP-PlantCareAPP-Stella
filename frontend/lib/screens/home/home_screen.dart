import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../services/weather_controller.dart';
import '../../services/weather_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/tier_frame.dart';
import '../../widgets/weather_backdrop.dart';
import '../../widgets/weather_scene_art.dart';
import '../../widgets/xp_toast.dart';

const _kAllFilter = '__all__';
const _kUnsortedFilter = '__unsorted__';
const _kWeatherTextShadow = [
  Shadow(color: Color(0x660B1424), blurRadius: 8, offset: Offset(0, 1)),
];

/// Status-based filter applied on top of the location chips.
enum _StatusFilter { all, needsWater, needsAttention, healthy }

extension _StatusFilterLabel on _StatusFilter {
  String get label {
    switch (this) {
      case _StatusFilter.all:
        return 'All plants';
      case _StatusFilter.needsWater:
        return 'Needs water';
      case _StatusFilter.needsAttention:
        return 'Needs attention';
      case _StatusFilter.healthy:
        return 'Healthy';
    }
  }

  IconData get icon {
    switch (this) {
      case _StatusFilter.all:
        return Icons.grid_view_rounded;
      case _StatusFilter.needsWater:
        return Icons.water_drop_outlined;
      case _StatusFilter.needsAttention:
        return Icons.warning_amber_rounded;
      case _StatusFilter.healthy:
        return Icons.favorite_rounded;
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Plant> _plants = [];
  bool _isLoadingPlants = true;
  String _username = '';
  String? _tier;
  Weather? _weather;
  final WeatherController _weatherController = WeatherController.instance;
  String _filter = _kAllFilter;
  _StatusFilter _statusFilter = _StatusFilter.all;

  final ScrollController _scrollController = ScrollController();
  // True once the weather header has scrolled out from behind the status bar,
  // at which point the status-bar icons flip from white to dark.
  bool _headerCollapsed = false;
  static const double _headerCollapseThreshold = 140;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _weather = _weatherController.weather;
    _weatherController.addListener(_onWeatherChanged);
    _weatherController.start();
    _loadAll();
    // Flush the daily-login XP toast (if any) once the first frame is
    // mounted, so the celebration lands on home rather than the login screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) XpToast.flush(context);
    });
  }

  @override
  void dispose() {
    _weatherController.removeListener(_onWeatherChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onWeatherChanged() {
    if (mounted) setState(() => _weather = _weatherController.weather);
  }

  void _onScroll() {
    final collapsed = _scrollController.offset > _headerCollapseThreshold;
    if (collapsed != _headerCollapsed) {
      setState(() => _headerCollapsed = collapsed);
    }
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
        () => _username = prefs.getString(AppConstants.usernameKey) ?? '',
      );
    }
    await Future.wait([_loadPlants(), _loadWeather(), _loadTier()]);
  }

  /// Fetch the user's tier so the header avatar can wear its frame.
  /// Non-critical — a failure just leaves the avatar unframed.
  Future<void> _loadTier() async {
    try {
      final profile = await ApiService.getProfile();
      if (mounted) setState(() => _tier = profile.tier);
    } catch (_) {}
  }

  Future<void> _loadPlants() async {
    if (mounted) setState(() => _isLoadingPlants = true);
    try {
      final plants = await ApiService.getPlants();
      if (!mounted) return;
      setState(() {
        _plants = plants;
        _isLoadingPlants = false;
      });
      // Rebuild the local watering reminders off the fresh schedule.
      NotificationService.scheduleCareReminders(plants);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPlants = false);
      AppSnackBar.error(
        context,
        e,
        fallback: 'Could not load your plants. Please try again.',
      );
    }
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    await _weatherController.refresh(forceRefresh: forceRefresh);
  }

  Future<void> _onRefresh() async {
    await Future.wait([_loadPlants(), _loadWeather(forceRefresh: true)]);
  }

  Future<void> _waterPlant(Plant plant) async {
    try {
      final updated = await ApiService.waterPlant(plant.id);
      if (!mounted) return;
      setState(() {
        final i = _plants.indexWhere((p) => p.id == updated.id);
        if (i != -1) _plants[i] = updated;
      });
      AppSnackBar.success(context, '${plant.name} watered');
      XpToast.flush(context);
      NotificationService.scheduleCareReminders(_plants);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          e,
          fallback: 'Could not log watering. Please try again.',
        );
      }
    }
  }

  Future<void> _fertilizePlant(Plant plant) async {
    try {
      final updated = await ApiService.fertilizePlant(plant.id);
      if (!mounted) return;
      setState(() {
        final i = _plants.indexWhere((p) => p.id == updated.id);
        if (i != -1) _plants[i] = updated;
      });
      AppSnackBar.success(context, '${plant.name} fertilized');
      XpToast.flush(context);
      NotificationService.scheduleCareReminders(_plants);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          e,
          fallback: 'Could not log fertilizing. Please try again.',
        );
      }
    }
  }

  Future<void> _mistPlant(Plant plant) async {
    try {
      final updated = await ApiService.mistPlant(plant.id);
      if (!mounted) return;
      setState(() {
        final i = _plants.indexWhere((p) => p.id == updated.id);
        if (i != -1) _plants[i] = updated;
      });
      AppSnackBar.success(context, '${plant.name} misted');
      XpToast.flush(context);
      NotificationService.scheduleCareReminders(_plants);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          e,
          fallback: 'Could not log misting. Please try again.',
        );
      }
    }
  }

  /// Long-press a plant tile for quick care. Mirrors the detail page's "Log
  /// care" sheet — Water always, Fertilize / Mist only when the species
  /// schedules them — plus a shortcut into a health scan.
  Future<void> _openQuickActions(Plant plant) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final rows = <Widget>[
          _CareActionRow(
            icon: Icons.water_drop_rounded,
            color: const Color(0xFF4F9FD9),
            label: 'Water',
            subtitle:
                'Next ${_careNext(plant.daysUntilWater)} · Last ${_careLast(plant.lastWatered)}',
            overdue: (plant.daysUntilWater ?? 1) <= 0,
            onTap: () {
              Navigator.pop(ctx);
              _waterPlant(plant);
            },
          ),
        ];
        if (plant.daysUntilFertilizer != null) {
          rows.add(
            _CareActionRow(
              icon: Icons.compost_rounded,
              color: AppColors.amber,
              label: 'Fertilize',
              subtitle:
                  'Next ${_careNext(plant.daysUntilFertilizer)} · Last ${_careLast(plant.lastFertilized)}',
              overdue: plant.daysUntilFertilizer! <= 0,
              onTap: () {
                Navigator.pop(ctx);
                _fertilizePlant(plant);
              },
            ),
          );
        }
        if (plant.daysUntilMisting != null) {
          rows.add(
            _CareActionRow(
              icon: Icons.cloud_rounded,
              color: const Color(0xFF26A69A),
              label: 'Mist',
              subtitle:
                  'Next ${_careNext(plant.daysUntilMisting)} · Last ${_careLast(plant.lastMisted)}',
              overdue: plant.daysUntilMisting! <= 0,
              onTap: () {
                Navigator.pop(ctx);
                _mistPlant(plant);
              },
            ),
          );
        }
        rows.add(
          _CareActionRow(
            icon: Icons.center_focus_strong_rounded,
            color: const Color(0xFF7C6CD6),
            label: 'Scan health',
            subtitle: 'Check leaves for disease',
            overdue: false,
            isNav: true,
            onTap: () {
              Navigator.pop(ctx);
              context.push('/scan/${plant.id}').then((_) {
                if (mounted) _loadPlants();
              });
            },
          ),
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    plant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                for (final row in rows) row,
              ],
            ),
          ),
        );
      },
    );
  }

  /// "in 3d" / "tomorrow" / "due now" for a care countdown.
  String _careNext(int? days) {
    if (days == null) return '—';
    if (days <= 0) return 'due now';
    if (days == 1) return 'tomorrow';
    return 'in ${days}d';
  }

  /// "today" / "yesterday" / "5d ago" / "never" for a last-care timestamp.
  String _careLast(DateTime? dt) {
    if (dt == null) return 'never';
    final days = DateTime.now().difference(dt).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '${days}d ago';
  }

  Future<void> _openAddPlant() async {
    await context.push('/plants/add');
    if (!mounted) return;
    _loadPlants();
    XpToast.flush(context);
  }

  // ───────── Care-due sheet (bell) ─────────

  /// Plants with any care activity due now.
  List<Plant> get _dueToday => _plants
      .where((p) => p.needsWater || p.needsFertilizer || p.needsMisting)
      .toList();

  // Kept as a compact fallback for older deep links; the header bell now opens
  // the full Care alerts page.
  // ignore: unused_element
  Future<void> _openCareSheet() async {
    final due = _dueToday;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Today's care",
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (due.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 44,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'All caught up — nothing due today!',
                          style: Theme.of(sheetContext).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in due)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (p.needsWater) 'Water',
                              if (p.needsFertilizer) 'Fertilize',
                              if (p.needsMisting) 'Mist',
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                          ),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await context.push('/plants/${p.id}');
                            _loadPlants();
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────── Filter helpers ─────────

  List<String> get _availableFilters {
    final seen = <String>{};
    var hasUnsorted = false;
    for (final p in _plants) {
      if (p.location.isEmpty) {
        hasUnsorted = true;
      } else {
        seen.add(p.location);
      }
    }
    final list = seen.toList()..sort();
    return [_kAllFilter, ...list, if (hasUnsorted) _kUnsortedFilter];
  }

  List<Plant> get _filteredPlants {
    // First narrow by location chip, then by status filter.
    Iterable<Plant> result = _plants;
    if (_filter == _kUnsortedFilter) {
      result = result.where((p) => p.location.isEmpty);
    } else if (_filter != _kAllFilter) {
      result = result.where((p) => p.location == _filter);
    }
    result = result.where(_matchesStatus);
    return result.toList();
  }

  bool _matchesStatus(Plant p) {
    switch (_statusFilter) {
      case _StatusFilter.all:
        return true;
      case _StatusFilter.needsWater:
        return p.needsWater;
      case _StatusFilter.needsAttention:
        return p.latestHealth == 'diseased';
      case _StatusFilter.healthy:
        return p.latestHealth == 'healthy';
    }
  }

  int _statusCount(_StatusFilter f) {
    switch (f) {
      case _StatusFilter.all:
        return _plants.length;
      case _StatusFilter.needsWater:
        return _plants.where((p) => p.needsWater).length;
      case _StatusFilter.needsAttention:
        return _plants.where((p) => p.latestHealth == 'diseased').length;
      case _StatusFilter.healthy:
        return _plants.where((p) => p.latestHealth == 'healthy').length;
    }
  }

  Future<void> _openFilterSheet() async {
    final selected = await showModalBottomSheet<_StatusFilter>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grab handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Filter by status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final f in _StatusFilter.values)
                  _FilterOption(
                    icon: f.icon,
                    label: f.label,
                    count: _statusCount(f),
                    selected: f == _statusFilter,
                    onTap: () => Navigator.pop(sheetContext, f),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _statusFilter = selected);
    }
  }

  String _filterLabel(String f) {
    if (f == _kAllFilter) return 'All Plants (${_plants.length})';
    if (f == _kUnsortedFilter) return 'Unsorted';
    return f;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    // _filteredPlants walks the plant list; compute once per build instead
    // of re-filtering for the empty-check, childCount, and item builder.
    final filtered = _filteredPlants;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: _headerCollapsed
            ? Brightness.dark
            : Brightness.light,
        statusBarBrightness: _headerCollapsed
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 76),
          child: FloatingActionButton(
            onPressed: _openAddPlant,
            backgroundColor: AppColors.primary,
            elevation: 4,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 460,
              child: ColoredBox(
                color: WeatherBackdrop.gradientColors(
                  _weather?.iconCode ?? '01d',
                ).first,
              ),
            ),
            RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Weather header + the "Your Garden" panel live in ONE sliver so
                  // the panel paints ON TOP of the weather (the viewport paints an
                  // earlier sliver above later ones, which would otherwise let the
                  // weather cover the panel). The panel has a rounded top and is
                  // pulled up to overlap the weather, so the blue shows through its
                  // corners. Panel colour == scaffold colour, so the space it
                  // vacates below (from the translate) blends into the grid.
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildWeatherCard(),
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                            ),
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                _buildGardenHeader(),
                                _buildFilterChips(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoadingPlants)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.72,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => const PlantCardSkeleton(),
                          childCount: 4,
                        ),
                      ),
                    )
                  else if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.72,
                            ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final plant = filtered[i];
                          return _PlantGridCard(
                            plant: plant,
                            onTap: () async {
                              await context.push('/plants/${plant.id}');
                              _loadPlants();
                            },
                            onLongPress: () => _openQuickActions(plant),
                          );
                        }, childCount: filtered.length),
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

  // ───────── Weather card ─────────

  /// Full-section watercolor weather scene, composited from the SVGs in
  /// `assets/weather/` by [WeatherSceneArt] (sky wash, sun/moon, drifting
  /// clouds, rain/snow… per condition).
  Widget _weatherBackground() {
    final w = _weather;
    if (w == null) return const SizedBox.shrink();
    // Freeze the animation once the header has scrolled out of view.
    return WeatherSceneArt(
      iconCode: w.iconCode,
      rainIntensity: w.rainIntensity,
      paused: _headerCollapsed,
    );
  }

  Widget _buildWeatherCard() {
    final statusBarInset = MediaQuery.of(context).padding.top;
    // Gradient tracks time of day (dawn/day/sunset/night), nudged by the
    // weather icon's day/night flag once a report is loaded.
    final iconCode = _weather?.iconCode ?? '01d';
    final weatherGroup = iconCode.length >= 2 ? iconCode.substring(0, 2) : '01';
    final hour = DateTime.now().hour;
    final isNight = iconCode.endsWith('n') || hour < 5 || hour >= 21;
    final isWet =
        weatherGroup == '09' || weatherGroup == '10' || weatherGroup == '11';
    final gradientColors = WeatherBackdrop.gradientColors(iconCode);
    final topScrimAlpha = isNight ? 0.24 : (isWet ? 0.16 : 0.12);
    final midScrimAlpha = isNight ? 0.14 : (isWet ? 0.08 : 0.06);
    final bottomScrimAlpha = isNight ? 0.16 : (isWet ? 0.12 : 0.08);
    final statFill = const Color(
      0xFF243A4D,
    ).withValues(alpha: isNight ? 0.52 : 0.48);
    final statBorder = Colors.white.withValues(alpha: isNight ? 0.14 : 0.22);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Slab extending above the header. It scrolls with the header,
        // so pulling down to refresh fills the overscroll gap with the
        // gradient's top colour instead of the bare scaffold grey. Off-screen
        // (clipped by the viewport) during normal scroll.
        Positioned(
          top: -600,
          left: 0,
          right: 0,
          height: 600,
          child: ColoredBox(color: gradientColors.first),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
              stops: const [0.0, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Full-section animated weather backdrop (behind the content).
              _weatherBackground(),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withValues(alpha: topScrimAlpha),
                        Colors.black.withValues(alpha: midScrimAlpha),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.46, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: bottomScrimAlpha),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.58],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: statusBarInset + 16,
                  left: 20,
                  right: 20,
                  bottom: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_greeting()},',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  shadows: _kWeatherTextShadow,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _username.isEmpty ? 'Plant lover' : _username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  shadows: _kWeatherTextShadow,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Profile avatar → Profile tab. Wears the tier
                            // frame once the profile fetch lands.
                            GestureDetector(
                              onTap: () => context.go('/profile'),
                              child: _tier == null
                                  ? _buildHeaderAvatar(40)
                                  : TierFrame(
                                      tier: _tier!,
                                      size: 52,
                                      child: _buildHeaderAvatar(null),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            // Notification bell → today's care sheet. Dot
                            // appears when anything is due.
                            GestureDetector(
                              onTap: () => context
                                  .push('/notifications')
                                  .then((_) => _loadPlants()),
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    if (_dueToday.isNotEmpty)
                                      Positioned(
                                        right: -1,
                                        top: -1,
                                        child: Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: AppColors.amber,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _weather?.cityName ?? 'Locating…',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            shadows: _kWeatherTextShadow,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _weather?.tempDisplay ?? '—°C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            shadows: _kWeatherTextShadow,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_weather != null)
                                Icon(
                                  _weather!.icon,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                _weather?.condition ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  shadows: _kWeatherTextShadow,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: statFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statBorder),
                      ),
                      child: Row(
                        children: [
                          _WeatherStat(
                            icon: Icons.water_drop_outlined,
                            label: 'HUMIDITY',
                            value: _weather == null
                                ? '—'
                                : '${_weather!.humidity}%',
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: Colors.white24,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          _WeatherStat(
                            icon: Icons.wb_sunny_outlined,
                            label: 'UV INDEX',
                            value: _weather?.uvLevel ?? '—',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Circular initial avatar for the weather header. [size] is null when
  /// wrapped by [TierFrame], which sizes the child via its padding instead.
  Widget _buildHeaderAvatar(double? size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white24,
        shape: BoxShape.circle,
      ),
      child: _username.isEmpty
          ? const Icon(Icons.person_rounded, color: Colors.white, size: 22)
          : Text(
              _username[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  // ───────── Garden header + filter chips ─────────

  Widget _buildGardenHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Your Garden', style: Theme.of(context).textTheme.titleLarge),
          _FilterButton(
            active: _statusFilter != _StatusFilter.all,
            label: _statusFilter == _StatusFilter.all
                ? 'Filter'
                : _statusFilter.label,
            onTap: _openFilterSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = _availableFilters;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          final selected = f == _filter;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.textPrimary : AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.cardBorder,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _filterLabel(f),
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────── Empty state ─────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.eco_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            _plants.isEmpty ? 'No plants yet' : 'No matches',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _plants.isEmpty
                ? 'Tap the + button in the bottom right to add your first plant.'
                : 'No plants match this filter. Try a different one.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openAddPlant,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Plant'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(160, 48)),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────

/// The pill next to "Your Garden". Tinted when a status filter is active.
class _FilterButton extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;
  const _FilterButton({
    required this.active,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              Icons.tune_rounded,
              color: active ? Colors.white : AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : AppColors.primary,
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

/// A single row inside the filter bottom sheet.
class _FilterOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterOption({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _WeatherStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlantGridCard extends StatelessWidget {
  final Plant plant;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _PlantGridCard({
    required this.plant,
    required this.onTap,
    required this.onLongPress,
  });

  /// "Species · Location" under the name — whichever parts exist.
  String _speciesLocation() {
    final parts = [
      plant.species,
      plant.location,
    ].where((s) => s.trim().isNotEmpty).toList();
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    plant.photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: plant.photoUrl!,
                            fit: BoxFit.cover,
                            // Grid tiles are ~half screen width; decoding at
                            // 400px instead of full camera res slashes memory
                            // and jank on scroll.
                            memCacheWidth: 400,
                            placeholder: (c, _) => Container(
                              color: AppColors.primary.withValues(alpha: 0.08),
                            ),
                            errorWidget: (c, _, _) => Container(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              child: const Icon(
                                Icons.eco_rounded,
                                color: AppColors.primary,
                                size: 36,
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: AppColors.primary,
                              size: 36,
                            ),
                          ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (plant.latestHealth != null)
                            _StatusBadge(
                              text: plant.latestHealth == 'healthy'
                                  ? 'Healthy'
                                  : 'Treat',
                              color: plant.latestHealth == 'healthy'
                                  ? AppColors.success
                                  : AppColors.amber,
                            ),
                          if (plant.needsWater) ...[
                            const SizedBox(height: 4),
                            const _StatusBadge(
                              text: 'Water',
                              color: Color(0xFF4F9FD9),
                              icon: Icons.water_drop_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Text area — species + location under the name, then the plant's
            // current status where the care icons used to sit.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _speciesLocation(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PlantStatusChip(plant: plant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _StatusBadge({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          if (icon != null) ...[
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// The plant's current status, shown as a tinted pill under the species line.
/// Priority: treatment > water > healthy, so a diseased-and-thirsty plant
/// reads "Needs treatment" (amber) rather than a misleading blue.
class _PlantStatusChip extends StatelessWidget {
  final Plant plant;
  const _PlantStatusChip({required this.plant});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String text;
    final Color color;
    if (plant.latestHealth == 'diseased') {
      icon = Icons.warning_amber_rounded;
      text = 'Needs treatment';
      color = AppColors.amber;
    } else if (plant.needsWater) {
      icon = Icons.water_drop_rounded;
      text = 'Needs water';
      color = const Color(0xFF4F9FD9);
    } else if (plant.latestHealth == 'healthy') {
      icon = Icons.check_circle_rounded;
      text = 'Healthy';
      color = AppColors.primary;
    } else {
      icon = Icons.check_circle_rounded;
      text = 'All good';
      color = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row in the long-press quick-actions sheet, styled to match the detail
/// page's "Log care" sheet: tinted icon tile, label + subtitle, and a trailing
/// affordance — a coloured `+` for care actions, or a chevron when [isNav].
class _CareActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final bool overdue;
  final bool isNav;
  final VoidCallback onTap;

  const _CareActionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.overdue,
    required this.onTap,
    this.isNav = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: overdue
                          ? AppColors.amber
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: overdue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (isNav)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 24,
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

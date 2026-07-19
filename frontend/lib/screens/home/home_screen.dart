import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../services/api_service.dart';
import '../../services/app_badge_controller.dart';
import '../../services/app_refresh_bus.dart';
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
  Shadow(color: Color(0x8C0B1424), blurRadius: 3, offset: Offset(0, 1)),
  Shadow(color: Color(0x730B1424), blurRadius: 10, offset: Offset(0, 2)),
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
  String? _avatarUrl;
  Weather? _weather;
  final WeatherController _weatherController = WeatherController.instance;
  String _filter = _kAllFilter;
  _StatusFilter _statusFilter = _StatusFilter.all;
  final TextEditingController _gardenSearchController = TextEditingController();
  String _gardenQuery = '';

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
    _gardenSearchController.dispose();
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

  /// Fetch the profile so the header avatar can show the user's photo and
  /// wear its tier frame. Non-critical — a failure just leaves the avatar as
  /// the initial fallback, unframed.
  Future<void> _loadTier() async {
    try {
      final profile = await ApiService.getProfile();
      if (mounted) {
        setState(() {
          _tier = profile.tier;
          _avatarUrl = profile.avatarUrl;
        });
      }
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
      // Rebuild local care reminders from the fresh schedule.
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
    await Future.wait([
      _loadPlants(),
      _loadWeather(forceRefresh: true),
      _loadTier(), // pick up avatar / tier changes made on the profile
    ]);
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
      AppRefreshBus.plantsChanged();
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
      AppRefreshBus.plantsChanged();
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
      AppRefreshBus.plantsChanged();
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
              context.push('/scan').then((_) {
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
    // Narrow by location, status, then the garden search query.
    Iterable<Plant> result = _plants;
    if (_filter == _kUnsortedFilter) {
      result = result.where((p) => p.location.isEmpty);
    } else if (_filter != _kAllFilter) {
      result = result.where((p) => p.location == _filter);
    }
    result = result.where(_matchesStatus);
    final query = _gardenQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.species.toLowerCase().contains(query) ||
            p.location.toLowerCase().contains(query);
      });
    }
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
        // No backdrop behind the scroll view: the header's own overscroll slab
        // covers pull-to-refresh, and anything painted here would bleed
        // through behind the plant grid below the "Your Garden" panel.
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            controller: _scrollController,
            // Keep the weather scene anchored while pulling to refresh. The
            // RefreshIndicator still receives overscroll notifications and
            // shows its spinner, but the page itself no longer rubber-bands.
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            slivers: [
              // Weather header + the "Your Garden" panel live in ONE sliver so
              // the panel paints ON TOP of the weather (the viewport paints an
              // earlier sliver above later ones, which would otherwise let the
              // weather cover the panel). The panel has a rounded top and is
              // pulled up to overlap the weather, so the blue shows through its
              // corners. The ColoredBox backs the whole sliver — including the
              // 28px of layout space the translate vacates below the panel —
              // so nothing behind the scroll view can ever show through here.
              SliverToBoxAdapter(
                child: ColoredBox(
                  color: AppColors.background,
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
                              _buildGardenSearch(),
                              _buildFilterChips(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The card-grid area paints its own background too, so it always
              // sits on an opaque surface regardless of what's behind the
              // scroll view or how tall the screen is.
              if (_isLoadingPlants)
                DecoratedSliver(
                  decoration: const BoxDecoration(color: AppColors.background),
                  sliver: SliverPadding(
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
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ColoredBox(
                    color: AppColors.background,
                    child: _buildEmptyState(),
                  ),
                )
              else
                DecoratedSliver(
                  decoration: const BoxDecoration(color: AppColors.background),
                  sliver: SliverPadding(
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
                ),
            ],
          ),
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
    final topScrimAlpha = isNight ? 0.18 : (isWet ? 0.10 : 0.06);
    final midScrimAlpha = isNight ? 0.09 : (isWet ? 0.05 : 0.03);
    final bottomScrimAlpha = isNight ? 0.10 : (isWet ? 0.07 : 0.04);
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
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
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
                        _buildHeaderActions(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _weather?.cityName ?? 'Locating…',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

  /// Circular avatar for the weather header — the user's photo if set,
  /// otherwise their initial (or a person icon). Same image source as the
  /// profile screen's card so the two stay in sync. [size] is null when
  /// wrapped by [TierFrame], which sizes the child via its padding instead.
  Widget _buildHeaderAvatar(double? size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAF7),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: _avatarUrl != null
          ? Image.network(
              _avatarUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => _headerAvatarFallback(),
            )
          : _headerAvatarFallback(),
    );
  }

  Widget _headerAvatarFallback() {
    return _username.isEmpty
        ? const Icon(
            Icons.person_rounded,
            color: AppColors.primaryDark,
            size: 26,
          )
        : Text(
            _username[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          );
  }

  /// The profile avatar in the top-right of the weather header. No glass
  /// backing anymore — just the (larger) framed avatar with a soft shadow so
  /// it still reads against a bright sky.
  Widget _buildHeaderActions() {
    const double avatarSize = 58;
    return Tooltip(
      message: 'Profile',
      child: Semantics(
        button: true,
        label: 'Open profile',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              AppBadgeController.instance.clearProfileUnlock();
              context.go('/profile');
            },
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4D0B1424),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: _tier == null
                  ? _buildHeaderAvatar(avatarSize)
                  : TierFrame(
                      tier: _tier!,
                      size: avatarSize,
                      child: _buildHeaderAvatar(null),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────── Garden header + filter chips ─────────

  Widget _buildGardenHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Your Garden',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }

  /// Search and status filtering share one row so the section heading and the
  /// location chips do not become crowded with another independent control.
  Widget _buildGardenSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: _gardenSearchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _gardenQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search your plants',
                  prefixIcon: const Icon(Icons.search_rounded, size: 21),
                  suffixIcon: _gardenQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _gardenSearchController.clear();
                            setState(() => _gardenQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
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

  /// Centered message shown when the grid has nothing to render. The bottom
  /// padding lifts it above the nav bar / FAB so it sits at the visual centre
  /// of the free space. Adding a plant is left to the FAB — no second button.
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 148),
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
                : _gardenQuery.trim().isNotEmpty
                ? 'Try another name, species, or location.'
                : 'No plants match this filter. Try a different one.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
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

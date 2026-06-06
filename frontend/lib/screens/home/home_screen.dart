import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';

const _kAllFilter = '__all__';
const _kUnsortedFilter = '__unsorted__';

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
  Weather? _weather;
  String _filter = _kAllFilter;
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() =>
          _username = prefs.getString(AppConstants.usernameKey) ?? '');
    }
    await Future.wait([_loadPlants(), _loadWeather()]);
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPlants = false);
      AppSnackBar.error(context, 'Failed to load plants: $e');
    }
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    // Paint cached value immediately so the card isn't empty.
    final cached = await LocationService.getCached();
    if (cached != null) {
      final w = await WeatherService.getWeather(cached.lat, cached.lon);
      if (mounted && w != null) setState(() => _weather = w);
    }

    // Then try for a fresh fix. On forceRefresh, also skip the OS's
    // last-known cache so a relocated emulator picks up its new coords.
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
    await Future.wait([
      _loadPlants(),
      _loadWeather(forceRefresh: true),
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
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to water: $e');
      }
    }
  }

  Future<void> _openAddPlant() async {
    await context.push('/plants/add');
    _loadPlants();
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
    return [
      _kAllFilter,
      ...list,
      if (hasUnsorted) _kUnsortedFilter,
    ];
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
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildWeatherCard()),
              SliverToBoxAdapter(child: _buildGardenHeader()),
              SliverToBoxAdapter(child: _buildFilterChips()),
              if (_isLoadingPlants)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
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
              else if (_filteredPlants.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        // Last tile is the "Add Plant" placeholder.
                        if (i == _filteredPlants.length) {
                          return _AddPlantTile(onTap: _openAddPlant);
                        }
                        return _PlantGridCard(
                          plant: _filteredPlants[i],
                          onTap: () async {
                            await context
                                .push('/plants/${_filteredPlants[i].id}');
                            _loadPlants();
                          },
                          onWater: () => _waterPlant(_filteredPlants[i]),
                        );
                      },
                      childCount: _filteredPlants.length + 1,
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

  Widget _buildWeatherCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7EC0EE), Color(0xFF4F9FD9)],
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
                          color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _username.isEmpty ? 'Plant lover' : _username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                _weather?.cityName ?? 'Locating…',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _WeatherStat(
                  icon: Icons.water_drop_outlined,
                  label: 'HUMIDITY',
                  value: _weather == null ? '—' : '${_weather!.humidity}%',
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
    );
  }

  // ───────── Garden header + filter chips ─────────

  Widget _buildGardenHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Your Garden',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          const Icon(Icons.eco_outlined,
              size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            _plants.isEmpty ? 'No plants yet' : 'No matches',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _plants.isEmpty
                ? 'Tap the + button to add your first plant.'
                : 'No plants match this filter. Try a different one.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openAddPlant,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Plant'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(160, 48),
            ),
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
  final VoidCallback onWater;
  const _PlantGridCard({
    required this.plant,
    required this.onTap,
    required this.onWater,
  });

  String _statusLine() {
    if (plant.latestHealth == 'diseased') return 'Needs treatment';
    if (plant.needsWater) return 'Needs water today';
    if (plant.latestHealth == 'healthy') return 'Doing great';
    return plant.species;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                    top: Radius.circular(18)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    plant.photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: plant.photoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (c, _) => Container(
                              color: AppColors.primary.withValues(alpha: 0.08),
                            ),
                            errorWidget: (c, _, _) => Container(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              child: const Icon(Icons.eco_rounded,
                                  color: AppColors.primary, size: 36),
                            ),
                          )
                        : Container(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            child: const Icon(Icons.eco_rounded,
                                color: AppColors.primary, size: 36),
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
            // Text area
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                    _statusLine(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: plant.needsWater
                          ? const Color(0xFF4F9FD9)
                          : (plant.latestHealth == 'diseased'
                              ? AppColors.amber
                              : AppColors.textSecondary),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ActionIcon(
                        icon: Icons.water_drop_outlined,
                        color: plant.needsWater
                            ? const Color(0xFF4F9FD9)
                            : AppColors.textMuted,
                        onTap: onWater,
                      ),
                      const SizedBox(width: 8),
                      const _ActionIcon(
                        icon: Icons.wb_sunny_outlined,
                        color: AppColors.amber,
                        onTap: null,
                      ),
                      const Spacer(),
                      _ActionIcon(
                        icon: Icons.add_rounded,
                        color: AppColors.primary,
                        onTap: onTap,
                      ),
                    ],
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
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
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

class _AddPlantTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPlantTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.textMuted,
            radius: 18,
            strokeWidth: 1.4,
            dash: 6,
            gap: 4,
          ),
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double distance = 0;
      while (distance < m.length) {
        final next = (distance + dash).clamp(0, m.length);
        canvas.drawPath(
          m.extractPath(distance, next.toDouble()),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

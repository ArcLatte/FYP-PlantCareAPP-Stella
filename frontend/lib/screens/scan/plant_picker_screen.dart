import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_error.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../services/api_service.dart';

const _allLocations = '__all__';
const _unsortedLocation = '__unsorted__';

enum _PlantStatus { all, needsWater, needsAttention, healthy }

extension on _PlantStatus {
  String get label {
    switch (this) {
      case _PlantStatus.all:
        return 'All plants';
      case _PlantStatus.needsWater:
        return 'Needs water';
      case _PlantStatus.needsAttention:
        return 'Needs attention';
      case _PlantStatus.healthy:
        return 'Healthy';
    }
  }

  IconData get icon {
    switch (this) {
      case _PlantStatus.all:
        return Icons.grid_view_rounded;
      case _PlantStatus.needsWater:
        return Icons.water_drop_outlined;
      case _PlantStatus.needsAttention:
        return Icons.warning_amber_rounded;
      case _PlantStatus.healthy:
        return Icons.favorite_rounded;
    }
  }
}

/// Full-page plant chooser used by the camera. It scales better than a bottom
/// sheet because search and filters stay visible even with a large garden.
class PlantPickerScreen extends StatefulWidget {
  final int? selectedPlantId;

  const PlantPickerScreen({super.key, this.selectedPlantId});

  @override
  State<PlantPickerScreen> createState() => _PlantPickerScreenState();
}

class _PlantPickerScreenState extends State<PlantPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Plant> _plants = [];
  bool _isLoading = true;
  String? _loadError;
  String _query = '';
  String _location = _allLocations;
  _PlantStatus _status = _PlantStatus.all;

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlants() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final plants = await ApiService.getPlants();
      if (!mounted) return;
      setState(() {
        _plants = plants;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = AppErrorMessages.message(
          error,
          fallback: 'Could not load your plants. Please try again.',
        );
      });
    }
  }

  Future<void> _addPlant() async {
    final existingIds = _plants.map((plant) => plant.id).toSet();
    final created = await context.push<bool>('/plants/add');
    if (!mounted || created != true) return;

    try {
      final plants = await ApiService.getPlants();
      if (!mounted) return;
      Plant? addedPlant;
      for (final plant in plants) {
        if (!existingIds.contains(plant.id)) {
          addedPlant = plant;
          break;
        }
      }
      if (addedPlant != null) {
        context.pop(addedPlant.id);
      } else {
        setState(() => _plants = plants);
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _loadError = AppErrorMessages.message(
          error,
          fallback: 'Plant added, but the garden could not be refreshed.',
        ),
      );
    }
  }

  List<String> get _locations {
    final named =
        _plants
            .map((plant) => plant.location.trim())
            .where((location) => location.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final hasUnsorted = _plants.any((plant) => plant.location.trim().isEmpty);
    return [_allLocations, ...named, if (hasUnsorted) _unsortedLocation];
  }

  List<Plant> get _visiblePlants {
    // Custom species are tracker-only, so they cannot be selected for a scan.
    Iterable<Plant> result = _plants.where((plant) => plant.scanAvailable);
    if (_location == _unsortedLocation) {
      result = result.where((plant) => plant.location.trim().isEmpty);
    } else if (_location != _allLocations) {
      result = result.where((plant) => plant.location == _location);
    }

    switch (_status) {
      case _PlantStatus.all:
        break;
      case _PlantStatus.needsWater:
        result = result.where((plant) => plant.needsWater);
      case _PlantStatus.needsAttention:
        result = result.where((plant) => plant.latestHealth == 'diseased');
      case _PlantStatus.healthy:
        result = result.where((plant) => plant.latestHealth == 'healthy');
    }

    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((plant) {
        return plant.name.toLowerCase().contains(query) ||
            plant.species.toLowerCase().contains(query) ||
            plant.location.toLowerCase().contains(query);
      });
    }
    return result.toList();
  }

  int _statusCount(_PlantStatus status) {
    switch (status) {
      case _PlantStatus.all:
        return _plants.length;
      case _PlantStatus.needsWater:
        return _plants.where((plant) => plant.needsWater).length;
      case _PlantStatus.needsAttention:
        return _plants
            .where((plant) => plant.latestHealth == 'diseased')
            .length;
      case _PlantStatus.healthy:
        return _plants.where((plant) => plant.latestHealth == 'healthy').length;
    }
  }

  Future<void> _openStatusFilter() async {
    final selected = await showModalBottomSheet<_PlantStatus>(
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
                'Filter by status',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final status in _PlantStatus.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    status.icon,
                    color: status == _status
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  title: Text(status.label),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_statusCount(status)}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 12),
                      if (status == _status)
                        const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                  onTap: () => Navigator.pop(sheetContext, status),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _status = selected);
  }

  @override
  Widget build(BuildContext context) {
    final visiblePlants = _visiblePlants;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a plant'),
        actions: [
          IconButton(
            tooltip: 'Add plant',
            onPressed: _addPlant,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPlants,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildControls()),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_loadError != null && _plants.isEmpty)
                SliverFillRemaining(child: _buildLoadError())
              else if (visiblePlants.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.76,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final plant = visiblePlants[index];
                      return _PlantChoiceCard(
                        plant: plant,
                        selected: plant.id == widget.selectedPlantId,
                        onTap: () => context.pop(plant.id),
                      );
                    }, childCount: visiblePlants.length),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Which plant are you scanning?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose the profile that belongs to the leaf.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search plants',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded, size: 19),
                            ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusFilterButton(
                active: _status != _PlantStatus.all,
                label: _status == _PlantStatus.all ? 'Filter' : _status.label,
                onTap: _openStatusFilter,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _locations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final location = _locations[index];
                final selected = location == _location;
                final label = location == _allLocations
                    ? 'All (${_plants.where((plant) => plant.scanAvailable).length})'
                    : location == _unsortedLocation
                    ? 'Unsorted'
                    : location;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _location = location),
                  selectedColor: AppColors.textPrimary,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.cardBorder),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadPlants,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasPlants = _plants.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.eco_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 14),
            Text(
              hasPlants ? 'No matching plants' : 'No plants yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasPlants
                  ? 'No scan-enabled plant profiles match. Custom species can be used for care logs and notes, but cannot be scanned.'
                  : 'Add your first plant profile before scanning.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!hasPlants) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _addPlant,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add plant'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusFilterButton extends StatelessWidget {
  final bool active;
  final String label;
  final VoidCallback onTap;

  const _StatusFilterButton({
    required this.active,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.primary
          : AppColors.primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46, maxWidth: 138),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                color: active ? Colors.white : AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlantChoiceCard extends StatelessWidget {
  final Plant plant;
  final bool selected;
  final VoidCallback onTap;

  const _PlantChoiceCard({
    required this.plant,
    required this.selected,
    required this.onTap,
  });

  String get _details => [
    plant.species,
    plant.location,
  ].where((value) => value.trim().isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Choose ${plant.name}, $_details',
      child: Material(
        color: AppColors.surface,
        elevation: selected ? 3 : 1,
        shadowColor: AppColors.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (plant.photoUrl != null)
                      CachedNetworkImage(
                        imageUrl: plant.photoUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        placeholder: (_, _) => _imageFallback(),
                        errorWidget: (_, _, _) => _imageFallback(),
                      )
                    else
                      _imageFallback(),
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.cardShadow,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          selected
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PlantHealthChip(plant: plant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.09),
      child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 40),
    );
  }
}

class _PlantHealthChip extends StatelessWidget {
  final Plant plant;

  const _PlantHealthChip({required this.plant});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    final Color color;
    if (plant.latestHealth == 'diseased') {
      icon = Icons.warning_amber_rounded;
      label = 'Needs attention';
      color = AppColors.amber;
    } else if (plant.needsWater) {
      icon = Icons.water_drop_rounded;
      label = 'Needs water';
      color = const Color(0xFF4F9FD9);
    } else if (plant.latestHealth == 'healthy') {
      icon = Icons.check_circle_rounded;
      label = 'Healthy';
      color = AppColors.primary;
    } else {
      icon = Icons.check_circle_outline_rounded;
      label = 'All good';
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
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
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

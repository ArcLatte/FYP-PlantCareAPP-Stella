import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../models/plant.dart';
import '../../models/plant_stage.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/stage_image.dart';
import '../../widgets/xp_toast.dart';

// Per-topic colors — mirror the palette used on the Tasks screen so the
// profile feels cohesive with the rest of the app.
const _kWaterColor = Color(0xFF4F9FD9);
const _kMistColor = Color(0xFF26A69A);

class PlantDetailScreen extends StatefulWidget {
  final int plantId;

  const PlantDetailScreen({super.key, required this.plantId});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  Plant? _plant;
  List<ActivityEvent> _activity = [];
  bool _isLoading = true;
  bool _isWatering = false;
  bool _isFertilizing = false;
  bool _isMisting = false;

  Future<void> _waterNow() async {
    if (_plant == null || _isWatering) return;
    setState(() => _isWatering = true);
    try {
      final updated = await ApiService.waterPlant(_plant!.id);
      if (!mounted) return;
      setState(() => _plant = updated);
      AppSnackBar.success(context, '${updated.name} watered');
      XpToast.flush(context);
      _refreshActivity();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to water: $e');
      }
    } finally {
      if (mounted) setState(() => _isWatering = false);
    }
  }

  Future<void> _fertilizeNow() async {
    if (_plant == null || _isFertilizing) return;
    setState(() => _isFertilizing = true);
    try {
      final updated = await ApiService.fertilizePlant(_plant!.id);
      if (!mounted) return;
      setState(() => _plant = updated);
      AppSnackBar.success(context, '${updated.name} fertilized');
      XpToast.flush(context);
      _refreshActivity();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to fertilize: $e');
    } finally {
      if (mounted) setState(() => _isFertilizing = false);
    }
  }

  Future<void> _mistNow() async {
    if (_plant == null || _isMisting) return;
    setState(() => _isMisting = true);
    try {
      final updated = await ApiService.mistPlant(_plant!.id);
      if (!mounted) return;
      setState(() => _plant = updated);
      AppSnackBar.success(context, '${updated.name} misted');
      XpToast.flush(context);
      _refreshActivity();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Failed to mist: $e');
    } finally {
      if (mounted) setState(() => _isMisting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final plant = await ApiService.getPlant(widget.plantId);
      final activity = await ApiService.getPlantActivity(widget.plantId);
      setState(() {
        _plant = plant;
        _activity = activity;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// Pull just the history after a care action so the new event shows up at the
  /// top without a full-screen reload.
  Future<void> _refreshActivity() async {
    try {
      final activity = await ApiService.getPlantActivity(widget.plantId);
      if (mounted) setState(() => _activity = activity);
    } catch (_) {
      // Non-fatal — the timeline just stays as-is until the next refresh.
    }
  }

  Future<void> _deletePlant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text(
          'Delete Plant',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to delete this plant? All scans will also be deleted.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deletePlant(widget.plantId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to delete plant: $e');
      }
    }
  }

  String _formatDisease(String label) {
    return label.replaceAll('_', ' ').replaceAll('Tomato ', '');
  }

  /// Plant-health section: shows the latest *confirmed* diagnosis with care
  /// tips and a "Read more" link, a healthy state, or a prompt to scan.
  Widget _buildHealthCard(BuildContext context) {
    final disease = _plant!.latestDisease;

    // No confirmed diagnosis yet → gentle prompt.
    if (disease == null) {
      final hasScans = _activity.any((e) => e.isScan);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.health_and_safety_outlined,
                color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasScans
                    ? 'Confirm a diagnosis on a scan below to see care tips.'
                    : 'Scan this plant to check its health.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final healthy = disease.isHealthy;
    final accent = healthy ? AppColors.success : AppColors.amber;
    final careText = healthy
        ? (disease.careTips.isNotEmpty
            ? disease.careTips
            : 'No issues detected. Keep up your regular care routine.')
        : (disease.treatment.isNotEmpty
            ? disease.treatment
            : disease.careTips);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  healthy
                      ? Icons.favorite_rounded
                      : Icons.warning_amber_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      healthy ? 'Looks healthy' : 'Needs attention',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      disease.name.isNotEmpty
                          ? disease.name
                          : _formatDisease(disease.label),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (careText.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              careText,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => context.push(
                  '/disease/${Uri.encodeComponent(disease.label)}'),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('Read more'),
            ),
          ),
        ],
      ),
    );
  }

  /// "Today" / "in 3d" / "Overdue 2d" / "—" from days-until.
  static String _nextLabel(int? days) {
    if (days == null) return '—';
    if (days == 0) return 'Today';
    if (days < 0) return 'Overdue ${-days}d';
    return 'in ${days}d';
  }

  static String _lastLabel(DateTime? d) {
    if (d == null) return 'Never';
    return '${d.day}/${d.month}/${d.year}';
  }

  /// "Planted today" / "12 days ago" / "—" from createdAt string.
  String _ageLabel(String createdAt) {
    final planted = DateTime.tryParse(createdAt);
    if (planted == null) return '—';
    final days = DateTime.now().difference(planted).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  /// Whole days since the plant was planted (clamped to ≥0). Drives the growth
  /// stage + harvest progress.
  int _ageDays(String createdAt) {
    final planted = DateTime.tryParse(createdAt);
    if (planted == null) return 0;
    final days = DateTime.now().difference(planted).inDays;
    return days < 0 ? 0 : days;
  }

  /// Per-topic colour for the species care strip. Mirrors the Tasks screen
  /// palette so sun/temp/etc. read the same wherever they appear.
  Color _careCardColor(String label) {
    switch (label) {
      case 'SUNLIGHT':
      case 'TEMP':
        return AppColors.amber;
      case 'LOCATION':
      case 'HARVEST':
      default:
        return AppColors.primary;
    }
  }

  /// Build the horizontal list of *intrinsic* species cards (sunlight, temp,
  /// location, harvest). Scheduling cadences (water/fertilize/mist) are omitted
  /// here — the Care card above owns those, so this avoids duplicating them.
  List<Widget> _buildCareTips(Plant plant) {
    final s = plant.speciesDetail;
    if (s == null) return const [];
    final cards = <Widget>[];

    void add(IconData icon, String value, String label) {
      cards.add(_CareCard(
        icon: icon,
        value: value,
        label: label,
        color: _careCardColor(label),
      ));
    }

    if (s.sunlightLabel.isNotEmpty) {
      add(Icons.wb_sunny_outlined, s.sunlightLabel, 'SUNLIGHT');
    }
    if (s.locationLabel.isNotEmpty) {
      add(Icons.home_outlined, s.locationLabel, 'LOCATION');
    }
    if (s.temperatureRange != null) {
      add(Icons.thermostat_outlined, s.temperatureRange!, 'TEMP');
    }
    if (s.daysToHarvest != null) {
      add(Icons.eco_outlined, '~${s.daysToHarvest}d', 'HARVEST');
    }
    return cards;
  }

  /// One Care card row per applicable activity. Water always applies; fertilize
  /// and mist only when the species schedules them.
  List<Widget> _buildCareRows(Plant plant) {
    final rows = <Widget>[
      _CareRow(
        icon: Icons.water_drop_rounded,
        color: _kWaterColor,
        label: 'Water',
        next: _nextLabel(plant.daysUntilWater),
        last: _lastLabel(plant.lastWatered),
        overdue: (plant.daysUntilWater ?? 1) <= 0,
        busy: _isWatering,
        onLog: _waterNow,
      ),
    ];
    if (plant.daysUntilFertilizer != null) {
      rows.add(_CareRow(
        icon: Icons.compost_rounded,
        color: AppColors.amber,
        label: 'Fertilize',
        next: _nextLabel(plant.daysUntilFertilizer),
        last: _lastLabel(plant.lastFertilized),
        overdue: (plant.daysUntilFertilizer ?? 1) <= 0,
        busy: _isFertilizing,
        onLog: _fertilizeNow,
      ));
    }
    if (plant.daysUntilMisting != null) {
      rows.add(_CareRow(
        icon: Icons.cloud_rounded,
        color: _kMistColor,
        label: 'Mist',
        next: _nextLabel(plant.daysUntilMisting),
        last: _lastLabel(plant.lastMisted),
        overdue: (plant.daysUntilMisting ?? 1) <= 0,
        busy: _isMisting,
        onLog: _mistNow,
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body extends behind the floating action bar so it appears to hover.
      extendBody: true,
      appBar: AppBar(
        title: Text(_plant?.name ?? 'Plant Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          // May be reached via `context.go` from the scan result (which clears
          // the stack), so guard against an empty navigation stack.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  final changed =
                      await context.push<bool>('/plants/${widget.plantId}/edit');
                  if (changed == true && mounted) _loadData();
                case 'delete':
                  _deletePlant();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        color: AppColors.textPrimary, size: 20),
                    SizedBox(width: 12),
                    Text('Edit plant',
                        style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: AppColors.error, size: 20),
                    SizedBox(width: 12),
                    Text('Delete plant',
                        style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const _PlantDetailSkeleton()
          : _plant == null
              ? const Center(
                  child: Text('Plant not found',
                      style: TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: CustomScrollView(
                    slivers: [
                      // 1. Hero photo with name + species + health overlay.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: _PlantHero(plant: _plant!),
                        ),
                      ),

                      // 2. Quick facts — planted / location.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: _QuickFacts(
                            age: _ageLabel(_plant!.createdAt),
                            location: _plant!.location,
                          ),
                        ),
                      ),

                      // 3. Growth stage + harvest progress.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: _GrowthCard(
                            ageDays: _ageDays(_plant!.createdAt),
                            daysToHarvest:
                                _plant!.speciesDetail?.daysToHarvest,
                          ),
                        ),
                      ),

                      // 4. Unified care card — one row per applicable activity,
                      // each combining next-due + last-done + a log button.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: _SectionCard(
                            title: 'Care',
                            child: Column(
                              children: [
                                for (final (i, row)
                                    in _buildCareRows(_plant!).indexed) ...[
                                  if (i > 0) const SizedBox(height: 14),
                                  row,
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 5. Plant health — latest confirmed diagnosis + a
                      // "Read more" link to the disease page.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: _buildHealthCard(context),
                        ),
                      ),

                      // 5b. Notes — user's own free-text note for this plant.
                      if (_plant!.notes != null &&
                          _plant!.notes!.trim().isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: _SectionCard(
                              title: 'Notes',
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _plant!.notes!,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 6. About this species (collapsible).
                      if (_plant!.speciesDetail != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: _SpeciesSection(
                              plant: _plant!,
                              cards: _buildCareTips(_plant!),
                            ),
                          ),
                        ),

                      // 7. History timeline — care events + scans merged.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                          child: Text(
                            'History',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      _activity.isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    24, 8, 24, 100),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.history_rounded,
                                        size: 48,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No history yet',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : SliverPadding(
                              // Bottom padding clears the persistent action
                              // bar so the last card isn't hidden behind it.
                              padding: const EdgeInsets.fromLTRB(
                                  24, 0, 24, 100),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final event = _activity[index];
                                    return _TimelineTile(
                                      event: event,
                                      formatDisease: _formatDisease,
                                      onTapScan: event.scanId != null
                                          ? () => context.push(
                                              '/result/${event.scanId}')
                                          : null,
                                    );
                                  },
                                  childCount: _activity.length,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
      // 8. Persistent action bar — a single primary Scan CTA. Care actions
      // now log inline in the Care card.
      bottomNavigationBar: _plant == null
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/scan/${widget.plantId}'),
                    icon: const Icon(Icons.document_scanner_rounded),
                    label: const Text('Scan plant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Hero photo with a bottom gradient scrim and the plant's identity overlaid:
/// name, species, and a health badge. This is the single source of the plant's
/// name/species/health on the page.
class _PlantHero extends StatelessWidget {
  final Plant plant;
  const _PlantHero({required this.plant});

  @override
  Widget build(BuildContext context) {
    final (healthLabel, healthColor) = switch (plant.latestHealth) {
      'healthy' => ('Healthy', AppColors.success),
      'diseased' => ('Needs treatment', AppColors.amber),
      _ => ('Unknown', AppColors.textMuted),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            plant.photoUrl != null
                ? CachedNetworkImage(
                    imageUrl: plant.photoUrl!,
                    fit: BoxFit.cover,
                    // Hero spans the screen width; cap decode size well under
                    // full camera resolution.
                    memCacheWidth: 900,
                    placeholder: (_, _) => const SkeletonBox(radius: 0),
                    errorWidget: (_, _, _) => const _PhotoPlaceholder(),
                  )
                : const _PhotoPlaceholder(),
            // Scrim so white text stays legible over any photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xCC000000),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          plant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (plant.species.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            plant.species,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _HeroHealthBadge(label: healthLabel, color: healthColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Solid, high-contrast health pill for the hero overlay (the translucent
/// in-card chip wouldn't read over a photo).
class _HeroHealthBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _HeroHealthBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.white, size: 8),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact planted/location pair under the hero.
class _QuickFacts extends StatelessWidget {
  final String age;
  final String location;

  const _QuickFacts({
    required this.age,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Expanded(
            child: _StatTile(
              icon: Icons.eco_rounded,
              color: AppColors.amber,
              label: 'PLANTED',
              value: age,
            ),
          ),
          Expanded(
            child: _StatTile(
              icon: Icons.place_rounded,
              color: AppColors.primary,
              label: 'LOCATION',
              value: location.isEmpty ? '—' : location,
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-plant growth visualization: the staged illustration driven by the
/// plant's age, plus a harvest progress bar for species that fruit/harvest.
class _GrowthCard extends StatelessWidget {
  final int ageDays;
  final int? daysToHarvest;

  const _GrowthCard({required this.ageDays, required this.daysToHarvest});

  @override
  Widget build(BuildContext context) {
    final stage = PlantStage.forStreak(ageDays);
    final next = PlantStage.next(stage);
    final caption = next == null
        ? 'Fully grown'
        : '${next.name} in ${(next.minDays - ageDays).clamp(1, 999)}d';

    final dh = daysToHarvest;
    final harvestRemaining = dh == null ? null : dh - ageDays;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: StageImage(image: stage.image, size: 56),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GROWTH STAGE',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(stage.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(caption,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (dh != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.agriculture_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Harvest',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  (harvestRemaining ?? 0) <= 0
                      ? 'Ready to harvest'
                      : '~${harvestRemaining}d to go',
                  style: TextStyle(
                    color: (harvestRemaining ?? 0) <= 0
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (ageDays / dh).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation(
                  (harvestRemaining ?? 0) <= 0
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A titled white card used to group a section (e.g. Care).
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// A single care activity: tinted icon, name, next-due + last-done, and an
/// inline Log button. Combines what used to be three separate widgets.
class _CareRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String next;
  final String last;
  final bool overdue;
  final bool busy;
  final VoidCallback onLog;

  const _CareRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.next,
    required this.last,
    required this.overdue,
    required this.busy,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Next ',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                    TextSpan(
                      text: next,
                      style: TextStyle(
                        color: overdue
                            ? AppColors.amber
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            overdue ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '  ·  Last $last',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: busy ? null : onLog,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: color.withValues(alpha: 0.6),
              // The app theme's ElevatedButton minimumSize is (infinity, 52);
              // inside a Row that forces an infinite width and kills layout.
              minimumSize: const Size(60, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Log'),
          ),
        ),
      ],
    );
  }
}

/// Collapsible "About this species" section: scientific name, description,
/// growing tips, plus the intrinsic species care cards.
class _SpeciesSection extends StatelessWidget {
  final Plant plant;
  final List<Widget> cards;
  const _SpeciesSection({required this.plant, required this.cards});

  @override
  Widget build(BuildContext context) {
    final s = plant.speciesDetail!;
    return Container(
      clipBehavior: Clip.antiAlias,
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
      child: Theme(
        // Strip ExpansionTile's default dividers so it blends into the card.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 0, 16),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text('About this species',
              style: Theme.of(context).textTheme.titleMedium),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.scientificName.isNotEmpty)
                      Text(
                        s.scientificName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (s.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(s.description,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (s.growingTips.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'GROWING TIPS',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(s.growingTips,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
            if (cards.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: cards,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One row in the History timeline: a care event or a scan. Scan rows are
/// tappable and open the result page.
class _TimelineTile extends StatelessWidget {
  final ActivityEvent event;
  final String Function(String) formatDisease;
  final VoidCallback? onTapScan;

  const _TimelineTile({
    required this.event,
    required this.formatDisease,
    required this.onTapScan,
  });

  static String _relative(DateTime d) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  ({IconData icon, Color color, String title}) _visuals() {
    if (event.isScan) {
      final healthy = event.health == 'healthy';
      return (
        icon: healthy ? Icons.favorite_rounded : Icons.warning_amber_rounded,
        color: healthy ? AppColors.success : AppColors.amber,
        title: event.label != null && event.label!.isNotEmpty
            ? formatDisease(event.label!)
            : 'Health scan',
      );
    }
    switch (event.activity) {
      case 'water':
        return (icon: Icons.water_drop_rounded, color: _kWaterColor, title: 'Watered');
      case 'fertilize':
        return (icon: Icons.compost_rounded, color: AppColors.amber, title: 'Fertilized');
      case 'mist':
        return (icon: Icons.cloud_rounded, color: _kMistColor, title: 'Misted');
      default:
        return (icon: Icons.eco_rounded, color: AppColors.primary, title: 'Care');
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _visuals();
    final tappable = event.isScan && onTapScan != null;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: v.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(v.icon, color: v.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(_relative(event.createdAt),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (tappable)
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
        ],
      ),
    );

    if (!tappable) return card;
    return GestureDetector(onTap: onTapScan, child: card);
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.eco_rounded, color: AppColors.primary, size: 56),
      ),
    );
  }
}

/// One cell in the quick-facts row. Tinted icon tile + label/value column.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small square card summarizing one species care recommendation
/// (sunlight, ideal temperature, location, harvest window).
class _CareCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _CareCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton scaffold rendered while the plant + history are being fetched.
/// Mirrors the new layout: hero → quick facts → growth → care → list.
class _PlantDetailSkeleton extends StatelessWidget {
  const _PlantDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 10,
            child: SkeletonBox(radius: 20),
          ),
          const SizedBox(height: 16),
          const SkeletonBox(height: 70, radius: 16),
          const SizedBox(height: 16),
          const SkeletonBox(height: 108, radius: 16),
          const SizedBox(height: 20),
          const SkeletonBox(height: 132, radius: 16),
          const SizedBox(height: 24),
          const SkeletonBox(width: 120, height: 20, radius: 6),
          const SizedBox(height: 12),
          for (int i = 0; i < 2; i++) ...[
            const SkeletonBox(height: 72, radius: 16),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

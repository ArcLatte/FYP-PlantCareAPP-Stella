import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../models/scan.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';
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
  List<ScanResult> _scans = [];
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
      final scans = await ApiService.getPlantScans(widget.plantId);
      setState(() {
        _plant = plant;
        _scans = scans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDisease(String label) {
    return label.replaceAll('_', ' ').replaceAll('Tomato ', '');
  }

  /// "Today" / "in 3d" / "Overdue 2d" / "—" from days-until-water.
  String _nextWateringLabel(int? days) {
    if (days == null) return '—';
    if (days == 0) return 'Today';
    if (days < 0) return 'Overdue ${-days}d';
    return 'in ${days}d';
  }

  /// "Due today" / "Due in 3d" / "Overdue 2d" for the care action rows.
  String _careDueLabel(int? days) {
    if (days == null) return '';
    if (days == 0) return 'Due today';
    if (days < 0) return 'Overdue ${-days}d';
    return 'Due in ${days}d';
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

  /// Per-topic colour for the species care strip. Mirrors the Tasks screen
  /// palette so water/mist/sun read the same wherever they appear.
  Color _careCardColor(String label) {
    switch (label) {
      case 'WATER':
        return _kWaterColor;
      case 'SUNLIGHT':
      case 'FERTILIZE':
      case 'TEMP':
        return AppColors.amber;
      case 'MIST':
        return _kMistColor;
      case 'LOCATION':
      case 'HARVEST':
      default:
        return AppColors.primary;
    }
  }

  /// Build the horizontal list of species care cards. Only cards with data
  /// are included, so plants whose species predates the knowledge base (or
  /// activities that don't apply, like misting for a tomato) are skipped.
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
    if (s.defaultWateringFreqDays != null) {
      add(Icons.water_drop_outlined,
          'Every ${s.defaultWateringFreqDays}d', 'WATER');
    }
    if (s.locationLabel.isNotEmpty) {
      add(Icons.home_outlined, s.locationLabel, 'LOCATION');
    }
    if (s.temperatureRange != null) {
      add(Icons.thermostat_outlined, s.temperatureRange!, 'TEMP');
    }
    if (s.defaultFertilizerFreqDays != null) {
      add(Icons.compost_outlined,
          'Every ${s.defaultFertilizerFreqDays}d', 'FERTILIZE');
    }
    if (s.defaultMistingFreqDays != null) {
      add(Icons.cloud_outlined,
          'Every ${s.defaultMistingFreqDays}d', 'MIST');
    }
    if (s.daysToHarvest != null) {
      add(Icons.eco_outlined, '~${s.daysToHarvest}d', 'HARVEST');
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_plant?.name ?? 'Plant Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
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
                      // 1. Hero photo
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: _PlantPhoto(photoUrl: _plant!.photoUrl),
                        ),
                      ),

                      // 2. Plant details (status bar)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: _PlantDetailsCard(
                            plant: _plant!,
                            nextWatering:
                                _nextWateringLabel(_plant!.daysUntilWater),
                            age: _ageLabel(_plant!.createdAt),
                            lastWatered: _plant!.lastWatered == null
                                ? 'Never'
                                : _formatDate(
                                    _plant!.lastWatered!.toIso8601String()),
                            added: _formatDate(_plant!.createdAt),
                          ),
                        ),
                      ),

                      // 2b. Fertilize / mist quick actions — only when the
                      // species actually has those schedules. Watering stays
                      // in the pinned bottom bar as the primary action.
                      if (_plant!.daysUntilFertilizer != null ||
                          _plant!.daysUntilMisting != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                            child: Column(
                              children: [
                                if (_plant!.daysUntilFertilizer != null)
                                  _CareActionRow(
                                    icon: Icons.compost_rounded,
                                    color: AppColors.amber,
                                    label: 'Fertilize',
                                    due: _careDueLabel(
                                        _plant!.daysUntilFertilizer),
                                    overdue:
                                        (_plant!.daysUntilFertilizer ?? 1) <= 0,
                                    busy: _isFertilizing,
                                    onLog: _fertilizeNow,
                                  ),
                                if (_plant!.daysUntilFertilizer != null &&
                                    _plant!.daysUntilMisting != null)
                                  const SizedBox(height: 10),
                                if (_plant!.daysUntilMisting != null)
                                  _CareActionRow(
                                    icon: Icons.cloud_rounded,
                                    color: _kMistColor,
                                    label: 'Mist',
                                    due: _careDueLabel(_plant!.daysUntilMisting),
                                    overdue: (_plant!.daysUntilMisting ?? 1) <= 0,
                                    busy: _isMisting,
                                    onLog: _mistNow,
                                  ),
                              ],
                            ),
                          ),
                        ),

                      // 3. Species care cards
                      if (_buildCareTips(_plant!).isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 0, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 24),
                                  child: Text('Plant care',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 96,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    padding:
                                        const EdgeInsets.only(right: 12),
                                    children: _buildCareTips(_plant!),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 4. Scan History
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                          child: Text(
                            'Scan History',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      _scans.isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    24, 8, 24, 100),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.document_scanner_outlined,
                                        size: 48,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No scans yet',
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
                                    final scan = _scans[index];
                                    return GestureDetector(
                                      onTap: () =>
                                          context.push('/result/${scan.id}'),
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: AppColors.cardBorder),
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
                                                color: scan.confirmedDisease
                                                            ?.contains(
                                                                'healthy') ==
                                                        true
                                                    ? AppColors.success
                                                        .withValues(alpha: 0.15)
                                                    : AppColors.amber
                                                        .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                scan.confirmedDisease?.contains(
                                                            'healthy') ==
                                                        true
                                                    ? Icons.favorite_rounded
                                                    : Icons.warning_amber_rounded,
                                                color: scan.confirmedDisease
                                                            ?.contains(
                                                                'healthy') ==
                                                        true
                                                    ? AppColors.success
                                                    : AppColors.amber,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    scan.confirmedDisease !=
                                                            null
                                                        ? _formatDisease(scan
                                                            .confirmedDisease!)
                                                        : 'Pending confirmation',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatDate(scan.createdAt),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppColors.textMuted,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  childCount: _scans.length,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
      // 5. Persistent action bar — Scan on the left, Water on the right.
      bottomNavigationBar: _plant == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/scan/${widget.plantId}'),
                        icon: const Icon(Icons.document_scanner_rounded,
                            color: AppColors.primary),
                        label: const Text(
                          'Scan',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isWatering ? null : _waterNow,
                        icon: _isWatering
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.water_drop_rounded),
                        label: const Text('Water now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kWaterColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _kWaterColor.withValues(alpha: 0.6),
                          disabledForegroundColor: Colors.white,
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
                  ],
                ),
              ),
            ),
    );
  }
}

/// Status card sitting under the hero photo. Shows identity (name + species),
/// a health chip, and a 2×2 grid of per-plant stats: next watering, last
/// watered, location, age.
class _PlantDetailsCard extends StatelessWidget {
  final Plant plant;
  final String nextWatering;
  final String age;
  final String lastWatered;
  final String added;

  const _PlantDetailsCard({
    required this.plant,
    required this.nextWatering,
    required this.age,
    required this.lastWatered,
    required this.added,
  });

  @override
  Widget build(BuildContext context) {
    final health = plant.latestHealth;
    final (healthLabel, healthColor) = switch (health) {
      'healthy' => ('Healthy', AppColors.success),
      'diseased' => ('Needs treatment', AppColors.amber),
      _ => ('Unknown', AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plant.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(plant.species,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HealthChip(label: healthLabel, color: healthColor),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.water_drop_rounded,
                  color: _kWaterColor,
                  label: 'NEXT WATERING',
                  value: nextWatering,
                ),
              ),
              Expanded(
                child: _StatTile(
                  icon: Icons.event_rounded,
                  color: _kWaterColor,
                  label: 'LAST WATERED',
                  value: lastWatered,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.place_rounded,
                  color: AppColors.primary,
                  label: 'LOCATION',
                  value: plant.location.isEmpty ? '—' : plant.location,
                ),
              ),
              Expanded(
                child: _StatTile(
                  icon: Icons.eco_rounded,
                  color: AppColors.amber,
                  label: 'PLANTED',
                  value: age,
                ),
              ),
            ],
          ),
          if (plant.notes != null && plant.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            Text(
              'NOTES',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(plant.notes!,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 14),
          Text('Added $added',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  final String label;
  final Color color;
  const _HealthChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick-log row for fertilize/mist: tinted icon, due status, "Log" button.
class _CareActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String due;
  final bool overdue;
  final bool busy;
  final VoidCallback onLog;
  const _CareActionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.due,
    required this.overdue,
    required this.busy,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
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
                Text(
                  due,
                  style: TextStyle(
                    color: overdue ? AppColors.amber : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        overdue ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: busy ? null : onLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: color.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
      ),
    );
  }
}

/// One cell in the 2×2 status grid. Tinted icon tile + label/value column.
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

/// Hero photo for the plant. Falls back to a soft gradient + leaf glyph when
/// the plant has no uploaded photo.
class _PlantPhoto extends StatelessWidget {
  final String? photoUrl;
  const _PlantPhoto({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: photoUrl != null
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                // Hero spans the screen width; cap decode size well under
                // full camera resolution.
                memCacheWidth: 900,
                placeholder: (_, _) => const SkeletonBox(radius: 0),
                errorWidget: (_, _, _) => const _PhotoPlaceholder(),
              )
            : const _PhotoPlaceholder(),
      ),
    );
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

/// Small square card summarizing one species care recommendation
/// (sunlight, watering cadence, ideal temperature, etc.).
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
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

/// Skeleton scaffold rendered while the plant + scan history are being
/// fetched. Mirrors the new layout: photo → details card → care strip → list.
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 180, height: 22, radius: 8),
                SizedBox(height: 12),
                SkeletonBox(width: 120, height: 14, radius: 6),
                SizedBox(height: 20),
                SkeletonBox(height: 44, radius: 10),
                SizedBox(height: 12),
                SkeletonBox(height: 44, radius: 10),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SkeletonBox(width: 120, height: 20, radius: 6),
          const SizedBox(height: 12),
          const SkeletonBox(height: 96, radius: 16),
          const SizedBox(height: 24),
          const SkeletonBox(width: 160, height: 20, radius: 6),
          const SizedBox(height: 12),
          for (int i = 0; i < 2; i++) ...[
            const SkeletonBox(height: 72, radius: 14),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

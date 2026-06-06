import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../models/scan.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';

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

  Future<void> _waterNow() async {
    if (_plant == null || _isWatering) return;
    setState(() => _isWatering = true);
    try {
      final updated = await ApiService.waterPlant(_plant!.id);
      if (!mounted) return;
      setState(() => _plant = updated);
      AppSnackBar.success(context, '${updated.name} watered');
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Failed to water: $e');
      }
    } finally {
      if (mounted) setState(() => _isWatering = false);
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

  /// Build the horizontal list of species care cards. Only cards with data
  /// are included, so plants whose species predates the knowledge base (or
  /// activities that don't apply, like misting for a tomato) are skipped.
  List<Widget> _buildCareTips(Plant plant) {
    final s = plant.speciesDetail;
    if (s == null) return const [];
    final cards = <Widget>[];

    if (s.sunlightLabel.isNotEmpty) {
      cards.add(_CareCard(
        icon: Icons.wb_sunny_outlined,
        value: s.sunlightLabel,
        label: 'SUNLIGHT',
      ));
    }
    if (s.defaultWateringFreqDays != null) {
      cards.add(_CareCard(
        icon: Icons.water_drop_outlined,
        value: 'Every ${s.defaultWateringFreqDays}d',
        label: 'WATER',
      ));
    }
    if (s.locationLabel.isNotEmpty) {
      cards.add(_CareCard(
        icon: Icons.home_outlined,
        value: s.locationLabel,
        label: 'LOCATION',
      ));
    }
    if (s.temperatureRange != null) {
      cards.add(_CareCard(
        icon: Icons.thermostat_outlined,
        value: s.temperatureRange!,
        label: 'TEMP',
      ));
    }
    if (s.defaultFertilizerFreqDays != null) {
      cards.add(_CareCard(
        icon: Icons.compost_outlined,
        value: 'Every ${s.defaultFertilizerFreqDays}d',
        label: 'FERTILIZE',
      ));
    }
    if (s.defaultMistingFreqDays != null) {
      cards.add(_CareCard(
        icon: Icons.cloud_outlined,
        value: 'Every ${s.defaultMistingFreqDays}d',
        label: 'MIST',
      ));
    }
    if (s.daysToHarvest != null) {
      cards.add(_CareCard(
        icon: Icons.eco_outlined,
        value: '~${s.daysToHarvest}d',
        label: 'HARVEST',
      ));
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
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error),
            onPressed: _deletePlant,
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
                      // Profile photo
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: _PlantPhoto(photoUrl: _plant!.photoUrl),
                        ),
                      ),

                      // Species care cards
                      if (_buildCareTips(_plant!).isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: SizedBox(
                              height: 96,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                children: _buildCareTips(_plant!),
                              ),
                            ),
                          ),
                        ),

                      // Plant info card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: Container(
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
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.eco_rounded,
                                        color: AppColors.primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _plant!.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _plant!.species,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(color: AppColors.divider),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _DetailStat(
                                        icon: Icons.place_outlined,
                                        label: 'LOCATION',
                                        value: _plant!.location.isEmpty
                                            ? '—'
                                            : _plant!.location,
                                      ),
                                    ),
                                    Expanded(
                                      child: _DetailStat(
                                        icon: Icons.water_drop_outlined,
                                        label: 'WATER EVERY',
                                        value:
                                            '${_plant!.wateringFreqDays}d',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _plant!.lastWatered == null
                                      ? 'Never watered'
                                      : 'Last watered ${_formatDate(_plant!.lastWatered!.toIso8601String())}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
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
                                    label:
                                        const Text('Water now'),
                                  ),
                                ),
                                if (_plant!.notes != null &&
                                    _plant!.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Divider(color: AppColors.divider),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Notes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _plant!.notes!,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                                const SizedBox(height: 16),
                                const Divider(color: AppColors.divider),
                                const SizedBox(height: 16),
                                Text(
                                  'Added ${_formatDate(_plant!.createdAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Scan button
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                context.push('/scan/${widget.plantId}'),
                            icon: const Icon(Icons.document_scanner_outlined),
                            label: const Text('Scan This Plant'),
                          ),
                        ),
                      ),

                      // Scan history header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          child: Text(
                            'Scan History',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),

                      // Scan list
                      _scans.isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
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
  const _CareCard({
    required this.icon,
    required this.value,
    required this.label,
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
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
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

class _DetailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Skeleton scaffold rendered while the plant + scan history are being
/// fetched. Mirrors the real layout: info card with hero shape, water-status
/// row, and a couple of scan-history rows.
class _PlantDetailSkeleton extends StatelessWidget {
  const _PlantDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
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
                SizedBox(height: 24),
                SkeletonBox(height: 180, radius: 14),
                SizedBox(height: 20),
                SkeletonBox(height: 48, radius: 12),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SkeletonBox(width: 160, height: 18, radius: 6),
          const SizedBox(height: 16),
          for (int i = 0; i < 2; i++) ...[
            const SkeletonBox(height: 72, radius: 14),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
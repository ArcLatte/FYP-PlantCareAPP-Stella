import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../models/scan.dart';
import '../../services/api_service.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${updated.name} watered')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to water: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete plant: $e')),
        );
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
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
                      // Plant info card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
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
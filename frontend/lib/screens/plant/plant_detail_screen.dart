import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/activity.dart';
import '../../models/plant.dart';
import '../../models/plant_stage.dart';
import '../../models/species.dart';
import '../../services/api_service.dart';
import '../../services/app_refresh_bus.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/xp_toast.dart';
import 'note_editor_screen.dart';

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

class _PlantDetailScreenState extends State<PlantDetailScreen>
    with SingleTickerProviderStateMixin {
  Plant? _plant;
  List<ActivityEvent> _activity = [];
  bool _isLoading = true;
  bool _isWatering = false;
  bool _isFertilizing = false;
  bool _isMisting = false;

  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _waterNow() async {
    if (_plant == null || _isWatering) return;
    setState(() => _isWatering = true);
    try {
      final updated = await ApiService.waterPlant(_plant!.id);
      if (!mounted) return;
      setState(() => _plant = updated);
      AppRefreshBus.plantsChanged();
      AppSnackBar.success(context, '${updated.name} watered');
      XpToast.flush(context);
      _refreshActivity();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          e,
          fallback: 'Could not log watering. Please try again.',
        );
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
      AppRefreshBus.plantsChanged();
      AppSnackBar.success(context, '${updated.name} fertilized');
      XpToast.flush(context);
      _refreshActivity();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          e,
          fallback: 'Could not log fertilizing. Please try again.',
        );
      }
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
      AppRefreshBus.plantsChanged();
      AppSnackBar.success(context, '${updated.name} misted');
      XpToast.flush(context);
      _refreshActivity();
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          e,
          fallback: 'Could not log misting. Please try again.',
        );
      }
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

  // ───────── Notes ─────────

  List<ActivityEvent> get _notes => _activity.where((e) => e.isNote).toList();

  /// History = care actions + scans only. Journal notes live in their own tab.
  List<ActivityEvent> get _logEvents =>
      _activity.where((e) => !e.isNote).toList();

  /// Open the editor to write a new journal note.
  Future<void> _addNote() async {
    if (_plant == null) return;
    final result = await Navigator.of(context).push<NoteEditResult>(
      MaterialPageRoute(
        builder: (_) =>
            NoteEditorScreen(plantId: _plant!.id, plantName: _plant!.name),
      ),
    );
    _applyNoteResult(result);
  }

  /// Open an existing note directly in the editor. Saving and deleting happen
  /// there; the returned [NoteEditResult] tells us how to update the list.
  Future<void> _openNote(ActivityEvent note) async {
    if (_plant == null || note.careLogId == null) return;
    final result = await Navigator.of(context).push<NoteEditResult>(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          plantId: _plant!.id,
          plantName: _plant!.name,
          existing: note,
        ),
      ),
    );
    _applyNoteResult(result, existing: note);
  }

  /// Reflects an editor result into [_activity] in place: replace an existing
  /// note, prepend a new one, or remove a deleted one.
  void _applyNoteResult(NoteEditResult? result, {ActivityEvent? existing}) {
    if (result == null || !mounted) return;
    if (result.deleted) {
      if (existing == null) return;
      setState(
        () => _activity = _activity
            .where((e) => !(e.isNote && e.careLogId == existing.careLogId))
            .toList(),
      );
      return;
    }
    final saved = result.saved;
    if (saved == null) return;
    setState(() {
      final exists = _activity.any(
        (e) => e.isNote && e.careLogId == saved.careLogId,
      );
      _activity = exists
          ? [
              for (final e in _activity)
                if (e.isNote && e.careLogId == saved.careLogId) saved else e,
            ]
          : [saved, ..._activity];
    });
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
        AppSnackBar.error(
          context,
          e,
          fallback: 'Could not delete the plant. Please try again.',
        );
      }
    }
  }

  String _formatDisease(String label) {
    return label.replaceAll('_', ' ').replaceAll('Tomato ', '');
  }

  /// Plant-health section for the Health & care tab. Returns null when there's
  /// no confirmed diagnosis (nothing useful to show); a slim green line when
  /// healthy; a prominent amber banner with the recommended action when
  /// diseased.
  Widget? _buildHealthCard(BuildContext context) {
    final disease = _plant!.latestDisease;

    if (disease == null) return null;

    if (disease.isHealthy) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: AppColors.success,
              size: 22,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Looks healthy',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                minimumSize: const Size(0, 44),
              ),
              onPressed: () => context.push(
                '/disease/${Uri.encodeComponent(disease.label)}',
              ),
              child: const Text('Read more'),
            ),
          ],
        ),
      );
    }

    final careText = disease.treatment.isNotEmpty
        ? disease.treatment
        : disease.careTips;
    const accent = AppColors.amber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NEEDS ATTENTION',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      disease.name.isNotEmpty
                          ? disease.name
                          : _formatDisease(disease.label),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (careText.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'WHAT TO DO',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            _ReadableText(
              careText,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.4,
              ),
              bulletColor: accent,
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 44),
              ),
              onPressed: () => context.push(
                '/disease/${Uri.encodeComponent(disease.label)}',
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('Read more about this disease'),
            ),
          ),
        ],
      ),
    );
  }

  // ───────── small helpers ─────────

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

  /// Whole days since the plant was planted (clamped to ≥0).
  int _ageDays(String createdAt) {
    final planted = DateTime.tryParse(createdAt);
    if (planted == null) return 0;
    final days = DateTime.now().difference(planted).inDays;
    return days < 0 ? 0 : days;
  }

  /// One Care row per applicable activity, each carrying the recommended
  /// cadence so the user sees "every N days" in plain words.
  List<Widget> _buildCareRows(Plant plant) {
    final s = plant.speciesDetail;
    final rows = <Widget>[
      _CareRow(
        icon: Icons.water_drop_rounded,
        color: _kWaterColor,
        label: 'Water',
        everyDays: plant.wateringFreqDays,
        next: _nextLabel(plant.daysUntilWater),
        last: _lastLabel(plant.lastWatered),
        overdue: (plant.daysUntilWater ?? 1) <= 0,
      ),
    ];
    if (plant.daysUntilFertilizer != null) {
      rows.add(
        _CareRow(
          icon: Icons.compost_rounded,
          color: AppColors.amber,
          label: 'Fertilize',
          everyDays: s?.defaultFertilizerFreqDays,
          next: _nextLabel(plant.daysUntilFertilizer),
          last: _lastLabel(plant.lastFertilized),
          overdue: (plant.daysUntilFertilizer ?? 1) <= 0,
        ),
      );
    }
    if (plant.daysUntilMisting != null) {
      rows.add(
        _CareRow(
          icon: Icons.cloud_rounded,
          color: _kMistColor,
          label: 'Mist',
          everyDays: s?.defaultMistingFreqDays,
          next: _nextLabel(plant.daysUntilMisting),
          last: _lastLabel(plant.lastMisted),
          overdue: (plant.daysUntilMisting ?? 1) <= 0,
        ),
      );
    }
    return rows;
  }

  /// Bottom sheet that lets the user pick which care action to log. Only the
  /// activities the species schedules are offered (Water always; Fertilize /
  /// Mist when applicable). Picking a row logs it and closes the sheet.
  Future<void> _showCareSheet(Plant plant) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final rows = <Widget>[
          _CareSheetRow(
            icon: Icons.water_drop_rounded,
            color: _kWaterColor,
            label: 'Water',
            subtitle:
                'Next ${_nextLabel(plant.daysUntilWater)} · Last ${_lastLabel(plant.lastWatered)}',
            overdue: (plant.daysUntilWater ?? 1) <= 0,
            onTap: () {
              Navigator.pop(ctx);
              _waterNow();
            },
          ),
        ];
        if (plant.daysUntilFertilizer != null) {
          rows.add(
            _CareSheetRow(
              icon: Icons.compost_rounded,
              color: AppColors.amber,
              label: 'Fertilize',
              subtitle:
                  'Next ${_nextLabel(plant.daysUntilFertilizer)} · Last ${_lastLabel(plant.lastFertilized)}',
              overdue: plant.daysUntilFertilizer! <= 0,
              onTap: () {
                Navigator.pop(ctx);
                _fertilizeNow();
              },
            ),
          );
        }
        if (plant.daysUntilMisting != null) {
          rows.add(
            _CareSheetRow(
              icon: Icons.cloud_rounded,
              color: _kMistColor,
              label: 'Mist',
              subtitle:
                  'Next ${_nextLabel(plant.daysUntilMisting)} · Last ${_lastLabel(plant.lastMisted)}',
              overdue: plant.daysUntilMisting! <= 0,
              onTap: () {
                Navigator.pop(ctx);
                _mistNow();
              },
            ),
          );
        }

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
                    'Log care',
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

  /// True when any applicable care activity is due today or overdue.
  bool _anyCareOverdue(Plant plant) {
    if ((plant.daysUntilWater ?? 1) <= 0) return true;
    if (plant.daysUntilFertilizer != null && plant.daysUntilFertilizer! <= 0) {
      return true;
    }
    if (plant.daysUntilMisting != null && plant.daysUntilMisting! <= 0) {
      return true;
    }
    return false;
  }

  bool get _isDiseased {
    final d = _plant?.latestDisease;
    return d != null && !d.isHealthy;
  }

  @override
  Widget build(BuildContext context) {
    final plant = _plant;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(plant?.name ?? 'Plant Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
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
                  final changed = await context.push<bool>(
                    '/plants/${widget.plantId}/edit',
                  );
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
                    Icon(
                      Icons.edit_outlined,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Edit plant',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Delete plant',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const _PlantDetailSkeleton()
          : plant == null
          ? const Center(
              child: Text(
                'Plant not found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              // NestedScrollView reports its body's overscroll at depth 2;
              // listening there makes the spinner appear at the very top of
              // the page (over the hero) instead of inside a tab.
              notificationPredicate: (n) => n.depth == 2,
              child: NestedScrollView(
                // Clamping (no rubber-band bounce) so the page feels solid.
                physics: const ClampingScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // Hero + care details scroll away with the page.
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _PlantHero(plant: plant),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _buildCareCard(context, plant),
                        ),
                      ],
                    ),
                  ),
                  // Tab pills pin to the top once scrolled up to.
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                    sliver: SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                          child: _TabPills(
                            controller: _tabController,
                            diseased: _isDiseased,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHealthCareTab(context, plant),
                    _buildNotesTab(context),
                    _buildHistoryTab(context),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: plant == null
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
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showCareSheet(plant),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Log care'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size.fromHeight(50),
                            side: const BorderSide(color: AppColors.cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: plant.scanAvailable
                              ? 'Choose this plant from the scan screen first.'
                              : 'Scanning is unavailable for custom species.',
                          child: ElevatedButton.icon(
                            onPressed: plant.scanAvailable
                                ? () => context.push('/scan')
                                : null,
                            icon: Icon(
                              plant.scanAvailable
                                  ? Icons.document_scanner_rounded
                                  : Icons.lock_rounded,
                            ),
                            label: Text(
                              plant.scanAvailable
                                  ? 'Scan plant'
                                  : 'Scan locked',
                            ),
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
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ───────── Tab 1: Health & care ─────────

  /// Combined plant-details card shown directly under the hero (and scrolling
  /// with the page): the care schedule with inline Log buttons, plus the
  /// growth / harvest progress bar.
  Widget _buildCareCard(BuildContext context, Plant plant) {
    final ageDays = _ageDays(plant.createdAt);
    final stage = PlantStage.forStreak(ageDays);
    final dh = plant.speciesDetail?.daysToHarvest;
    final double progress;
    final String caption;
    if (dh != null) {
      progress = (ageDays / dh).clamp(0.0, 1.0);
      final remaining = dh - ageDays;
      caption = remaining <= 0
          ? 'Ready to harvest'
          : '~${remaining}d to harvest';
    } else {
      final next = PlantStage.next(stage);
      if (next == null) {
        progress = 1;
        caption = 'Fully grown';
      } else {
        progress = ((ageDays - stage.minDays) / (next.minDays - stage.minDays))
            .clamp(0.0, 1.0);
        caption = 'Next: ${next.name}';
      }
    }

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
              Text(
                'Care schedule',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_anyCareOverdue(plant)) ...[
                const Spacer(),
                const _AttentionPill(),
              ],
            ],
          ),
          const SizedBox(height: 14),
          for (final (i, row) in _buildCareRows(plant).indexed) ...[
            if (i > 0) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 14),
            ],
            row,
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.eco_rounded,
                color: AppColors.primary.withValues(alpha: 0.9),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                stage.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                caption,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(
                progress >= 1 ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCareTab(BuildContext context, Plant plant) {
    final healthCard = _buildHealthCard(context);
    return _TabScroll(
      storageKey: 'tab-health',
      children: [
        if (healthCard != null) ...[healthCard, const SizedBox(height: 16)],
        if (plant.speciesDetail != null)
          _ConditionsCard(
            speciesName: plant.species,
            speciesId: plant.speciesDetail!.id,
            location: plant.location,
            wateringFreqDays: plant.wateringFreqDays,
            species: plant.speciesDetail!,
          ),
      ],
    );
  }

  // ───────── Tab 2: Notes (journal) ─────────

  Widget _buildNotesTab(BuildContext context) {
    final notes = _notes;
    return _TabScroll(
      storageKey: 'tab-notes',
      children: [
        ElevatedButton.icon(
          onPressed: _addNote,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add note'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),
        if (notes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'No notes yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Write down how your plant is doing — add a photo to\nwatch it change over time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ..._groupByDate(
            notes,
            (note) => _NoteCard(note: note, onTap: () => _openNote(note)),
          ),
      ],
    );
  }

  // ───────── Tab 3: History (care + scans) ─────────

  Widget _buildHistoryTab(BuildContext context) {
    final events = _logEvents;
    return _TabScroll(
      storageKey: 'tab-history',
      children: [
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
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
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          ..._groupByDate(
            events,
            (event) => _TimelineTile(
              event: event,
              formatDisease: _formatDisease,
              onTapScan: event.scanId != null
                  ? () => context.push('/result/${event.scanId}')
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Interleaves [_DateHeader]s into a reverse-chronological list of events,
/// emitting a header each time the calendar day changes.
List<Widget> _groupByDate(
  List<ActivityEvent> events,
  Widget Function(ActivityEvent) itemBuilder,
) {
  final widgets = <Widget>[];
  DateTime? lastDay;
  for (final e in events) {
    final d = e.createdAt;
    final day = DateTime(d.year, d.month, d.day);
    if (lastDay == null || day != lastDay) {
      widgets.add(_DateHeader(date: d));
      lastDay = day;
    }
    widgets.add(itemBuilder(e));
  }
  return widgets;
}

/// A single tab's scrollable body inside the [NestedScrollView]. Injects the
/// pinned tab-bar overlap so content starts below it and keeps its own scroll
/// position per tab. Pull-to-refresh is handled by the page-level
/// [RefreshIndicator] so the spinner shows at the top of the whole page.
class _TabScroll extends StatelessWidget {
  final String storageKey;
  final List<Widget> children;

  const _TabScroll({required this.storageKey, required this.children});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: PageStorageKey<String>(storageKey),
          // Always scrollable so pull-to-refresh works even with short
          // content; clamping so the section below the tabs doesn't bounce.
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              sliver: SliverList(delegate: SliverChildListDelegate(children)),
            ),
          ],
        );
      },
    );
  }
}

/// Pinned header that hosts the tab pills. Paints the page background so
/// scrolled content doesn't show through behind the bar.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _TabBarDelegate({required this.child});

  static const double _height = 70;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.background, child: child);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => oldDelegate.child != child;
}

/// Hero photo with a bottom gradient scrim and the plant's identity overlaid:
/// name, then "species · location", and a health badge.
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

    // species · location subtitle pieces.
    final subtitleParts = <Widget>[];
    if (plant.species.isNotEmpty) {
      subtitleParts.add(
        Flexible(
          child: Text(
            plant.species,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    if (plant.location.isNotEmpty) {
      if (subtitleParts.isNotEmpty) {
        subtitleParts.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('·', style: TextStyle(color: Colors.white54)),
          ),
        );
      }
      subtitleParts.add(
        const Icon(Icons.place_rounded, color: Colors.white70, size: 14),
      );
      subtitleParts.add(const SizedBox(width: 3));
      subtitleParts.add(
        Flexible(
          child: Text(
            plant.location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

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
                    memCacheWidth: 900,
                    placeholder: (_, _) => const SkeletonBox(radius: 0),
                    errorWidget: (_, _, _) => const _PhotoPlaceholder(),
                  )
                : const _PhotoPlaceholder(),
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
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
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
                        if (subtitleParts.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(children: subtitleParts),
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

/// Solid, high-contrast health pill for the hero overlay.
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

/// The three tab pills (Health & care / Notes / History) shown under the
/// essentials bar. The Health pill carries an amber dot when the plant is
/// diseased so the alert is visible from any tab.
class _TabPills extends StatelessWidget {
  final TabController controller;
  final bool diseased;
  const _TabPills({required this.controller, required this.diseased});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        labelPadding: EdgeInsets.zero,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Health & care'),
                if (diseased) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(height: 38, text: 'Notes'),
          const Tab(height: 38, text: 'History'),
        ],
      ),
    );
  }
}

/// Merged "Conditions & care" card: recommended conditions as plain large-label
/// rows, a care tip from the species' growing tips (expandable), and a link to
/// the full species reference page.
class _ConditionsCard extends StatelessWidget {
  final String speciesName;
  final int speciesId;
  final String location;
  final int wateringFreqDays;
  final SpeciesDetail species;

  const _ConditionsCard({
    required this.speciesName,
    required this.speciesId,
    required this.location,
    required this.wateringFreqDays,
    required this.species,
  });

  @override
  Widget build(BuildContext context) {
    final s = species;

    final rows = <Widget>[];
    if (s.sunlightLabel.isNotEmpty) {
      rows.add(
        _ConditionRow(
          icon: Icons.wb_sunny_rounded,
          color: AppColors.amber,
          label: 'Sunlight',
          value: s.sunlightLabel,
        ),
      );
    }
    if (s.temperatureRange != null) {
      rows.add(
        _ConditionRow(
          icon: Icons.thermostat_rounded,
          color: _kWaterColor,
          label: 'Ideal temperature',
          value: s.temperatureRange!,
        ),
      );
    }
    rows.add(
      _ConditionRow(
        icon: Icons.water_drop_rounded,
        color: _kWaterColor,
        label: 'Water',
        value: 'Every $wateringFreqDays days',
      ),
    );
    if (s.locationLabel.isNotEmpty || location.isNotEmpty) {
      rows.add(
        _ConditionRow(
          icon: Icons.place_rounded,
          color: AppColors.primary,
          label: 'Location',
          value: location.isNotEmpty ? location : s.locationLabel,
        ),
      );
    }

    final tip = s.growingTips.trim();
    final hasTip = tip.isNotEmpty;

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
          Text(
            'Conditions & care tips',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 14),
            row,
          ],
          if (hasTip) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 14),
            const Text(
              'CARE TIP',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            _ReadableText(
              tip,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.4,
              ),
              bulletColor: AppColors.primary,
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 44),
              ),
              onPressed: () => context.push('/species/$speciesId'),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: Text(
                speciesName.isNotEmpty
                    ? 'Read more about $speciesName'
                    : 'Read more about this species',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One recommended-condition row: tinted icon, plain label, value.
class _ConditionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _ConditionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Small amber "Needs attention" pill shown in the Care card header.
class _AttentionPill extends StatelessWidget {
  const _AttentionPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.error_outline_rounded, color: AppColors.amber, size: 14),
          SizedBox(width: 5),
          Text(
            'Needs attention',
            style: TextStyle(
              color: AppColors.amber,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single care activity: tinted icon, name, recommended cadence + next-due +
/// last-done. Read-only info; logging happens from the bottom action bar.
class _CareRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int? everyDays;
  final String next;
  final String last;
  final bool overdue;

  const _CareRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.everyDays,
    required this.next,
    required this.last,
    required this.overdue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (everyDays != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'every $everyDays days',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Next ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: next,
                      style: TextStyle(
                        color: overdue
                            ? AppColors.amber
                            : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: overdue ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '   ·   Last $last',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One pickable action row in the "Log care" bottom sheet: tinted icon, name,
/// and its next-due / last-done subtitle. Tapping it logs that activity.
class _CareSheetRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final bool overdue;
  final VoidCallback onTap;

  const _CareSheetRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.overdue,
    required this.onTap,
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

/// Renders care/treatment text in the most readable shape: a bulleted list when
/// the text reads as multiple steps (separated by line breaks or sentences), or
/// a plain short paragraph otherwise.
class _ReadableText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color bulletColor;

  const _ReadableText(
    this.text, {
    required this.style,
    required this.bulletColor,
  });

  @override
  Widget build(BuildContext context) {
    final points = _bulletize(text);
    if (points == null) {
      return Text(text.trim(), style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, p) in points.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: i == points.length - 1 ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7, right: 10),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: bulletColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: Text(p, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Splits [raw] into step strings when it reads better as bullets (≥2 steps),
/// else returns null so the caller renders a single paragraph. Recognises
/// explicit line breaks / "1." / "-" markers first, then falls back to
/// splitting on sentence boundaries.
List<String>? _bulletize(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;

  String clean(String s) =>
      s.trim().replaceFirst(RegExp(r'^[-•*\d.)\s]+'), '').trim();

  if (t.contains('\n')) {
    final lines = t.split('\n').map(clean).where((e) => e.isNotEmpty).toList();
    return lines.length >= 2 ? lines : null;
  }

  final parts = t
      .split(RegExp(r'(?<=[.;])\s+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => e.endsWith('.') ? e.substring(0, e.length - 1) : e)
      .toList();
  return parts.length >= 2 ? parts : null;
}

/// A compact journal preview in the Notes tab: optional photo, the note's
/// title (falling back to the first line of the body), a one-line snippet, and
/// the time of day. Tapping it opens the full reader.
class _NoteCard extends StatelessWidget {
  final ActivityEvent note;
  final VoidCallback? onTap;
  const _NoteCard({required this.note, this.onTap});

  static String _plainMarkdown(String value) => value
      .replaceAll('**', '')
      .replaceAllMapped(RegExp(r'_([^_]+)_'), (match) => match.group(1)!)
      .trim();

  static String _timeLabel(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h12:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Strips a leading bullet marker ("• ", "- ", "* ") for clean preview text.
  static String _stripBullet(String s) =>
      s.replaceFirst(RegExp(r'^\s*(?:•|[-*])\s+'), '').trim();

  @override
  Widget build(BuildContext context) {
    final rawTitle = note.noteTitle?.trim() ?? '';
    final body = note.note?.trim() ?? '';

    String title;
    String preview;
    if (rawTitle.isNotEmpty) {
      title = _plainMarkdown(rawTitle);
      preview = _plainMarkdown(_stripBullet(body.replaceAll('\n', ' ')));
    } else if (body.isNotEmpty) {
      final lines = body.split('\n');
      final idx = lines.indexWhere((l) => l.trim().isNotEmpty);
      title = _plainMarkdown(_stripBullet(lines[idx]));
      preview = _plainMarkdown(_stripBullet(lines.skip(idx + 1).join(' ')));
    } else {
      title = 'Photo';
      preview = '';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            if (note.noteImages.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: SizedBox(
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: note.noteImages.first.url,
                        fit: BoxFit.cover,
                        memCacheWidth: 900,
                        placeholder: (_, _) =>
                            const SkeletonBox(height: 150, radius: 0),
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                      if (note.noteImages.length > 1)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${note.noteImages.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _timeLabel(note.createdAt),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textMuted,
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

/// A date divider shown between days in the Notes and History timelines.
class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    final year = date.year == now.year ? '' : ' ${date.year}';
    return '${date.day} ${_months[date.month - 1]}$year';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Text(
        _label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
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
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(d.year, d.month, d.day)).inDays;
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
        return (
          icon: Icons.water_drop_rounded,
          color: _kWaterColor,
          title: 'Watered',
        );
      case 'fertilize':
        return (
          icon: Icons.compost_rounded,
          color: AppColors.amber,
          title: 'Fertilized',
        );
      case 'mist':
        return (icon: Icons.cloud_rounded, color: _kMistColor, title: 'Misted');
      default:
        return (
          icon: Icons.eco_rounded,
          color: AppColors.primary,
          title: 'Care',
        );
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
                Text(v.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  _relative(event.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (tappable)
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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

/// Skeleton scaffold rendered while the plant + history are being fetched.
class _PlantDetailSkeleton extends StatelessWidget {
  const _PlantDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 150, radius: 20),
          const SizedBox(height: 12),
          const SkeletonBox(height: 120, radius: 16),
          const SizedBox(height: 14),
          const SkeletonBox(height: 46, radius: 999),
          const SizedBox(height: 16),
          const SkeletonBox(height: 96, radius: 16),
          const SizedBox(height: 16),
          const SkeletonBox(height: 180, radius: 16),
        ],
      ),
    );
  }
}

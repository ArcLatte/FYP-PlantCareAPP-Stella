import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_error.dart';
import '../../core/theme.dart';
import '../../models/scan.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/xp_toast.dart';

/// Scan result review screen.
///
/// Layout (top → bottom): the scanned photo, a card of the top-3 predictions
/// the user selects between, and a pinned Confirm button. Confirming records
/// the diagnosis and reveals care info inline with a "Read more" link to the
/// disease page.
class ResultScreen extends StatefulWidget {
  final int scanId;

  const ResultScreen({super.key, required this.scanId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  ScanResult? _scan;
  String? _selectedLabel;
  bool _isLoading = true;
  bool _isConfirming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadScan();
    // Surface any XP / unlocks the scan endpoint awarded (lastXpResult was
    // populated inside ApiService.scanPlant). Has to run after first frame
    // so the ScaffoldMessenger is attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) XpToast.flush(context);
    });
  }

  Future<void> _loadScan() async {
    try {
      final scan = await ApiService.getScan(widget.scanId);
      setState(() {
        _scan = scan;
        // Default selection: the already-confirmed label, else the top pick.
        _selectedLabel = scan.confirmedDisease ??
            (scan.predictions.isNotEmpty ? scan.predictions.first.label : null);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDisease(String label) async {
    // Capture the (root) messenger before the async gap so the confirmation
    // snackbar survives the navigation to the plant page.
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isConfirming = true;
      _errorMessage = null;
    });
    try {
      final updated = await ApiService.confirmDisease(widget.scanId, label);
      if (!mounted) return;
      final plantId = updated.plantId ?? _scan?.plantId;
      final healthy = label.toLowerCase().contains('healthy');
      final name = updated.diseaseName ?? _formatLabel(label);
      messenger.showSnackBar(
        _savedSnack(healthy ? 'Marked healthy' : 'Diagnosis saved — $name'),
      );
      // One tap → straight to the plant page, which already shows the
      // confirmed diagnosis with treatment / care tips (latest_disease).
      if (plantId != null) {
        context.go('/plants/$plantId');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppErrorMessages.message(
          e,
          fallback: 'Could not save the diagnosis. Please try again.',
        );
        _isConfirming = false;
      });
    }
  }

  SnackBar _savedSnack(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 3),
    );
  }

  void _goBack() {
    final plantId = _scan?.plantId;
    if (plantId != null) {
      context.go('/plants/$plantId');
    } else {
      context.go('/home');
    }
  }

  String _formatLabel(String label) {
    return label
        .replaceAll('_', ' ')
        .replaceAll('Tomato ', '')
        .replaceAll('  ', ' ')
        .trim();
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.7) return AppColors.success;
    if (confidence >= 0.4) return AppColors.amber;
    return AppColors.error;
  }

  bool get _isHealthy =>
      _scan?.confirmedDisease?.toLowerCase().contains('healthy') == true;

  bool get _isConfirmed => _scan?.confirmedDisease != null;

  @override
  Widget build(BuildContext context) {
    final scan = _scan;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Scan Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
      ),
      body: _isLoading
          ? const _ResultSkeleton()
          : scan == null
              ? const Center(
                  child: Text(
                    'Result not found',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Scanned image, centered.
                        _ScanImage(imageUrl: scan.imageUrl),
                        const SizedBox(height: 24),

                        // 2. Confirmed diagnosis + care info (after confirming).
                        if (_isConfirmed) ...[
                          _buildConfirmedSection(scan),
                          const SizedBox(height: 24),
                        ],

                        // 3. Top predictions — selectable.
                        Text(
                          'Top Predictions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scan.alternativesLocked
                              ? 'High-confidence result — other candidates are '
                                  'shown for reference only.'
                              : 'Select the correct diagnosis, then confirm '
                                  'below.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),

                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        ...scan.predictions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final prediction = entry.value;
                          final rank = index + 1;
                          // High-confidence scans lock every candidate below
                          // the top one: they can't be selected or confirmed.
                          final locked = scan.alternativesLocked && rank > 1;
                          return _PredictionTile(
                            rank: rank,
                            name: prediction.name ??
                                _formatLabel(prediction.label),
                            imageUrl: prediction.imageUrl,
                            confidence: prediction.confidence,
                            color: _confidenceColor(prediction.confidence),
                            selected: _selectedLabel == prediction.label,
                            locked: locked,
                            onTap: (_isConfirming || locked)
                                ? null
                                : () => setState(
                                      () => _selectedLabel = prediction.label,
                                    ),
                            // Only offer "confirm from detail" for a label that
                            // is actually confirmable (drop scanId when locked).
                            onReadMore: () => context.push(
                              '/disease/${Uri.encodeComponent(prediction.label)}'
                              '${locked ? '' : '?scanId=${widget.scanId}'}',
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
      // Pinned Confirm / Done action.
      bottomNavigationBar:
          (_isLoading || scan == null) ? null : _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    // When reopened on an already-confirmed scan and the selection still
    // matches the confirmed label, there's nothing to submit — just go back.
    final backToPlant =
        _isConfirmed && _selectedLabel == _scan!.confirmedDisease;
    return SafeArea(
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
          child: _isConfirming
              ? const SizedBox(
                  height: 52,
                  child: Center(child: CircularProgressIndicator()),
                )
              : backToPlant
                  ? ElevatedButton.icon(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back to plant'),
                    )
                  : ElevatedButton(
                      onPressed: _selectedLabel == null
                          ? null
                          : () => _confirmDisease(_selectedLabel!),
                      child: Text(
                        _isConfirmed ? 'Update diagnosis' : 'Confirm diagnosis',
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildConfirmedSection(ScanResult scan) {
    final label = scan.confirmedDisease!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isHealthy
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHealthy
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.amber.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                _isHealthy
                    ? Icons.favorite_rounded
                    : Icons.warning_amber_rounded,
                color: _isHealthy ? AppColors.success : AppColors.amber,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _isHealthy ? 'Healthy Plant!' : 'Disease Detected',
                style: TextStyle(
                  color: _isHealthy ? AppColors.success : AppColors.amber,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                scan.diseaseName ?? _formatLabel(label),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        if (scan.treatment != null && scan.treatment!.isNotEmpty) ...[
          const SizedBox(height: 20),
          _careCard('Treatment', scan.treatment!),
        ],
        if (scan.careTips != null && scan.careTips!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _careCard('Care actions', scan.careTips!),
        ],

        const SizedBox(height: 16),
        OutlinedButton.icon(
          // Already confirmed — the detail page opens in read-only mode (no
          // scanId, so no confirm bar).
          onPressed: () =>
              context.push('/disease/${Uri.encodeComponent(label)}'),
          icon: const Icon(Icons.menu_book_rounded, size: 18),
          label: const Text('Read more about this'),
        ),
      ],
    );
  }

  Widget _careCard(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Container(
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
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

/// The scanned photo, centered with rounded corners. Falls back to a neutral
/// placeholder when no image URL is available.
class _ScanImage extends StatelessWidget {
  final String? imageUrl;

  const _ScanImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1,
          child: imageUrl == null || imageUrl!.isEmpty
              ? Container(
                  color: AppColors.surfaceLight,
                  child: const Icon(
                    Icons.local_florist_rounded,
                    size: 64,
                    color: AppColors.textMuted,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (c, _) =>
                      Container(color: AppColors.surfaceLight),
                  errorWidget: (c, _, _) => Container(
                    color: AppColors.surfaceLight,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A single selectable prediction card: an example reference photo (to compare
/// against the scan), the disease name with rank + confidence bar + %, a radio
/// selection indicator, and a per-card "Read more" link.
class _PredictionTile extends StatelessWidget {
  final int rank;
  final String name;
  final String? imageUrl;
  final double confidence;
  final Color color;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;
  final VoidCallback onReadMore;

  const _PredictionTile({
    required this.rank,
    required this.name,
    required this.imageUrl,
    required this.confidence,
    required this.color,
    required this.selected,
    required this.locked,
    required this.onTap,
    required this.onReadMore,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;
    // Locked alternatives are dimmed and non-selectable, but still show their
    // photo / confidence and keep the "Read more" link working.
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.cardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Example reference photo with a rank badge.
              _Thumb(imageUrl: imageUrl, rank: rank, isTop: isTop),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(confidence * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        locked
                            ? const Icon(
                                Icons.lock_rounded,
                                color: AppColors.textMuted,
                                size: 20,
                              )
                            : Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                size: 22,
                              ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: confidence,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onReadMore,
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: const Text('Read more'),
                      ),
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
}

/// Square reference thumbnail with a rank badge in the corner. Falls back to a
/// leaf glyph when no example image exists for the label.
class _Thumb extends StatelessWidget {
  final String? imageUrl;
  final int rank;
  final bool isTop;

  const _Thumb({
    required this.imageUrl,
    required this.rank,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: imageUrl == null || imageUrl!.isEmpty
                  ? Container(
                      color: AppColors.surfaceLight,
                      child: const Icon(
                        Icons.local_florist_rounded,
                        color: AppColors.textMuted,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (c, _) =>
                          Container(color: AppColors.surfaceLight),
                      errorWidget: (c, _, _) => Container(
                        color: AppColors.surfaceLight,
                        child: const Icon(
                          Icons.local_florist_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isTop ? AppColors.primary : Colors.black).withValues(
                  alpha: 0.75,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton scaffold for the scan-result screen. Mirrors the real layout:
/// the hero image, a heading, then a couple of prediction rows.
class _ResultSkeleton extends StatelessWidget {
  const _ResultSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(height: 280, radius: 20),
            SizedBox(height: 24),
            SkeletonBox(width: 180, height: 18, radius: 6),
            SizedBox(height: 16),
            SkeletonBox(height: 64, radius: 16),
            SizedBox(height: 12),
            SkeletonBox(height: 64, radius: 16),
            SizedBox(height: 12),
            SkeletonBox(height: 64, radius: 16),
          ],
        ),
      ),
    );
  }
}

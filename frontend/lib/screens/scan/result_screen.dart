import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/scan.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/xp_toast.dart';

class ResultScreen extends StatefulWidget {
  final int scanId;

  const ResultScreen({super.key, required this.scanId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  ScanResult? _scan;
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDisease(String label) async {
    setState(() {
      _isConfirming = true;
      _errorMessage = null;
    });
    try {
      final updated = await ApiService.confirmDisease(widget.scanId, label);
      setState(() {
        _scan = updated;
        _isConfirming = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isConfirming = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: _isLoading
          ? const _ResultSkeleton()
          : _scan == null
              ? const Center(
                  child: Text('Result not found',
                      style: TextStyle(color: AppColors.textSecondary)))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Confirmed result banner
                        if (_scan!.confirmedDisease != null) ...[
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
                                  color: _isHealthy
                                      ? AppColors.success
                                      : AppColors.amber,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _isHealthy ? 'Healthy Plant!' : 'Disease Detected',
                                  style: TextStyle(
                                    color: _isHealthy
                                        ? AppColors.success
                                        : AppColors.amber,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatLabel(_scan!.confirmedDisease!),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Treatment & Care Tips
                        if (_scan!.treatment != null) ...[
                          Text(
                            'Treatment',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: AppColors.cardBorder),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.cardShadow,
                                  blurRadius: 12,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _scan!.treatment!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        if (_scan!.careTips != null) ...[
                          Text(
                            'Care Tips',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: AppColors.cardBorder),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.cardShadow,
                                  blurRadius: 12,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _scan!.careTips!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Predictions
                        Text(
                          _scan!.confirmedDisease != null
                              ? 'All Predictions'
                              : 'Top Predictions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _scan!.confirmedDisease != null
                              ? 'Confirm the correct diagnosis below'
                              : 'Select the correct diagnosis to confirm',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),

                        // Error
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Prediction cards
                        ..._scan!.predictions.asMap().entries.map((entry) {
                          final index = entry.key;
                          final prediction = entry.value;
                          final isConfirmed = _scan!.confirmedDisease ==
                              prediction.label;
                          final isTop = index == 0;

                          return GestureDetector(
                            onTap: _isConfirming
                                ? null
                                : () => _confirmDisease(prediction.label),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isConfirmed
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isConfirmed
                                      ? AppColors.primary
                                      : AppColors.cardBorder,
                                  width: isConfirmed ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Rank badge
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isTop
                                          ? AppColors.primary.withValues(alpha: 0.2)
                                          : AppColors.surfaceLight,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '#${index + 1}',
                                        style: TextStyle(
                                          color: isTop
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Label
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatLabel(prediction.label),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        // Confidence bar
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: prediction.confidence,
                                            backgroundColor:
                                                AppColors.surfaceLight,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              _confidenceColor(
                                                  prediction.confidence),
                                            ),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Confidence %
                                  Text(
                                    '${(prediction.confidence * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: _confidenceColor(
                                          prediction.confidence),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (isConfirmed) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 24),

                        // Done button
                        ElevatedButton(
                          onPressed: () => context.go('/home'),
                          child: const Text('Back to Home'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

/// Skeleton scaffold for the scan-result screen. Mirrors the real layout:
/// a banner card on top, the hero image, then a couple of prediction rows.
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
            SkeletonBox(height: 88, radius: 16),
            SizedBox(height: 20),
            SkeletonBox(height: 220, radius: 16),
            SizedBox(height: 24),
            SkeletonBox(width: 180, height: 18, radius: 6),
            SizedBox(height: 16),
            SkeletonBox(height: 56, radius: 12),
            SizedBox(height: 12),
            SkeletonBox(height: 56, radius: 12),
            SizedBox(height: 12),
            SkeletonBox(height: 56, radius: 12),
          ],
        ),
      ),
    );
  }
}
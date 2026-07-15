import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/disease.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';

/// Full knowledge-base page for a disease ("read more"). Reached from the scan
/// result screen and the plant profile disease section via `/disease/:label`.
///
/// When [scanId] is provided (came from a scan), a persistent "Confirm this
/// diagnosis" button is shown so the user can confirm straight from here. When
/// it's null (opened from the plant profile) there is no confirm button.
class DiseaseDetailScreen extends StatefulWidget {
  final String label;
  final int? scanId;

  const DiseaseDetailScreen({super.key, required this.label, this.scanId});

  @override
  State<DiseaseDetailScreen> createState() => _DiseaseDetailScreenState();
}

class _DiseaseDetailScreenState extends State<DiseaseDetailScreen> {
  Disease? _disease;
  bool _isLoading = true;
  bool _isConfirming = false;
  final _pageController = PageController();
  int _page = 0;

  bool get _confirmMode => widget.scanId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final disease = await ApiService.getDisease(widget.label);
      if (mounted) {
        setState(() {
          _disease = disease;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirm() async {
    // Capture the (root) messenger before the async gap so the confirmation
    // snackbar survives the navigation to the plant page.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isConfirming = true);
    try {
      final result = await ApiService.confirmDisease(widget.scanId!, widget.label);
      if (!mounted) return;
      final healthy = widget.label.toLowerCase().contains('healthy');
      final name = result.diseaseName ?? _disease?.name ?? '';
      messenger.showSnackBar(_savedSnack(
        healthy
            ? 'Marked healthy'
            : 'Diagnosis saved${name.isNotEmpty ? ' — $name' : ''}',
      ));
      // One tap → straight to the plant page (which shows the confirmed
      // diagnosis), rather than bouncing back through the result screen.
      final plantId = result.plantId;
      if (plantId != null) {
        context.go('/plants/$plantId');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConfirming = false);
        AppSnackBar.error(
          context,
          e,
          fallback: 'Could not save the diagnosis. Please try again.',
        );
      }
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

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the source link')),
      );
    }
  }

  Color _severityColor(Disease d) {
    if (d.isHealthy) return AppColors.success;
    switch (d.severity) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.amber;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Split prose into individual sentences for bullet display.
  List<String> _bullets(String text) {
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final d = _disease;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text(d?.name ?? 'Disease')),
      body: _isLoading
          ? const _DiseaseSkeleton()
          : d == null
              ? const Center(
                  child: Text('Disease details not found',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : SafeArea(
                  bottom: false,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        24, 24, 24, _confirmMode ? 110 : 24),
                    children: [
                      // Swipeable reference image carousel.
                      if (d.allImages.isNotEmpty) _ImageCarousel(
                        images: d.allImages,
                        controller: _pageController,
                        page: _page,
                        onPage: (i) => setState(() => _page = i),
                      ),
                      if (d.allImages.isNotEmpty) const SizedBox(height: 20),

                      // Header: name + severity chip.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.name,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          if (d.severity.isNotEmpty)
                            _SeverityChip(
                              label: d.isHealthy
                                  ? 'Healthy'
                                  : '${d.severity[0].toUpperCase()}${d.severity.substring(1)} severity',
                              color: _severityColor(d),
                            ),
                        ],
                      ),
                      if (d.speciesName != null &&
                          d.speciesName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(d.speciesName!,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],

                      // Intro / overview as plain text (no card).
                      if (d.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          d.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.4),
                        ),
                      ],

                      _BulletSection(
                        title: 'Symptoms',
                        icon: Icons.search_rounded,
                        items: _bullets(d.symptoms),
                      ),
                      _BulletSection(
                        title: 'Cause',
                        icon: Icons.coronavirus_rounded,
                        items: _bullets(d.cause),
                      ),
                      _BulletSection(
                        title: 'Treatment',
                        icon: Icons.healing_rounded,
                        items: _bullets(d.treatment),
                        accent: AppColors.primary,
                      ),
                      _BulletSection(
                        title: 'Care actions',
                        icon: Icons.eco_rounded,
                        items: _bullets(d.careTips),
                        accent: AppColors.primary,
                      ),
                      _BulletSection(
                        title: 'Prevention',
                        icon: Icons.shield_outlined,
                        items: _bullets(d.prevention),
                      ),

                      if (d.sourceUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openSource(d.sourceUrl),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(
                            d.sourceName.isNotEmpty
                                ? 'Learn more · ${d.sourceName}'
                                : 'Learn more',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
      bottomNavigationBar: (!_confirmMode || d == null) ? null : _confirmBar(),
    );
  }

  Widget _confirmBar() {
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
              : ElevatedButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Confirm this diagnosis'),
                ),
        ),
      ),
    );
  }
}

/// Horizontal swipeable image carousel with page dots.
class _ImageCarousel extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int page;
  final ValueChanged<int> onPage;

  const _ImageCarousel({
    required this.images,
    required this.controller,
    required this.page,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: PageView.builder(
              controller: controller,
              onPageChanged: onPage,
              itemCount: images.length,
              itemBuilder: (context, i) => CachedNetworkImage(
                imageUrl: images[i],
                fit: BoxFit.cover,
                placeholder: (c, _) =>
                    Container(color: AppColors.surfaceLight),
                errorWidget: (c, _, _) => Container(
                  color: AppColors.surfaceLight,
                  child: const Icon(Icons.image_not_supported_rounded,
                      size: 40, color: AppColors.textMuted),
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == page ? AppColors.primary : AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A titled section rendered as a bullet list. Hidden when there's no content.
class _BulletSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final Color? accent;

  const _BulletSection({
    required this.title,
    required this.icon,
    required this.items,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final color = accent ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent ?? AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SeverityChip({required this.label, required this.color});

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

class _DiseaseSkeleton extends StatelessWidget {
  const _DiseaseSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SkeletonBox(height: 220, radius: 20),
          SizedBox(height: 20),
          SkeletonBox(width: 200, height: 24, radius: 6),
          SizedBox(height: 24),
          SkeletonBox(width: 120, height: 18, radius: 6),
          SizedBox(height: 10),
          SkeletonBox(height: 60, radius: 12),
          SizedBox(height: 20),
          SkeletonBox(width: 120, height: 18, radius: 6),
          SizedBox(height: 10),
          SkeletonBox(height: 60, radius: 12),
        ],
      ),
    );
  }
}

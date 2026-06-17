import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/disease.dart';
import '../../models/species.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton.dart';

/// Library hub: a browsable reference of plant species and diseases, reached
/// from the "Library" tab in the bottom pill bar (`/library`). Two segments —
/// Plants (species) and Diseases (grouped by the plant they affect) — both
/// filtered by a single search box.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<SpeciesDetail> _species = [];
  List<Disease> _diseases = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final results = await Future.wait([
        ApiService.getSpecies(),
        ApiService.getDiseases(),
      ]);
      if (!mounted) return;
      final speciesMaps = results[0] as List<Map<String, dynamic>>;
      setState(() {
        _species = speciesMaps.map(SpeciesDetail.fromJson).toList();
        _diseases = results[1] as List<Disease>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  List<SpeciesDetail> get _filteredSpecies {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _species;
    return _species
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.scientificName.toLowerCase().contains(q))
        .toList();
  }

  List<Disease> get _filteredDiseases {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _diseases;
    return _diseases
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            (d.speciesName ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            // Search across both segments.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search plants & diseases…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            // Rounded segmented control — mirrors the app's pill aesthetic
            // instead of the default underlined Material tabs.
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _SegmentedTabs(),
            ),
            Expanded(
              child: _hasError
                  ? _ErrorState(onRetry: _load)
                  : TabBarView(
                      children: [
                        _SpeciesTab(
                          isLoading: _isLoading,
                          species: _filteredSpecies,
                        ),
                        _DiseasesTab(
                          isLoading: _isLoading,
                          diseases: _filteredDiseases,
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

// ─── Segmented (Plants / Diseases) control ────────────────────────

/// A rounded "segmented control" built on the ambient [TabController] so it
/// keeps swipe-to-switch behaviour while looking like the app's pill chips: a
/// soft track with a solid primary pill sliding under the active segment.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(20),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(height: 40, text: 'Plants'),
          Tab(height: 40, text: 'Diseases'),
        ],
      ),
    );
  }
}

// ─── Plants (species) tab ─────────────────────────────────────────

class _SpeciesTab extends StatelessWidget {
  final bool isLoading;
  final List<SpeciesDetail> species;

  const _SpeciesTab({required this.isLoading, required this.species});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return GridView.count(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
        children: const [
          PlantCardSkeleton(),
          PlantCardSkeleton(),
          PlantCardSkeleton(),
          PlantCardSkeleton(),
        ],
      );
    }
    if (species.isEmpty) {
      return const _EmptyState(
        icon: Icons.local_florist_outlined,
        title: 'No plants found',
        message: 'Try a different search.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: species.length,
      itemBuilder: (context, i) => _SpeciesCard(species: species[i]),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final SpeciesDetail species;

  const _SpeciesCard({required this.species});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/library/species/${species.id}'),
      child: Container(
        // Chrome matches the home "_PlantGridCard": rounded 18, soft shadow,
        // no border — so the two grids read as one design language.
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image area. Species carry no photo, so we show the SAME
            // soft-mint + leaf placeholder the home grid uses for a plant
            // whose photo is missing — keeping the placeholder consistent.
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Container(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.local_florist_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),
            ),
            // Text area.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    species.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (species.scientificName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      species.scientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (species.sunlightLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny_outlined,
                            size: 13, color: AppColors.amber),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            species.sunlightLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Diseases tab (grouped by plant species) ──────────────────────

class _DiseasesTab extends StatelessWidget {
  final bool isLoading;
  final List<Disease> diseases;

  const _DiseasesTab({required this.isLoading, required this.diseases});

  /// Bucket diseases under the plant they affect, sorted alphabetically with
  /// any species-less entries collected last under "Other".
  List<MapEntry<String, List<Disease>>> _grouped() {
    const otherKey = 'Other';
    final groups = <String, List<Disease>>{};
    for (final d in diseases) {
      final name = (d.speciesName ?? '').trim();
      groups.putIfAbsent(name.isEmpty ? otherKey : name, () => []).add(d);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) {
        // Keep "Other" at the bottom; everything else alphabetical.
        if (a.key == otherKey) return 1;
        if (b.key == otherKey) return -1;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          for (int i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SkeletonBox(height: 80, radius: 16),
            ),
        ],
      );
    }
    if (diseases.isEmpty) {
      return const _EmptyState(
        icon: Icons.coronavirus_outlined,
        title: 'No diseases found',
        message: 'Try a different search.',
      );
    }

    final children = <Widget>[];
    for (final group in _grouped()) {
      children.add(_DiseaseGroupHeader(
        species: group.key,
        count: group.value.length,
      ));
      for (final d in group.value) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _DiseaseCard(disease: d),
        ));
      }
      children.add(const SizedBox(height: 8));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: children,
    );
  }
}

/// Section header introducing the diseases that affect one plant species.
class _DiseaseGroupHeader extends StatelessWidget {
  final String species;
  final int count;

  const _DiseaseGroupHeader({required this.species, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_florist_rounded,
                color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              species,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiseaseCard extends StatelessWidget {
  final Disease disease;

  const _DiseaseCard({required this.disease});

  @override
  Widget build(BuildContext context) {
    final images = disease.allImages;
    return GestureDetector(
      onTap: () =>
          context.push('/disease/${Uri.encodeComponent(disease.label)}'),
      child: Container(
        padding: const EdgeInsets.all(10),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 60,
                height: 60,
                child: images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: images.first,
                        fit: BoxFit.cover,
                        placeholder: (c, _) =>
                            Container(color: AppColors.surfaceLight),
                        errorWidget: (c, _, _) => const _DiseaseThumbFallback(),
                      )
                    : const _DiseaseThumbFallback(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    disease.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (disease.severity.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SeverityChip.fromSeverity(disease.severity),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DiseaseThumbFallback extends StatelessWidget {
  const _DiseaseThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceLight,
      child: const Icon(Icons.coronavirus_rounded, color: AppColors.textMuted),
    );
  }
}

// ─── Shared bits ──────────────────────────────────────────────────

/// Small pill showing a disease's severity, colour-coded the same way as the
/// disease detail page (high → red, medium → amber, low → green).
class SeverityChip extends StatelessWidget {
  final String label;
  final Color color;

  const SeverityChip({super.key, required this.label, required this.color});

  factory SeverityChip.fromSeverity(String severity) {
    final color = switch (severity) {
      'high' => AppColors.error,
      'medium' => AppColors.amber,
      'low' => AppColors.success,
      _ => AppColors.textSecondary,
    };
    final label = severity.isEmpty
        ? ''
        : '${severity[0].toUpperCase()}${severity.substring(1)} severity';
    return SeverityChip(label: label, color: color);
  }

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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text("Couldn't load the library",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

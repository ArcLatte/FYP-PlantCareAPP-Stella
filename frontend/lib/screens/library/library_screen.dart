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
                          query: _query,
                          allDiseases: _diseases,
                          allSpecies: _species,
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
            // Image area. Uses the self-hosted species photo, falling back to
            // the same soft-mint + leaf placeholder the home grid uses when a
            // photo is missing — keeping the placeholder consistent.
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: SpeciesImage(imageUrl: species.imageUrl),
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

// ─── Diseases tab (species-first) ─────────────────────────────────

/// Species-first browse: a grid of species cards (photo + disease count).
/// Tapping a card opens that species' disease grid. When a search query is
/// active it switches to a flat grid of the matching diseases (skipping the
/// species level), so a direct name search jumps straight to results.
class _DiseasesTab extends StatelessWidget {
  final bool isLoading;
  final String query;
  final List<Disease> allDiseases;
  final List<SpeciesDetail> allSpecies;

  const _DiseasesTab({
    required this.isLoading,
    required this.query,
    required this.allDiseases,
    required this.allSpecies,
  });

  List<Disease> get _matchingDiseases {
    final q = query.trim().toLowerCase();
    return allDiseases
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            (d.speciesName ?? '').toLowerCase().contains(q))
        .toList();
  }

  /// Species with at least one disease, paired with the count and sorted by
  /// name — joins the disease list (by speciesName) to the species list.
  List<({SpeciesDetail species, int count})> _speciesWithDiseases() {
    final counts = <String, int>{};
    for (final d in allDiseases) {
      final key = (d.speciesName ?? '').toLowerCase();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final out = <({SpeciesDetail species, int count})>[];
    for (final s in allSpecies) {
      final c = counts[s.name.toLowerCase()];
      if (c != null && c > 0) out.add((species: s, count: c));
    }
    out.sort((a, b) =>
        a.species.name.toLowerCase().compareTo(b.species.name.toLowerCase()));
    return out;
  }

  static const _grid = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 14,
    crossAxisSpacing: 14,
    childAspectRatio: 0.72,
  );

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

    // Search override: skip the species level and show the matching diseases
    // directly as a flat grid.
    if (query.trim().isNotEmpty) {
      final matches = _matchingDiseases;
      if (matches.isEmpty) {
        return const _EmptyState(
          icon: Icons.coronavirus_outlined,
          title: 'No diseases found',
          message: 'Try a different search.',
        );
      }
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        gridDelegate: _grid,
        itemCount: matches.length,
        itemBuilder: (context, i) => DiseaseGridCard(disease: matches[i]),
      );
    }

    final groups = _speciesWithDiseases();
    if (groups.isEmpty) {
      return const _EmptyState(
        icon: Icons.coronavirus_outlined,
        title: 'No diseases found',
        message: 'Disease references will appear here.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      gridDelegate: _grid,
      itemCount: groups.length,
      itemBuilder: (context, i) => _SpeciesDiseaseCard(
        species: groups[i].species,
        count: groups[i].count,
      ),
    );
  }
}

/// A species card for the Diseases tab: species photo, name, and a chip with
/// the number of diseases catalogued for it. Opens that species' disease grid.
class _SpeciesDiseaseCard extends StatelessWidget {
  final SpeciesDetail species;
  final int count;

  const _SpeciesDiseaseCard({required this.species, required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/library/diseases/${species.id}'),
      child: Container(
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
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: SpeciesImage(imageUrl: species.imageUrl),
              ),
            ),
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
                  const SizedBox(height: 6),
                  _CountChip(count: count),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill showing how many diseases a species has catalogued.
class _CountChip extends StatelessWidget {
  final int count;

  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.coronavirus_rounded,
              size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            '$count ${count == 1 ? 'disease' : 'diseases'}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Species reference photo filling its parent, with the app's soft-mint + leaf
/// placeholder as the fallback (missing URL, load error, or while loading).
class SpeciesImage extends StatelessWidget {
  final String? imageUrl;

  const SpeciesImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: const Icon(Icons.local_florist_rounded,
          color: AppColors.primary, size: 40),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (c, _) => Container(color: AppColors.surfaceLight),
      errorWidget: (c, _, _) => placeholder,
    );
  }
}

/// A disease card for a 2-column grid: reference photo on top, name, and a
/// severity chip. Opens the disease knowledge-base page. Shared by the search
/// override here and by the species disease grid.
class DiseaseGridCard extends StatelessWidget {
  final Disease disease;

  const DiseaseGridCard({super.key, required this.disease});

  @override
  Widget build(BuildContext context) {
    final images = disease.allImages;
    final placeholder = Container(
      color: AppColors.surfaceLight,
      alignment: Alignment.center,
      child: const Icon(Icons.coronavirus_rounded,
          color: AppColors.textMuted, size: 34),
    );
    return GestureDetector(
      onTap: () =>
          context.push('/disease/${Uri.encodeComponent(disease.label)}'),
      child: Container(
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
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: images.first,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (c, _) =>
                            Container(color: AppColors.surfaceLight),
                        errorWidget: (c, _, _) => placeholder,
                      )
                    : placeholder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    disease.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (disease.severity.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SeverityChip.fromSeverity(disease.severity),
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

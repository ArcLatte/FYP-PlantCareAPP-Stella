import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/disease.dart';
import '../../models/species.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton.dart';
import '../tasks/care_activity.dart';
import 'library_screen.dart' show SeverityChip, SpeciesImage;

/// Full reference page for one plant species, opened from the Library
/// (`/library/species/:id`). Lays out what the plant is, its recommended
/// growing conditions, a care schedule, growing tips, and the diseases that
/// commonly affect it (which deep-link to the disease knowledge base).
class SpeciesDetailScreen extends StatefulWidget {
  final int speciesId;

  const SpeciesDetailScreen({super.key, required this.speciesId});

  @override
  State<SpeciesDetailScreen> createState() => _SpeciesDetailScreenState();
}

class _SpeciesDetailScreenState extends State<SpeciesDetailScreen> {
  SpeciesDetail? _species;
  List<Disease> _diseases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getSpeciesDetail(widget.speciesId),
        ApiService.getDiseases(),
      ]);
      if (!mounted) return;
      setState(() {
        _species = results[0] as SpeciesDetail;
        _diseases = results[1] as List<Disease>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Diseases whose species matches this plant — powers the "Common diseases"
  /// section so users can jump straight from a plant to what can ail it.
  List<Disease> get _relatedDiseases {
    final s = _species;
    if (s == null) return const [];
    return _diseases
        .where((d) =>
            (d.speciesName ?? '').toLowerCase() == s.name.toLowerCase())
        .toList();
  }

  List<Widget> _conditionCards(SpeciesDetail s) {
    final cards = <Widget>[];
    if (s.sunlightLabel.isNotEmpty) {
      cards.add(_CareCard(
        icon: Icons.wb_sunny_outlined,
        value: s.sunlightLabel,
        label: 'SUNLIGHT',
        color: AppColors.amber,
      ));
    }
    if (s.locationLabel.isNotEmpty) {
      cards.add(_CareCard(
        icon: Icons.home_outlined,
        value: s.locationLabel,
        label: 'LOCATION',
        color: AppColors.primary,
      ));
    }
    if (s.temperatureRange != null) {
      cards.add(_CareCard(
        icon: Icons.thermostat_outlined,
        value: s.temperatureRange!,
        label: 'TEMP',
        color: AppColors.amber,
      ));
    }
    if (s.daysToHarvest != null) {
      cards.add(_CareCard(
        icon: Icons.eco_outlined,
        value: '~${s.daysToHarvest}d',
        label: 'HARVEST',
        color: AppColors.primary,
      ));
    }
    return cards;
  }

  List<Widget> _scheduleRows(SpeciesDetail s) {
    final rows = <Widget>[];
    void add(CareActivity a, int? days) {
      if (days == null) return;
      rows.add(_ScheduleRow(
        icon: a.icon,
        color: a.color,
        label: a.title,
        value: 'Every $days ${days == 1 ? 'day' : 'days'}',
      ));
    }

    add(CareActivity.water, s.defaultWateringFreqDays);
    add(CareActivity.fertilize, s.defaultFertilizerFreqDays);
    add(CareActivity.mist, s.defaultMistingFreqDays);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final s = _species;
    return Scaffold(
      appBar: AppBar(title: Text(s?.name ?? 'Species')),
      body: _isLoading
          ? const _SpeciesSkeleton()
          : s == null
              ? const Center(
                  child: Text(
                    'Species details not found',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : _buildContent(context, s),
    );
  }

  Widget _buildContent(BuildContext context, SpeciesDetail s) {
    final conditionCards = _conditionCards(s);
    final scheduleRows = _scheduleRows(s);
    final related = _relatedDiseases;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // Header: leaf badge + name + scientific name.
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 52,
                height: 52,
                child: SpeciesImage(imageUrl: s.imageUrl),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: Theme.of(context).textTheme.headlineMedium),
                  if (s.scientificName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      s.scientificName,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // What it is.
        if (s.description.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            s.description,
            style:
                Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
        ],

        // Recommended conditions (sun, location, temp, harvest).
        if (conditionCards.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionLabel('Recommended conditions'),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: conditionCards,
            ),
          ),
        ],

        // Care schedule (watering / fertilizing / misting cadence).
        if (scheduleRows.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Care schedule'),
          const SizedBox(height: 10),
          _InfoCard(
            child: Column(
              children: [
                for (int i = 0; i < scheduleRows.length; i++) ...[
                  if (i > 0) const Divider(height: 18),
                  scheduleRows[i],
                ],
              ],
            ),
          ),
        ],

        // How to plant & care.
        if (s.growingTips.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('How to plant & care'),
          const SizedBox(height: 10),
          _InfoCard(
            child: Text(
              s.growingTips,
              style:
                  Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
          ),
        ],

        // Common diseases → disease knowledge base.
        if (related.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Common diseases'),
          const SizedBox(height: 10),
          for (final d in related)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DiseaseRow(disease: d),
            ),
        ],
      ],
    );
  }
}

// ─── Section helpers ──────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

/// White rounded card used to group a block of reference content.
class _InfoCard extends StatelessWidget {
  final Widget child;

  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
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
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Small square fact card (icon, value, label) — mirrors the species care
/// cards on the plant detail screen.
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

/// One row in the care-schedule card: tinted icon + activity + cadence.
class _ScheduleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _ScheduleRow({
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Compact tappable disease row → opens the disease knowledge base.
class _DiseaseRow extends StatelessWidget {
  final Disease disease;

  const _DiseaseRow({required this.disease});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          context.push('/disease/${Uri.encodeComponent(disease.label)}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              child: Text(
                disease.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (disease.severity.isNotEmpty) ...[
              SeverityChip.fromSeverity(disease.severity),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SpeciesSkeleton extends StatelessWidget {
  const _SpeciesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: const [
            SkeletonBox(width: 52, height: 52, radius: 14),
            SizedBox(width: 14),
            Expanded(child: SkeletonBox(height: 28, radius: 6)),
          ],
        ),
        const SizedBox(height: 20),
        const SkeletonBox(height: 60, radius: 12),
        const SizedBox(height: 24),
        const SkeletonBox(width: 180, height: 18, radius: 6),
        const SizedBox(height: 12),
        const SkeletonBox(height: 96, radius: 16),
        const SizedBox(height: 24),
        const SkeletonBox(width: 140, height: 18, radius: 6),
        const SizedBox(height: 10),
        const SkeletonBox(height: 120, radius: 16),
      ],
    );
  }
}

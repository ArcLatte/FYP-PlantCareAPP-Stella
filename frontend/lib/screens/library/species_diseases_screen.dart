import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/disease.dart';
import '../../models/species.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton.dart';
import 'library_screen.dart' show DiseaseGridCard, SpeciesImage;

/// The diseases catalogued for one plant species, reached from the Library
/// Diseases tab (`/library/diseases/:speciesId`). Shows a species header, then
/// a 2-column grid of disease cards that deep-link into the knowledge base.
class SpeciesDiseasesScreen extends StatefulWidget {
  final int speciesId;

  const SpeciesDiseasesScreen({super.key, required this.speciesId});

  @override
  State<SpeciesDiseasesScreen> createState() => _SpeciesDiseasesScreenState();
}

class _SpeciesDiseasesScreenState extends State<SpeciesDiseasesScreen> {
  SpeciesDetail? _species;
  List<Disease> _diseases = [];
  bool _isLoading = true;
  bool _hasError = false;

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
        ApiService.getSpeciesDetail(widget.speciesId),
        ApiService.getDiseases(),
      ]);
      if (!mounted) return;
      final species = results[0] as SpeciesDetail;
      final all = results[1] as List<Disease>;
      setState(() {
        _species = species;
        _diseases = all
            .where(
              (d) =>
                  (d.speciesName ?? '').toLowerCase() ==
                  species.name.toLowerCase(),
            )
            .toList();
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

  static const _grid = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 14,
    crossAxisSpacing: 14,
    childAspectRatio: 0.72,
  );

  @override
  Widget build(BuildContext context) {
    final s = _species;
    return Scaffold(
      appBar: AppBar(title: Text(s?.name ?? 'Diseases')),
      body: _isLoading
          ? _loading()
          : _hasError || s == null
          ? _error()
          : _content(s),
    );
  }

  Widget _loading() {
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
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

  Widget _error() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            "Couldn't load diseases",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      ),
    );
  }

  Widget _content(SpeciesDetail s) {
    final count = _diseases.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Species header: photo + name + count.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: SpeciesImage(imageUrl: s.imageUrl),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'disease' : 'diseases'} catalogued',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: count == 0
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      'No diseases are catalogued for ${s.name} yet.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  gridDelegate: _grid,
                  itemCount: _diseases.length,
                  itemBuilder: (context, i) =>
                      DiseaseGridCard(disease: _diseases[i]),
                ),
        ),
      ],
    );
  }
}

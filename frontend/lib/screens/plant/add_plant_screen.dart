import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/photo_picker_sheet.dart';
import '../../widgets/skeleton.dart';

const _defaultLocations = <String>[
  'Indoor',
  'Outdoor',
  'Balcony',
  'Office',
  'Garden',
];

/// 4-step add-plant wizard: Species → Location → Care schedule → Photo &
/// review. One decision per screen; species choice drives smart defaults
/// (watering interval, recommended location, which care dates apply).
class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _pageController = PageController();
  int _step = 0;

  // ── Step 1: species ──
  List<Map<String, dynamic>> _species = [];
  bool _isLoadingSpecies = true;
  String _speciesQuery = '';
  Map<String, dynamic>? _selectedSpecies;

  // ── Step 2: location ──
  final List<String> _customLocations = [];
  bool _isLoadingLocations = true;
  String? _selectedLocation;

  // ── Step 3: schedule ──
  final _nameController = TextEditingController();
  final _freqController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _lastWatered;
  DateTime? _lastFertilized;
  DateTime? _lastMisted;

  // ── Step 4: photo + save ──
  File? _photo;
  bool _isSaving = false;
  String? _errorMessage;

  static const _stepTitles = [
    'Pick species',
    'Choose location',
    'Care schedule',
    'Photo & review',
  ];

  @override
  void initState() {
    super.initState();
    _loadSpecies();
    _loadLocations();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _freqController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSpecies() async {
    try {
      final species = await ApiService.getSpecies();
      if (!mounted) return;
      setState(() {
        _species = species;
        _isLoadingSpecies = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingSpecies = false);
    }
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await ApiService.getLocations();
      if (!mounted) return;
      setState(() {
        _customLocations
          ..clear()
          ..addAll(locations
              .map((l) => l['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty));
        _isLoadingLocations = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  // ───────── Derived state ─────────

  List<Map<String, dynamic>> get _filteredSpecies {
    if (_speciesQuery.isEmpty) return _species;
    final q = _speciesQuery.toLowerCase();
    return _species.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final sci = (s['scientific_name'] ?? '').toString().toLowerCase();
      return name.contains(q) || sci.contains(q);
    }).toList();
  }

  List<String> get _allLocations {
    final all = <String>[..._defaultLocations];
    for (final c in _customLocations) {
      if (!all.contains(c)) all.add(c);
    }
    return all;
  }

  int? get _speciesFertilizerFreq =>
      (_selectedSpecies?['default_fertilizer_freq_days'] as num?)?.toInt();
  int? get _speciesMistingFreq =>
      (_selectedSpecies?['default_misting_freq_days'] as num?)?.toInt();

  bool get _anythingTouched =>
      _selectedSpecies != null ||
      _selectedLocation != null ||
      _nameController.text.isNotEmpty ||
      _notesController.text.isNotEmpty ||
      _photo != null;

  bool get _canGoNext {
    switch (_step) {
      case 0:
        return _selectedSpecies != null;
      case 1:
        return true; // location optional — server defaults to ''
      case 2:
        return _effectiveName.isNotEmpty &&
            (int.tryParse(_freqController.text.trim()) ?? 0) > 0;
      case 3:
        return !_isSaving;
      default:
        return false;
    }
  }

  /// Nickname falls back to the species name so users can speed through.
  String get _effectiveName {
    final typed = _nameController.text.trim();
    if (typed.isNotEmpty) return typed;
    return (_selectedSpecies?['name'] ?? '').toString().trim();
  }

  // ───────── Navigation ─────────

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSpeciesPicked(Map<String, dynamic> s) {
    setState(() {
      _selectedSpecies = s;
      // Smart defaults from the species knowledge base.
      _freqController.text =
          ((s['default_watering_freq_days'] as num?)?.toInt() ?? 7).toString();
      final rec = (s['recommended_location'] ?? '').toString();
      _selectedLocation ??= switch (rec) {
        'indoor' => 'Indoor',
        'outdoor' => 'Outdoor',
        _ => null,
      };
      // Care dates that don't apply to the new species are discarded.
      if (_speciesFertilizerFreq == null) _lastFertilized = null;
      if (_speciesMistingFreq == null) _lastMisted = null;
    });
  }

  Future<void> _handleBack() async {
    if (_step > 0) {
      _goToStep(_step - 1);
      return;
    }
    if (!_anythingTouched) {
      context.pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard new plant?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Your selections will be lost.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.pop();
  }

  // ───────── Location helpers ─────────

  Future<void> _promptNewLocation() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add new location',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'e.g. Kitchen window'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child:
                const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    final name = result?.trim();
    if (name == null || name.isEmpty) return;
    try {
      await ApiService.createLocation(name);
      if (!mounted) return;
      setState(() {
        if (!_customLocations.contains(name) &&
            !_defaultLocations.contains(name)) {
          _customLocations.add(name);
        }
        _selectedLocation = name;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  // ───────── Date pickers ─────────

  Future<void> _pickDate(
    DateTime? current,
    ValueChanged<DateTime?> onPicked,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  String _dateLabel(DateTime? d) =>
      d == null ? 'Never / not sure' : '${d.day}/${d.month}/${d.year}';

  // ───────── Photo ─────────

  Future<void> _openPhotoSheet() async {
    final result =
        await showPhotoPickerSheet(context, showClear: _photo != null);
    if (result == null || !mounted) return;
    setState(() {
      if (result.cleared) {
        _photo = null;
      } else if (result.file != null) {
        _photo = result.file;
      }
    });
  }

  // ───────── Save ─────────

  Future<void> _save() async {
    final speciesId = (_selectedSpecies?['id'] as num?)?.toInt();
    if (speciesId == null) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final plant = await ApiService.createPlant(
        _effectiveName,
        speciesId,
        _notesController.text.trim(),
        location: _selectedLocation,
        wateringFreqDays: int.tryParse(_freqController.text.trim()) ?? 7,
        lastWatered: _lastWatered,
        lastFertilized: _lastFertilized,
        lastMisted: _lastMisted,
      );
      // Photo rides a follow-up multipart PUT: the create endpoint is JSON,
      // and updatePlant already speaks multipart — no photo means one call.
      if (_photo != null) {
        await ApiService.updatePlant(plant.id, photo: _photo);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ───────── Build ─────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_stepTitles[_step]),
          leading: IconButton(
            icon: Icon(_step == 0
                ? Icons.close_rounded
                : Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _ProgressPills(current: _step, total: 4),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSpeciesStep(),
                    _buildLocationStep(),
                    _buildScheduleStep(),
                    _buildReviewStep(),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goToStep(_step - 1),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: AppColors.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Back',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _canGoNext
                        ? (_step == 3 ? _save : () => _goToStep(_step + 1))
                        : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_step == 3 ? 'Add to my garden' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────── Step 1: species ─────────

  Widget _buildSpeciesStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What kind of plant is this?',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _speciesQuery = v),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search species…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoadingSpecies
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  itemCount: 6,
                  itemBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: SkeletonBox(height: 72, radius: 14),
                  ),
                )
              : _filteredSpecies.isEmpty
                  ? Center(
                      child: Text(
                        _species.isEmpty
                            ? 'No species available'
                            : "No species match '$_speciesQuery'",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: _filteredSpecies.length,
                      itemBuilder: (context, i) {
                        final s = _filteredSpecies[i];
                        final selected =
                            _selectedSpecies?['id'] == s['id'];
                        return _SpeciesRow(
                          species: s,
                          selected: selected,
                          onTap: () => _onSpeciesPicked(s),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ───────── Step 2: location ─────────

  Widget _buildLocationStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Text('Where will it live?',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Helps you group plants by room or area.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (_isLoadingLocations)
          for (int i = 0; i < 4; i++) ...[
            const SkeletonBox(height: 56, radius: 14),
            const SizedBox(height: 10),
          ]
        else ...[
          for (final name in _allLocations) ...[
            _SelectableRow(
              icon: Icons.place_outlined,
              label: name,
              selected: _selectedLocation == name,
              onTap: () => setState(() {
                // Tap again to deselect — location is optional.
                _selectedLocation =
                    _selectedLocation == name ? null : name;
              }),
            ),
            const SizedBox(height: 10),
          ],
          _SelectableRow(
            icon: Icons.add_rounded,
            label: 'Add new location…',
            selected: false,
            accent: true,
            onTap: _promptNewLocation,
          ),
        ],
      ],
    );
  }

  // ───────── Step 3: schedule ─────────

  Widget _buildScheduleStep() {
    final speciesName = (_selectedSpecies?['name'] ?? '').toString();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Text('Nickname & care schedule',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text('Plant nickname', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: speciesName.isEmpty ? 'e.g. My Tomato' : speciesName,
            prefixIcon: const Icon(Icons.local_florist_outlined),
          ),
        ),
        const SizedBox(height: 24),
        Text('Watering interval (days)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _freqController,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: '7',
            prefixIcon: Icon(Icons.water_drop_outlined),
          ),
        ),
        const SizedBox(height: 24),
        _DateRow(
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF4F9FD9),
          label: 'Last watered',
          value: _dateLabel(_lastWatered),
          onTap: () => _pickDate(
              _lastWatered, (d) => setState(() => _lastWatered = d)),
          onClear: _lastWatered == null
              ? null
              : () => setState(() => _lastWatered = null),
        ),
        if (_speciesFertilizerFreq != null) ...[
          const SizedBox(height: 12),
          _DateRow(
            icon: Icons.compost_rounded,
            color: AppColors.amber,
            label: 'Last fertilized',
            hint: 'Recommended every ${_speciesFertilizerFreq}d',
            value: _dateLabel(_lastFertilized),
            onTap: () => _pickDate(
                _lastFertilized, (d) => setState(() => _lastFertilized = d)),
            onClear: _lastFertilized == null
                ? null
                : () => setState(() => _lastFertilized = null),
          ),
        ],
        if (_speciesMistingFreq != null) ...[
          const SizedBox(height: 12),
          _DateRow(
            icon: Icons.cloud_rounded,
            color: const Color(0xFF26A69A),
            label: 'Last misted',
            hint: 'Recommended every ${_speciesMistingFreq}d',
            value: _dateLabel(_lastMisted),
            onTap: () => _pickDate(
                _lastMisted, (d) => setState(() => _lastMisted = d)),
            onClear: _lastMisted == null
                ? null
                : () => setState(() => _lastMisted = null),
          ),
        ],
        const SizedBox(height: 24),
        Text('Notes (optional)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          style: const TextStyle(color: AppColors.textPrimary),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Any notes about this plant...',
            prefixIcon: Icon(Icons.notes_rounded),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  // ───────── Step 4: photo + review ─────────

  Widget _buildReviewStep() {
    final speciesName = (_selectedSpecies?['name'] ?? '').toString();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Text('Add a photo of your plant',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text("Optional, but it makes your garden feel alive.",
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: _openPhotoSheet,
            child: _photo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      _photo!,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 1.4,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded,
                            color: AppColors.primary, size: 44),
                        SizedBox(height: 10),
                        Text(
                          'Tap to add photo',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (_photo != null)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _photo = null),
              child: const Text('Remove photo',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          ),
        const SizedBox(height: 16),
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Review summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'Name', value: _effectiveName),
              _SummaryRow(label: 'Species', value: speciesName),
              _SummaryRow(
                  label: 'Location', value: _selectedLocation ?? '—'),
              _SummaryRow(
                label: 'Watering',
                value: 'Every ${_freqController.text.trim()} days',
              ),
              if (_lastWatered != null)
                _SummaryRow(
                    label: 'Last watered', value: _dateLabel(_lastWatered)),
              if (_lastFertilized != null)
                _SummaryRow(
                    label: 'Last fertilized',
                    value: _dateLabel(_lastFertilized)),
              if (_lastMisted != null)
                _SummaryRow(
                    label: 'Last misted', value: _dateLabel(_lastMisted)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────

/// 4-segment progress strip under the AppBar.
class _ProgressPills extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressPills({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          for (int i = 0; i < total; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                decoration: BoxDecoration(
                  color: i < current
                      ? AppColors.primary
                      : i == current
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (i < total - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// One species result row: leaf tile, name, scientific name + care hints.
class _SpeciesRow extends StatelessWidget {
  final Map<String, dynamic> species;
  final bool selected;
  final VoidCallback onTap;
  const _SpeciesRow({
    required this.species,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (species['name'] ?? '').toString();
    final sci = (species['scientific_name'] ?? '').toString();
    final waterDays =
        (species['default_watering_freq_days'] as num?)?.toInt();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.eco_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (sci.isNotEmpty || waterDays != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (sci.isNotEmpty) sci,
                        if (waterDays != null) 'Water every ${waterDays}d',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable card row used for the location list.
class _SelectableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;
  const _SelectableRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? AppColors.primary
        : selected
            ? AppColors.primary
            : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:
                      accent ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Tappable date row with colored icon tile, used for last-care dates.
class _DateRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? hint;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 18),
                onPressed: onClear,
              )
            else
              const Icon(Icons.event_rounded,
                  color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

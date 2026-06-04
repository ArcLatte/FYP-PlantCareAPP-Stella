import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton.dart';

const _kAddNewSentinel = '__add_new_location__';
const _defaultLocations = <String>[
  'Indoor',
  'Outdoor',
  'Balcony',
  'Office',
  'Garden',
];

class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _freqController = TextEditingController(text: '7');

  List<Map<String, dynamic>> _species = [];
  int? _selectedSpeciesId;
  bool _isLoading = false;
  bool _isLoadingSpecies = true;
  String? _errorMessage;

  // Locations
  final List<String> _customLocations = [];
  String? _selectedLocation;
  bool _isLoadingLocations = true;

  @override
  void initState() {
    super.initState();
    _loadSpecies();
    _loadLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _freqController.dispose();
    super.dispose();
  }

  Future<void> _loadSpecies() async {
    try {
      final species = await ApiService.getSpecies();
      setState(() {
        _species = species;
        _isLoadingSpecies = false;
      });
    } catch (e) {
      setState(() => _isLoadingSpecies = false);
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

  List<String> get _allLocations {
    final all = <String>[];
    all.addAll(_defaultLocations);
    for (final c in _customLocations) {
      if (!all.contains(c)) all.add(c);
    }
    return all;
  }

  Future<void> _promptNewLocation() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Add new location',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'e.g. Kitchen window',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text(
              'Save',
              style: TextStyle(color: AppColors.primary),
            ),
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
        setState(() => _errorMessage =
            e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _addPlant() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpeciesId == null) {
      setState(() => _errorMessage = 'Please select a species');
      return;
    }
    final freq = int.tryParse(_freqController.text.trim()) ?? 7;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ApiService.createPlant(
        _nameController.text.trim(),
        _selectedSpeciesId!,
        _notesController.text.trim(),
        location: _selectedLocation,
        wateringFreqDays: freq,
      );
      if (mounted) context.pop();
    } catch (e) {
      setState(() =>
          _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Plant'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plant icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: AppColors.primary,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

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
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Plant name
                Text('Plant Name',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. My Tomato Plant',
                    prefixIcon: Icon(Icons.local_florist_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter a plant name' : null,
                ),
                const SizedBox(height: 24),

                // Species dropdown
                Text('Species',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _isLoadingSpecies
                    ? const SkeletonBox(height: 56, radius: 12)
                    : DropdownButtonFormField<int>(
                        initialValue: _selectedSpeciesId,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Select species',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: _species
                            .map((s) => DropdownMenuItem<int>(
                                  value: s['id'] as int,
                                  child: Text(s['name'] as String),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedSpeciesId = val),
                      ),
                const SizedBox(height: 24),

                // Location dropdown
                Text('Location',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _isLoadingLocations
                    ? const SkeletonBox(height: 56, radius: 12)
                    : DropdownButtonFormField<String>(
                        initialValue: _selectedLocation,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Select location',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                        items: [
                          ..._allLocations.map(
                            (name) => DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            ),
                          ),
                          const DropdownMenuItem<String>(
                            value: _kAddNewSentinel,
                            child: Row(
                              children: [
                                Icon(Icons.add_rounded,
                                    color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Add new location…',
                                  style:
                                      TextStyle(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == _kAddNewSentinel) {
                            _promptNewLocation();
                          } else {
                            setState(() => _selectedLocation = val);
                          }
                        },
                      ),
                const SizedBox(height: 24),

                // Watering frequency
                Text('Watering interval (days)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _freqController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: '7',
                    prefixIcon: Icon(Icons.water_drop_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Enter a positive number';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Notes
                Text('Notes (optional)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Any notes about this plant...',
                    prefixIcon: Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _isLoading ? null : _addPlant,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add Plant'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

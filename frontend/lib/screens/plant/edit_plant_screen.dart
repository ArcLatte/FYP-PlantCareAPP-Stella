import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';

const _kAddNewSentinel = '__add_new_location__';
const _defaultLocations = <String>[
  'Indoor',
  'Outdoor',
  'Balcony',
  'Office',
  'Garden',
];

/// Edit an existing plant. Mirrors AddPlantScreen layout but pre-fills
/// every field from the loaded [Plant] and supports replacing the hero
/// photo (the new image rides along with the JSON fields in a single
/// multipart PUT on save).
class EditPlantScreen extends StatefulWidget {
  final int plantId;
  const EditPlantScreen({super.key, required this.plantId});

  @override
  State<EditPlantScreen> createState() => _EditPlantScreenState();
}

class _EditPlantScreenState extends State<EditPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _freqController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Plant? _plant;
  List<Map<String, dynamic>> _species = [];
  final List<String> _customLocations = [];

  int? _selectedSpeciesId;
  String? _selectedLocation;
  File? _newPhoto;

  bool _isLoadingPlant = true;
  bool _isLoadingSpecies = true;
  bool _isLoadingLocations = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _freqController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPlant(), _loadSpecies(), _loadLocations()]);
  }

  Future<void> _loadPlant() async {
    try {
      final plant = await ApiService.getPlant(widget.plantId);
      if (!mounted) return;
      setState(() {
        _plant = plant;
        _nameController.text = plant.name;
        _notesController.text = plant.notes ?? '';
        _freqController.text = plant.wateringFreqDays.toString();
        _selectedSpeciesId = plant.speciesId;
        _selectedLocation = plant.location.isEmpty ? null : plant.location;
        _isLoadingPlant = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlant = false;
          _errorMessage = 'Failed to load plant: $e';
        });
      }
    }
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

  List<String> get _allLocations {
    final all = <String>[..._defaultLocations];
    for (final c in _customLocations) {
      if (!all.contains(c)) all.add(c);
    }
    // Preserve the plant's existing location even if it's not in the lists.
    final current = _selectedLocation;
    if (current != null && current.isNotEmpty && !all.contains(current)) {
      all.add(current);
    }
    return all;
  }

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
            child: const Text('Save',
                style: TextStyle(color: AppColors.primary)),
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

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _newPhoto = File(picked.path));
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Could not pick image: $e');
    }
  }

  Future<void> _showPhotoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.primary),
                title: const Text('Take photo',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: const Text('Choose from gallery',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (_newPhoto != null || _plant?.photoUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error),
                  title: const Text('Remove selected photo',
                      style: TextStyle(color: AppColors.error)),
                  subtitle: const Text(
                    'Cancels your pending change; the saved photo is kept until save.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() => _newPhoto = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpeciesId == null) {
      setState(() => _errorMessage = 'Please select a species');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ApiService.updatePlant(
        widget.plantId,
        name: _nameController.text.trim(),
        notes: _notesController.text.trim(),
        location: _selectedLocation ?? '',
        wateringFreqDays:
            int.tryParse(_freqController.text.trim()) ?? 7,
        speciesId: _selectedSpeciesId,
        photo: _newPhoto,
      );
      if (!mounted) return;
      AppSnackBar.success(context, 'Plant updated');
      context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Plant'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoadingPlant
          ? const Center(child: CircularProgressIndicator())
          : _plant == null
              ? const Center(
                  child: Text('Plant not found',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo picker
                          Center(child: _PhotoPicker(
                            existingUrl: _plant!.photoUrl,
                            newPhoto: _newPhoto,
                            onTap: _showPhotoSheet,
                          )),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: _showPhotoSheet,
                              icon: const Icon(Icons.camera_alt_rounded,
                                  size: 18, color: AppColors.primary),
                              label: Text(
                                _newPhoto != null
                                    ? 'Change selected photo'
                                    : (_plant!.photoUrl != null
                                        ? 'Change photo'
                                        : 'Add a photo'),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
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
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

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
                            validator: (v) => v == null || v.isEmpty
                                ? 'Enter a plant name'
                                : null,
                          ),
                          const SizedBox(height: 24),

                          Text('Species',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _isLoadingSpecies
                              ? const SkeletonBox(height: 56, radius: 12)
                              : DropdownButtonFormField<int>(
                                  initialValue: _selectedSpeciesId,
                                  dropdownColor: AppColors.surface,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary),
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

                          Text('Location',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _isLoadingLocations
                              ? const SkeletonBox(height: 56, radius: 12)
                              : DropdownButtonFormField<String>(
                                  initialValue: _selectedLocation,
                                  dropdownColor: AppColors.surface,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary),
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
                                              color: AppColors.primary,
                                              size: 18),
                                          SizedBox(width: 8),
                                          Text('Add new location…',
                                              style: TextStyle(
                                                  color: AppColors.primary)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val == _kAddNewSentinel) {
                                      _promptNewLocation();
                                    } else {
                                      setState(
                                          () => _selectedLocation = val);
                                    }
                                  },
                                ),
                          const SizedBox(height: 24),

                          Text('Watering interval (days)',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _freqController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style:
                                const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              hintText: '7',
                              prefixIcon: Icon(Icons.water_drop_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final n = int.tryParse(v);
                              if (n == null || n <= 0) {
                                return 'Enter a positive number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          Text('Notes (optional)',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesController,
                            style:
                                const TextStyle(color: AppColors.textPrimary),
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Any notes about this plant...',
                              prefixIcon: Icon(Icons.notes_rounded),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 40),

                          ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save Changes'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}

/// Square hero photo with overlayed camera badge. Prefers the freshly picked
/// local file; falls back to the saved remote URL; finally a leaf placeholder.
class _PhotoPicker extends StatelessWidget {
  final String? existingUrl;
  final File? newPhoto;
  final VoidCallback onTap;

  const _PhotoPicker({
    required this.existingUrl,
    required this.newPhoto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 140,
              height: 140,
              child: newPhoto != null
                  ? Image.file(newPhoto!, fit: BoxFit.cover)
                  : (existingUrl != null
                      ? CachedNetworkImage(
                          imageUrl: existingUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              const SkeletonBox(radius: 0),
                          errorWidget: (_, _, _) => const _PhotoFallback(),
                        )
                      : const _PhotoFallback()),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

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
        child: Icon(Icons.eco_rounded, color: AppColors.primary, size: 48),
      ),
    );
  }
}

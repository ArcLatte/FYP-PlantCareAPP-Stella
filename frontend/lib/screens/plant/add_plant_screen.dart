import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../services/api_service.dart';

class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _species = [];
  int? _selectedSpeciesId;
  bool _isLoading = false;
  bool _isLoadingSpecies = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSpecies();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
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

  Future<void> _addPlant() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSpeciesId == null) {
      setState(() => _errorMessage = 'Please select a species');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ApiService.createPlant(
        _nameController.text.trim(),
        _selectedSpeciesId!,
        _notesController.text.trim(),
      );
      if (mounted) context.pop();
    } catch (e) {
      setState(() =>
          _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
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

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.error.withOpacity(0.3)),
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
                Text(
                  'Plant Name',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                Text(
                  'Species',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _isLoadingSpecies
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : DropdownButtonFormField<int>(
                        value: _selectedSpeciesId,
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

                // Notes
                Text(
                  'Notes (optional)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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

                // Submit button
                ElevatedButton(
                  onPressed: _isLoading ? null : _addPlant,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
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
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/photo_picker_sheet.dart';

/// Compose a new post: text and/or a photo, with an optional tracked plant
/// attached. Pops `true` on success so the feed knows to refresh.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _bodyController = TextEditingController();
  File? _image;
  Plant? _plant;
  bool _submitting = false;

  bool get _canPost =>
      !_submitting &&
      (_bodyController.text.trim().isNotEmpty || _image != null);

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result =
        await showPhotoPickerSheet(context, showClear: _image != null);
    if (result == null) return;
    setState(() => _image = result.cleared ? null : result.file);
  }

  Future<void> _pickPlant() async {
    final selected = await showModalBottomSheet<Plant>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _PlantPickerSheet(),
    );
    if (selected != null) setState(() => _plant = selected);
  }

  Future<void> _submit() async {
    if (!_canPost) return;
    setState(() => _submitting = true);
    try {
      await ApiService.createPost(
        body: _bodyController.text.trim(),
        image: _image,
        plantId: _plant?.id,
      );
      if (!mounted) return;
      AppSnackBar.success(context, 'Posted!');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackBar.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _canPost ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : Text(
                      'Post',
                      style: TextStyle(
                        color:
                            _canPost ? AppColors.primary : AppColors.textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TextField(
            controller: _bodyController,
            autofocus: true,
            maxLines: null,
            minLines: 4,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: "What's growing on?",
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              counterText: '',
            ),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
          if (_image != null) ...[
            const SizedBox(height: 8),
            _ImagePreview(image: _image!, onRemove: () => setState(() => _image = null)),
          ],
          if (_plant != null) ...[
            const SizedBox(height: 12),
            _AttachedPlant(plant: _plant!, onRemove: () => setState(() => _plant = null)),
          ],
          const SizedBox(height: 16),
          const Divider(),
          _ComposeAction(
            icon: Icons.image_outlined,
            label: _image == null ? 'Add photo' : 'Change photo',
            onTap: _pickPhoto,
          ),
          _ComposeAction(
            icon: Icons.eco_outlined,
            label: _plant == null ? 'Attach a plant' : 'Change plant',
            onTap: _pickPlant,
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final File image;
  final VoidCallback onRemove;
  const _ImagePreview({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: Image.file(image, width: double.infinity, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachedPlant extends StatelessWidget {
  final Plant plant;
  final VoidCallback onRemove;
  const _AttachedPlant({required this.plant, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${plant.name} · ${plant.species}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ComposeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ComposeAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing the user's tracked plants to attach to a post.
class _PlantPickerSheet extends StatefulWidget {
  const _PlantPickerSheet();

  @override
  State<_PlantPickerSheet> createState() => _PlantPickerSheetState();
}

class _PlantPickerSheetState extends State<_PlantPickerSheet> {
  List<Plant>? _plants;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plants = await ApiService.getPlants();
      if (mounted) setState(() => _plants = plants);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Attach a plant',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Flexible(child: _buildList()),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!,
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }
    if (_plants == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_plants!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          "You don't have any plants to attach yet.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _plants!.length,
      itemBuilder: (context, index) {
        final plant = _plants![index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: plant.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: plant.photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const _PlantIcon(),
                    )
                  : const _PlantIcon(),
            ),
          ),
          title: Text(plant.name,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Text(plant.species,
              style: const TextStyle(color: AppColors.textMuted)),
          onTap: () => Navigator.pop(context, plant),
        );
      },
    );
  }
}

class _PlantIcon extends StatelessWidget {
  const _PlantIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceLight,
      alignment: Alignment.center,
      child: const Icon(Icons.eco_outlined, color: AppColors.textMuted, size: 20),
    );
  }
}

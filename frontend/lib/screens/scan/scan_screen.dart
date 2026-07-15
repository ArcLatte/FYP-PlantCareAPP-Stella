import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_error.dart';
import '../../core/theme.dart';
import '../../models/plant.dart';
import '../../services/api_service.dart';

class ScanScreen extends StatefulWidget {
  final int? plantId;

  const ScanScreen({super.key, this.plantId});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  Future<void>? _cameraReady;
  String? _cameraError;

  List<Plant> _plants = [];
  int? _selectedPlantId;
  bool _isLoadingPlants = true;

  bool _isSubmitting = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedPlantId = widget.plantId;
    _loadPlants();
    _cameraReady = _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _camera;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _cameraReady = _initCamera());
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _cameraError = 'No cameras available on this device';
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _cameraError = AppErrorMessages.message(
            e,
            fallback:
                'Camera unavailable. Check camera permission and try again.',
          ),
        );
      }
    }
  }

  Future<void> _loadPlants() async {
    try {
      final plants = await ApiService.getPlants();
      if (!mounted) return;
      setState(() {
        _plants = plants;
        _isLoadingPlants = false;
        if (_selectedPlantId == null && plants.isNotEmpty) {
          _selectedPlantId = plants.first.id;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingPlants = false);
    }
  }

  Future<void> _capture() async {
    if (_selectedPlantId == null) {
      setState(() => _errorMessage = 'Select a plant first');
      return;
    }
    final controller = _camera;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final xfile = await controller.takePicture();
      await _submit(File(xfile.path));
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppErrorMessages.message(
            e,
            fallback: 'Could not take the picture. Please try again.',
          );
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_selectedPlantId == null) {
      setState(() => _errorMessage = 'Select a plant first');
      return;
    }
    if (_isSubmitting) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });
      await _submit(File(picked.path));
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppErrorMessages.message(
            e,
            fallback: 'Could not open that image. Please choose another one.',
          );
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submit(File file) async {
    try {
      final result = await ApiService.scanPlant(_selectedPlantId!, file);
      if (mounted) context.pushReplacement('/result/${result.id}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppErrorMessages.message(
            e,
            fallback: 'Could not scan this image. Please try again.',
          );
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview fills the screen
            Positioned.fill(child: _buildPreview()),

            // Top: back button + plant selector
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),

            // Bottom: gallery + capture + spacer
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),

            // Error banner
            if (_errorMessage != null)
              Positioned(
                top: 90,
                left: 16,
                right: 16,
                child: _buildErrorBanner(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Pick from gallery instead'),
              ),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<void>(
      future: _cameraReady,
      builder: (context, snapshot) {
        final controller = _camera;
        if (snapshot.connectionState != ConnectionState.done ||
            controller == null ||
            !controller.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildPlantSelector()),
        ],
      ),
    );
  }

  Widget _buildPlantSelector() {
    if (_isLoadingPlants) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    if (_plants.isEmpty) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Add a plant first',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    return GestureDetector(
      onTap: _showPlantPickerSheet,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.eco_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedPlant?.name ?? 'Select plant',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Plant? get _selectedPlant {
    if (_selectedPlantId == null) return null;
    for (final p in _plants) {
      if (p.id == _selectedPlantId) return p;
    }
    return null;
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // Gallery (bottom-left)
          _CircleButton(
            icon: Icons.photo_library_outlined,
            onTap: _isSubmitting ? null : _pickFromGallery,
          ),
          const Spacer(),
          // Capture (center)
          GestureDetector(
            onTap: _isSubmitting ? null : _capture,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                color: Colors.white24,
              ),
              child: _isSubmitting
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const Spacer(),
          // Balancer (invisible) so capture stays centered
          const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  void _showPlantPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select plant',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._plants.map((p) {
                final selected = p.id == _selectedPlantId;
                return ListTile(
                  leading: Icon(
                    Icons.eco_rounded,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    p.species,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedPlantId = p.id);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.4),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

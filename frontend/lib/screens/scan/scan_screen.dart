import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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
  bool _hasPromptedForPlant = false;

  bool _isSubmitting = false;
  File? _capturedImage;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        // Both classifiers consume 224x224 tensors. Medium keeps ample detail
        // while making capture and mobile upload noticeably faster.
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
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
      });
      // A scan must be deliberately tied to a profile. Prompt once after the
      // garden loads instead of silently choosing the first plant.
      if (_selectedPlantId == null &&
          plants.isNotEmpty &&
          !_hasPromptedForPlant) {
        _hasPromptedForPlant = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedPlantId == null) _openPlantPicker();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPlants = false);
    }
  }

  Future<void> _openAddPlant() async {
    final created = await context.push<bool>('/plants/add');
    if (!mounted || created != true) return;
    await _loadPlants();
  }

  Future<void> _openPlantPicker() async {
    final selected = await context.push<int>(
      '/scan/select-plant?selected=${_selectedPlantId ?? ''}',
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedPlantId = selected;
      _errorMessage = null;
    });
    // The chooser can also create a plant. Refresh so its name/photo are
    // immediately available in the camera selector when it returns.
    await _loadPlants();
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
      final file = await _compressScanPhoto(File(xfile.path));
      if (!mounted) return;
      setState(() => _capturedImage = file);
      await _submit(file);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppErrorMessages.message(
            e,
            fallback: 'Could not take the picture. Please try again.',
          );
          _isSubmitting = false;
          _capturedImage = null;
        });
      }
    }
  }

  /// Keeps camera uploads small before sending them to the scan API. The
  /// classifier resizes every image to 224px, so 1280px JPEG preserves more
  /// than enough leaf detail while avoiding full-resolution camera uploads.
  Future<File> _compressScanPhoto(File original) async {
    final targetPath =
        '${original.parent.path}/'
        'scan_${DateTime.now().microsecondsSinceEpoch}.jpg';
    try {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        original.absolute.path,
        targetPath,
        minWidth: 1280,
        minHeight: 1280,
        quality: 85,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      return compressed == null ? original : File(compressed.path);
    } catch (_) {
      // A scan should still be possible if a device cannot compress its image.
      return original;
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
        _capturedImage = File(picked.path);
        _errorMessage = null;
      });
      await _submit(_capturedImage!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppErrorMessages.message(
            e,
            fallback: 'Could not open that image. Please choose another one.',
          );
          _isSubmitting = false;
          _capturedImage = null;
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
          _capturedImage = null;
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

            // Framing guide is UI-only; it is not part of the saved photo.
            // Stays up while analyzing so the sweep animation plays over the
            // frozen capture (the modal overlay dims everything above it).
            if (_cameraError == null &&
                (_camera?.value.isInitialized == true ||
                    _capturedImage != null))
              Positioned.fill(child: _ScanGuide(scanning: _isSubmitting)),

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

            // A modal analysis state also blocks every camera control. The
            // captured frame remains visible and motionless underneath it.
            if (_isSubmitting) Positioned.fill(child: _buildAnalysisOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final capturedImage = _capturedImage;
    if (capturedImage != null) {
      return Image.file(
        capturedImage,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
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
      return GestureDetector(
        onTap: _openAddPlant,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Add a plant first',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _openPlantPicker,
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

  Widget _buildAnalysisOverlay() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.38),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Analyzing your photo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Checking image quality and plant health. This may take a few seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
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

/// Framing guide overlay: hint pill + animated frame. Idle, the corner
/// brackets breathe gently; while [scanning] a scan line sweeps the frame.
class _ScanGuide extends StatefulWidget {
  final bool scanning;

  const _ScanGuide({required this.scanning});

  @override
  State<_ScanGuide> createState() => _ScanGuideState();
}

class _ScanGuideState extends State<_ScanGuide>
    with SingleTickerProviderStateMixin {
  static const _idleCycle = Duration(milliseconds: 2600);
  static const _sweepCycle = Duration(milliseconds: 1700);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.scanning ? _sweepCycle : _idleCycle,
  )..repeat();

  @override
  void didUpdateWidget(covariant _ScanGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanning != widget.scanning) {
      _controller.duration = widget.scanning ? _sweepCycle : _idleCycle;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 112, 28, 142),
        child: Column(
          children: [
            // Hint pill fades out while analyzing — the modal overlay carries
            // the messaging then.
            AnimatedOpacity(
              opacity: widget.scanning ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.center_focus_strong_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Place one leaf inside the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 0.86,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      // 0 → 1 → 0 over one loop, eased at both ends.
                      final pulse = 0.5 - 0.5 * math.cos(2 * math.pi * t);
                      return Transform.scale(
                        scale: widget.scanning ? 1.0 : 1.0 + 0.012 * pulse,
                        child: CustomPaint(
                          painter: _ScanFramePainter(
                            t: t,
                            pulse: pulse,
                            scanning: widget.scanning,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  /// Loop position, 0..1. Drives the scan-line sweep while scanning.
  final double t;

  /// Eased 0 → 1 → 0 over one loop. Drives the idle breathing.
  final double pulse;
  final bool scanning;

  _ScanFramePainter({
    required this.t,
    required this.pulse,
    required this.scanning,
  });

  static const _radius = 28.0;
  // Straight arm length of each corner bracket, past the rounded corner.
  static const _arm = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final rrect = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(_radius),
    );

    final outlinePaint = Paint()
      ..color = Colors.white.withValues(
        alpha: scanning ? 0.22 : 0.22 + 0.12 * pulse,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(rrect, outlinePaint);

    // Corner brackets that follow the rounded corners, with a soft glow
    // underneath so they read against both bright and dark foliage.
    final brackets = _cornerBrackets(bounds);
    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(
        alpha: scanning ? 0.5 : 0.2 + 0.3 * pulse,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(brackets, glowPaint);
    final bracketPaint = Paint()
      ..color = scanning
          ? AppColors.primary
          : AppColors.primary.withValues(alpha: 0.75 + 0.25 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(brackets, bracketPaint);

    if (scanning) {
      // Scan line sweeping top → bottom with a fading trail, clipped to the
      // frame so nothing spills past the rounded corners.
      canvas.save();
      canvas.clipRRect(rrect);
      final lineY = bounds.top + bounds.height * t;
      final trailTop = math.max(bounds.top, lineY - bounds.height * 0.26);
      if (lineY - trailTop > 1) {
        final trailRect = Rect.fromLTRB(
          bounds.left,
          trailTop,
          bounds.right,
          lineY,
        );
        final trailPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0),
              AppColors.primary.withValues(alpha: 0.3),
            ],
          ).createShader(trailRect);
        canvas.drawRect(trailRect, trailPaint);
      }
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawLine(
        Offset(bounds.left + 12, lineY),
        Offset(bounds.right - 12, lineY),
        linePaint,
      );
      canvas.restore();
    }
  }

  /// One path holding all four corner brackets: straight arm, rounded arc
  /// matching the outline's corner radius, straight arm.
  Path _cornerBrackets(Rect b) {
    const r = _radius;
    const rad = Radius.circular(r);
    return Path()
      // Top-left
      ..moveTo(b.left, b.top + r + _arm)
      ..lineTo(b.left, b.top + r)
      ..arcToPoint(Offset(b.left + r, b.top), radius: rad)
      ..lineTo(b.left + r + _arm, b.top)
      // Top-right
      ..moveTo(b.right - r - _arm, b.top)
      ..lineTo(b.right - r, b.top)
      ..arcToPoint(Offset(b.right, b.top + r), radius: rad)
      ..lineTo(b.right, b.top + r + _arm)
      // Bottom-right
      ..moveTo(b.right, b.bottom - r - _arm)
      ..lineTo(b.right, b.bottom - r)
      ..arcToPoint(Offset(b.right - r, b.bottom), radius: rad)
      ..lineTo(b.right - r - _arm, b.bottom)
      // Bottom-left
      ..moveTo(b.left + r + _arm, b.bottom)
      ..lineTo(b.left + r, b.bottom)
      ..arcToPoint(Offset(b.left, b.bottom - r), radius: rad)
      ..lineTo(b.left, b.bottom - r - _arm);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.pulse != pulse ||
      oldDelegate.scanning != scanning;
}

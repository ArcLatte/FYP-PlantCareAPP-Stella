import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a plant stage image, preferring a user-supplied `<image>.png` in
/// `assets/plant_stages/` if present, otherwise the bundled `<image>.svg`. This
/// is what makes AI-generated art drop-in: add `seedling.png` and it's used
/// automatically (the folder is already declared in pubspec).
///
/// Shared by the Tasks streak plant and the per-plant Growth card on the
/// profile, so the growth illustration reads the same wherever it appears.
class StageImage extends StatelessWidget {
  final String image;
  final double size;
  const StageImage({super.key, required this.image, required this.size});

  static Future<Set<String>>? _pngFuture;
  static Future<Set<String>> _pngStages() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest
          .listAssets()
          .where((a) =>
              a.startsWith('assets/plant_stages/') && a.endsWith('.png'))
          .map((a) => a.split('/').last.replaceAll('.png', ''))
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    _pngFuture ??= _pngStages();
    return FutureBuilder<Set<String>>(
      future: _pngFuture,
      builder: (context, snap) {
        final hasPng = snap.data?.contains(image) ?? false;
        if (hasPng) {
          return Image.asset(
            'assets/plant_stages/$image.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        }
        return SvgPicture.asset(
          'assets/plant_stages/$image.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      },
    );
  }
}

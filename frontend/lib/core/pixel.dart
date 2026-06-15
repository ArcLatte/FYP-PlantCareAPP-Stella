import 'package:flutter/material.dart';
import 'theme.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Pixel / 8-bit design kit.
///
/// A retro-game look layered on top of the existing [AppColors] palette:
/// chunky dark borders, hard (zero-blur) drop shadows, chamfered "pixel
/// window" corners, and the Silkscreen / Press Start 2P bitmap fonts.
///
/// Use [PixelBox] for any framed surface and [Pixel.text] / [Pixel.display]
/// for type. Keeping it in one file means the rest of the app can opt into
/// the aesthetic screen-by-screen without a global theme rewrite.
/// ─────────────────────────────────────────────────────────────────────────
class Pixel {
  Pixel._();

  /// Bitmap UI font — legible at small sizes. Default for labels/body.
  static const String fontBody = 'Silkscreen';

  /// Chunky arcade font — for hero numbers and short titles only.
  static const String fontDisplay = 'PressStart2P';

  /// The single dark "ink" used for every border and hard shadow, so the
  /// whole UI reads like it was drawn with one black marker.
  static const Color ink = Color(0xFF233028);

  /// Soft cream page background — warmer than clinical white, very SNES.
  static const Color paper = Color(0xFFEFE9DA);
  static const Color panel = Color(0xFFFBF7EC);

  /// One "pixel" unit. Corners are chamfered by this much and the grid in
  /// the weather scene snaps to it.
  static const double unit = 4;

  // ── Type ────────────────────────────────────────────────────────────────

  static TextStyle text(
    double size, {
    Color color = ink,
    bool bold = false,
    double? height,
    double letterSpacing = 0.5,
  }) => TextStyle(
    fontFamily: fontBody,
    fontSize: size,
    color: color,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle display(
    double size, {
    Color color = ink,
    double? height,
  }) => TextStyle(
    fontFamily: fontDisplay,
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: 0,
  );
}

/// A chamfered "8-bit window" container: solid fill, thick dark border, and a
/// hard offset shadow (no blur). The corners are notched by one pixel unit so
/// the box reads as an octagon — the classic retro dialog-box silhouette.
class PixelBox extends StatelessWidget {
  final Widget? child;
  final Color color;
  final Color border;
  final Color? shadow;
  final double borderWidth;
  final double notch;
  final Offset shadowOffset;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const PixelBox({
    super.key,
    this.child,
    this.color = Pixel.panel,
    this.border = Pixel.ink,
    this.shadow = Pixel.ink,
    this.borderWidth = 3,
    this.notch = Pixel.unit,
    this.shadowOffset = const Offset(4, 4),
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = CustomPaint(
      painter: _PixelBoxPainter(
        color: color,
        border: border,
        shadow: shadow,
        borderWidth: borderWidth,
        notch: notch,
        shadowOffset: shadowOffset,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

class _PixelBoxPainter extends CustomPainter {
  final Color color;
  final Color border;
  final Color? shadow;
  final double borderWidth;
  final double notch;
  final Offset shadowOffset;

  _PixelBoxPainter({
    required this.color,
    required this.border,
    required this.shadow,
    required this.borderWidth,
    required this.notch,
    required this.shadowOffset,
  });

  /// Octagon (rectangle with each corner chamfered by [notch]).
  Path _shape(double w, double h) {
    final n = notch;
    return Path()
      ..moveTo(n, 0)
      ..lineTo(w - n, 0)
      ..lineTo(w, n)
      ..lineTo(w, h - n)
      ..lineTo(w - n, h)
      ..lineTo(n, h)
      ..lineTo(0, h - n)
      ..lineTo(0, n)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shape(size.width, size.height);

    if (shadow != null &&
        (shadowOffset.dx != 0 || shadowOffset.dy != 0)) {
      canvas.save();
      canvas.translate(shadowOffset.dx, shadowOffset.dy);
      canvas.drawPath(path, Paint()..color = shadow!);
      canvas.restore();
    }

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(covariant _PixelBoxPainter old) =>
      old.color != color ||
      old.border != border ||
      old.shadow != shadow ||
      old.borderWidth != borderWidth ||
      old.notch != notch ||
      old.shadowOffset != shadowOffset;
}

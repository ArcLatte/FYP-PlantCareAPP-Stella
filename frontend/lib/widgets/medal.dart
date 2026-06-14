import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/medal_series.dart';

/// A shaped, metallic medal disc with an embossed icon and a star row for
/// the earned level. The silhouette comes from the series' category
/// (circle = daily care, shield = growth, hexagon = streaks, seal =
/// scanning/health, diamond = variety/progression) and the metal upgrades
/// bronze → diamond as levels unlock. Locked series render grey.
class Medal extends StatelessWidget {
  final MedalMetal metal;
  final MedalShape shape;
  final IconData icon;
  final int level;
  final int maxLevel;

  /// Disc diameter; the full widget is taller when stars are shown.
  final double size;
  final bool showStars;
  final bool glow;

  const Medal({
    super.key,
    required this.metal,
    required this.icon,
    required this.level,
    required this.maxLevel,
    this.shape = MedalShape.circle,
    this.size = 72,
    this.showStars = true,
    this.glow = false,
  });

  /// Convenience constructor straight from a series.
  Medal.series(
    MedalSeries series, {
    super.key,
    this.size = 72,
    this.showStars = true,
    this.glow = false,
  })  : metal = series.metal,
        shape = series.shape,
        icon = series.icon,
        level = series.level,
        maxLevel = series.maxLevel;

  bool get _locked => metal == MedalMetal.locked;

  @override
  Widget build(BuildContext context) {
    final starSize = (size * 0.22).clamp(10.0, 18.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _MedalDiscPainter(
                  metal: metal,
                  shape: shape,
                  glow: glow && !_locked,
                ),
              ),
              // Embossed icon: dark offset shadow under the glyph.
              Transform.translate(
                offset: const Offset(0.8, 1.4),
                child: Icon(
                  icon,
                  size: size * 0.38,
                  color: Colors.black.withValues(alpha: 0.30),
                ),
              ),
              Icon(
                icon,
                size: size * 0.38,
                color: _locked
                    ? Colors.white.withValues(alpha: 0.55)
                    : Colors.white,
              ),
            ],
          ),
        ),
        if (showStars) ...[
          SizedBox(height: size * 0.08),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < maxLevel; i++)
                Icon(
                  i < level ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: starSize,
                  color: i < level ? metal.color : const Color(0xFFBDBDB5),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Paints the shaped disc: optional glow, drop shadow, metallic gradient
/// fill, darker rim ring, and a specular highlight clipped to the shape.
class _MedalDiscPainter extends CustomPainter {
  final MedalMetal metal;
  final MedalShape shape;
  final bool glow;

  _MedalDiscPainter({
    required this.metal,
    required this.shape,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final (light, dark) = metal.gradient;
    final path = _shapePath(shape, size, inset: size.width * 0.02);

    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = dark.withValues(alpha: 0.55)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, size.width * 0.10),
      );
    } else {
      canvas.drawShadow(
          path, Colors.black.withValues(alpha: 0.35), 3, true);
    }

    // Metallic face.
    final rect = Offset.zero & size;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, dark],
        ).createShader(rect),
    );

    // Rim ring: the same silhouette, inset and stroked darker. The inner
    // face flips the gradient for a subtle machined look.
    final rim = _shapePath(shape, size, inset: size.width * 0.10);
    canvas.drawPath(
      rim,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [light, dark],
        ).createShader(rect),
    );
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.025
        ..color =
            Color.lerp(dark, Colors.black, 0.25)!.withValues(alpha: 0.55),
    );

    // Specular highlight, clipped so it never escapes the silhouette.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.32, size.height * 0.22),
        width: size.width * 0.34,
        height: size.height * 0.16,
      ),
      Paint()
        ..color = Colors.white
            .withValues(alpha: metal == MedalMetal.locked ? 0.25 : 0.40),
    );
    canvas.restore();
  }

  /// Silhouette path for [shape], inset from the box edge.
  static Path _shapePath(MedalShape shape, Size size, {double inset = 0}) {
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(w, h) / 2;

    switch (shape) {
      case MedalShape.circle:
        return Path()
          ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

      case MedalShape.shield:
        // Crest: flat rounded top, sides tapering to a bottom point.
        final left = cx - r;
        final right = cx + r;
        final top = cy - r;
        final bottom = cy + r;
        final cornerR = r * 0.25;
        return Path()
          ..moveTo(left + cornerR, top)
          ..lineTo(right - cornerR, top)
          ..quadraticBezierTo(right, top, right, top + cornerR)
          ..lineTo(right, cy + r * 0.05)
          ..quadraticBezierTo(
              right, cy + r * 0.62, cx, bottom)
          ..quadraticBezierTo(
              left, cy + r * 0.62, left, cy + r * 0.05)
          ..lineTo(left, top + cornerR)
          ..quadraticBezierTo(left, top, left + cornerR, top)
          ..close();

      case MedalShape.hexagon:
        // Pointy-top hexagon.
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = -math.pi / 2 + i * math.pi / 3;
          final p = Offset(
              cx + r * math.cos(angle), cy + r * math.sin(angle));
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        return path..close();

      case MedalShape.seal:
        // Scalloped award seal: radius modulated by a cosine wave.
        final path = Path();
        const scallops = 10;
        const steps = 120;
        for (int i = 0; i <= steps; i++) {
          final t = 2 * math.pi * i / steps;
          final rr = r * (0.92 + 0.08 * math.cos(scallops * t));
          final p = Offset(cx + rr * math.cos(t), cy + rr * math.sin(t));
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        return path..close();

      case MedalShape.diamond:
        // Rhombus with slightly softened corners.
        final soft = r * 0.12;
        return Path()
          ..moveTo(cx - soft, cy - r + soft * 0.4)
          ..quadraticBezierTo(cx, cy - r, cx + soft, cy - r + soft * 0.4)
          ..lineTo(cx + r - soft * 0.4, cy - soft)
          ..quadraticBezierTo(cx + r, cy, cx + r - soft * 0.4, cy + soft)
          ..lineTo(cx + soft, cy + r - soft * 0.4)
          ..quadraticBezierTo(cx, cy + r, cx - soft, cy + r - soft * 0.4)
          ..lineTo(cx - r + soft * 0.4, cy + soft)
          ..quadraticBezierTo(cx - r, cy, cx - r + soft * 0.4, cy - soft)
          ..close();
    }
  }

  @override
  bool shouldRepaint(covariant _MedalDiscPainter old) =>
      old.metal != metal || old.shape != shape || old.glow != glow;
}

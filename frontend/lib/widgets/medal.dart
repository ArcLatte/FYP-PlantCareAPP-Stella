import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/medal_series.dart';

/// A shaped, metallic medal with an embossed icon, a star row for the
/// earned level, and ornaments that stack up as the metal evolves:
///
///   bronze   — polished disc with a machined rim
///   silver   — + ribbon tails behind the disc
///   gold     — + laurel wreath hugging the sides
///   amethyst — + jewel crest on top
///   diamond  — + radiant halo spikes behind everything
///
/// The silhouette still comes from the series' category (circle = daily
/// care, shield = growth, hexagon = streaks, seal = scanning/health,
/// diamond = variety/progression). Locked series render flat grey.
class Medal extends StatelessWidget {
  final MedalMetal metal;
  final MedalShape shape;
  final IconData icon;
  final int level;
  final int maxLevel;

  /// Widget box width; the full widget is taller when stars are shown.
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
    final starSize = (size * 0.20).clamp(9.0, 17.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _MedalPainter(
                  metal: metal,
                  shape: shape,
                  glow: glow && !_locked,
                ),
              ),
              // Icon centered on the disc (which sits slightly above the
              // box middle to leave room for the ribbon tails).
              Align(
                alignment: const Alignment(0, _MedalPainter.kIconAlignY),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Embossed shadow under the glyph.
                    Transform.translate(
                      offset: const Offset(0.7, 1.2),
                      child: Icon(
                        icon,
                        size: size * 0.30,
                        color: Colors.black.withValues(alpha: 0.30),
                      ),
                    ),
                    Icon(
                      icon,
                      size: size * 0.30,
                      color: _locked
                          ? Colors.white.withValues(alpha: 0.55)
                          : Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showStars) ...[
          SizedBox(height: size * 0.04),
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

/// Paints the full medal: halo spikes, ribbon tails, shaped metallic disc
/// with rim + engraving, wreath, and jewel crest — gated by the metal tier.
class _MedalPainter extends CustomPainter {
  final MedalMetal metal;
  final MedalShape shape;
  final bool glow;

  _MedalPainter({
    required this.metal,
    required this.shape,
    required this.glow,
  });

  /// Disc center sits at 0.47 of the box height; expressed as an
  /// [Alignment] y for the icon overlay: 0.47 * 2 - 1.
  static const double kIconAlignY = -0.06;

  /// Ribbon cloth color per metal — the classic award-ribbon pairings.
  static Color _ribbonColor(MedalMetal m) {
    switch (m) {
      case MedalMetal.silver:
        return const Color(0xFF5E7290);
      case MedalMetal.gold:
        return const Color(0xFFC0394B);
      case MedalMetal.amethyst:
        return const Color(0xFF6C3FA8);
      case MedalMetal.diamond:
        return const Color(0xFF2E8FA3);
      default:
        return const Color(0xFF8C5A2B);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s * 0.5, s * 0.47);
    final discR = s * 0.36;
    final (light, dark) = metal.gradient;
    final tier = metal.index; // locked=0 … diamond=5

    if (metal == MedalMetal.diamond) {
      _halo(canvas, center, discR, light);
    }
    if (tier >= MedalMetal.silver.index) {
      _ribbons(canvas, s, center, discR);
    }

    final path = _shapePath(shape, center, discR);

    if (glow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = dark.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.09),
      );
    } else {
      canvas.drawShadow(path, Colors.black.withValues(alpha: 0.35), 3, true);
    }

    _disc(canvas, path, center, discR, light, dark);

    if (tier >= MedalMetal.gold.index) {
      _wreath(canvas, center, discR, dark);
    }
    if (tier >= MedalMetal.amethyst.index) {
      _jewel(canvas, s, center, discR, light, dark);
    }
  }

  /// Radiant spikes behind the disc — the diamond-tier crown.
  void _halo(Canvas canvas, Offset center, double discR, Color light) {
    final paint = Paint()..color = light.withValues(alpha: 0.65);
    const spikes = 12;
    for (int i = 0; i < spikes; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / spikes;
      final len = discR * (i.isEven ? 1.30 : 1.14);
      final halfW = math.pi / spikes * 0.30;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx + math.cos(a - halfW) * discR * 0.9,
              center.dy + math.sin(a - halfW) * discR * 0.9)
          ..lineTo(
              center.dx + math.cos(a) * len, center.dy + math.sin(a) * len)
          ..lineTo(center.dx + math.cos(a + halfW) * discR * 0.9,
              center.dy + math.sin(a + halfW) * discR * 0.9)
          ..close(),
        paint,
      );
    }
  }

  /// Two notched ribbon tails fanning out from behind the disc bottom.
  void _ribbons(Canvas canvas, double s, Offset center, double discR) {
    final cloth = _ribbonColor(metal);
    for (final sign in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(center.dx, center.dy + discR * 0.15);
      canvas.rotate(sign * 0.42);
      final w = s * 0.155;
      final len = s * 0.46;
      final notch = w * 0.55;
      final tail = Path()
        ..moveTo(-w / 2, 0)
        ..lineTo(w / 2, 0)
        ..lineTo(w / 2, len)
        ..lineTo(0, len - notch)
        ..lineTo(-w / 2, len)
        ..close();
      canvas.drawPath(
        tail,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.lerp(cloth, Colors.black, 0.28)!,
              cloth,
              Color.lerp(cloth, Colors.black, 0.20)!,
            ],
          ).createShader(Rect.fromLTWH(-w / 2, 0, w, len)),
      );
      // Center stripe for that woven-ribbon look.
      canvas.drawRect(
        Rect.fromLTWH(-w * 0.12, 0, w * 0.24, len - notch * 0.4),
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
      canvas.restore();
    }
  }

  /// Metallic face: 3-stop gradient, machined inner ring with flipped
  /// gradient, engraved tick dots, and a curved specular highlight.
  void _disc(Canvas canvas, Path path, Offset center, double discR,
      Color light, Color dark) {
    final mid = Color.lerp(light, dark, 0.45)!;
    final rect = Rect.fromCircle(center: center, radius: discR);

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, mid, dark],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    // Outer edge line.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = discR * 0.045
        ..color = Color.lerp(dark, Colors.black, 0.30)!
            .withValues(alpha: 0.65),
    );

    // Inner face, gradient flipped for a machined-step look.
    final inner = _shapePath(shape, center, discR * 0.80);
    canvas.drawPath(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [light, dark],
        ).createShader(rect),
    );
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = discR * 0.05
        ..color = Color.lerp(dark, Colors.black, 0.25)!
            .withValues(alpha: 0.55),
    );

    // Engraved dots between rim and inner face.
    if (metal != MedalMetal.locked) {
      final dotPaint = Paint()
        ..color = Color.lerp(dark, Colors.black, 0.2)!
            .withValues(alpha: 0.5);
      const dots = 16;
      for (int i = 0; i < dots; i++) {
        final a = 2 * math.pi * i / dots + math.pi / dots;
        canvas.drawCircle(
          Offset(center.dx + math.cos(a) * discR * 0.90,
              center.dy + math.sin(a) * discR * 0.90),
          discR * 0.028,
          dotPaint,
        );
      }
    }

    // Specular arc along the upper-left rim.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: discR * 0.88),
      math.pi * 0.95,
      math.pi * 0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = discR * 0.10
        ..color = Colors.white
            .withValues(alpha: metal == MedalMetal.locked ? 0.20 : 0.45),
    );
    canvas.restore();
  }

  /// Laurel branches hugging the lower sides of the disc.
  void _wreath(Canvas canvas, Offset center, double discR, Color dark) {
    final leafPaint = Paint()
      ..color = Color.lerp(dark, Colors.black, 0.12)!;
    final veinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = discR * 0.02;
    final rr = discR * 1.12;
    const leaves = 6;
    for (final sign in const [-1.0, 1.0]) {
      for (int i = 0; i < leaves; i++) {
        // From just below horizontal down toward the bottom.
        final a = math.pi / 2 + sign * (math.pi * 0.14 + i * math.pi * 0.075);
        final p = Offset(
            center.dx + math.cos(a) * rr, center.dy + math.sin(a) * rr);
        final leafLen = discR * (0.24 - i * 0.012);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        // Tangential, tips pointing up the branch.
        canvas.rotate(a - sign * math.pi * 0.34);
        final leaf = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(leafLen * 0.42, -leafLen * 0.5, 0, -leafLen)
          ..quadraticBezierTo(-leafLen * 0.42, -leafLen * 0.5, 0, 0)
          ..close();
        canvas.drawPath(leaf, leafPaint);
        canvas.drawLine(Offset.zero, Offset(0, -leafLen * 0.8), veinPaint);
        canvas.restore();
      }
    }
  }

  /// Faceted jewel crest at the top of the medal.
  void _jewel(Canvas canvas, double s, Offset center, double discR,
      Color light, Color dark) {
    final c = Offset(center.dx, center.dy - discR * 1.06);
    final r = discR * 0.22;
    final gem = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.9, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.9, c.dy)
      ..close();
    canvas.drawPath(
      gem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, light, dark],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(
      gem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..color = Color.lerp(dark, Colors.black, 0.3)!,
    );
    // Facet lines.
    final facet = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.10;
    canvas.drawLine(
        Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), facet);
    canvas.drawLine(
        Offset(c.dx - r * 0.9, c.dy), Offset(c.dx + r * 0.9, c.dy), facet);
  }

  /// Silhouette path for [shape], centered at [center] with radius [r].
  static Path _shapePath(MedalShape shape, Offset center, double r) {
    final cx = center.dx;
    final cy = center.dy;

    switch (shape) {
      case MedalShape.circle:
        return Path()
          ..addOval(Rect.fromCircle(center: center, radius: r));

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
          ..quadraticBezierTo(right, cy + r * 0.62, cx, bottom)
          ..quadraticBezierTo(left, cy + r * 0.62, left, cy + r * 0.05)
          ..lineTo(left, top + cornerR)
          ..quadraticBezierTo(left, top, left + cornerR, top)
          ..close();

      case MedalShape.hexagon:
        // Pointy-top hexagon.
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = -math.pi / 2 + i * math.pi / 3;
          final p =
              Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
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
  bool shouldRepaint(covariant _MedalPainter old) =>
      old.metal != metal || old.shape != shape || old.glow != glow;
}

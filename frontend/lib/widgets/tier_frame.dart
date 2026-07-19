import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Code-drawn avatar frames for Stella's eight gardening tiers.
///
/// The API still returns the original tier keys (Seedling, Sprout, ...), so
/// [tierIndex] accepts both those keys and the player-facing upgrade names.
class TierFrame extends StatelessWidget {
  final String tier;
  final double size;
  final Widget child;

  const TierFrame({
    super.key,
    required this.tier,
    required this.size,
    required this.child,
  });

  static const tierNames = <String>[
    'Garden Novice',
    'Garden Apprentice',
    'Plant Tender',
    'Skilled Gardener',
    'Expert Cultivator',
    'Master Horticulturist',
    'Garden Guardian',
    'Garden Sage',
  ];

  static const _apiTierKeys = <String>[
    'Seedling',
    'Sprout',
    'Sapling',
    'Gardener',
    'Cultivator',
    'Botanist',
    'Plantsmith',
    'Garden Sage',
  ];

  /// Returns the 0...7 visual stage for an API key or display name.
  static int tierIndex(String tier) {
    final displayIndex = tierNames.indexOf(tier);
    if (displayIndex >= 0) return displayIndex;
    final apiIndex = _apiTierKeys.indexOf(tier);
    return apiIndex < 0 ? 0 : apiIndex;
  }

  /// Player-facing tier name for the backend's level thresholds.
  static String tierForLevel(int level) {
    if (level < 5) return tierNames[0];
    if (level < 10) return tierNames[1];
    if (level < 20) return tierNames[2];
    if (level < 35) return tierNames[3];
    if (level < 50) return tierNames[4];
    if (level < 75) return tierNames[5];
    if (level < 100) return tierNames[6];
    return tierNames[7];
  }

  static Color tierColor(String tier) => const <Color>[
    Color(0xFFB28758),
    Color(0xFF62A45E),
    Color(0xFF3F8C55),
    Color(0xFF9A6739),
    Color(0xFF9DAAB1),
    Color(0xFF4B83B6),
    Color(0xFFD09A2D),
    Color(0xFFF0B93F),
  ][tierIndex(tier)];

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TierFramePainter(tierIndex(tier)),
        child: Padding(
          padding: EdgeInsets.all(size * 0.17),
          child: ClipOval(child: child),
        ),
      ),
    );
  }
}

class _TierFramePainter extends CustomPainter {
  final int index;

  const _TierFramePainter(this.index);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.405;

    switch (index) {
      case 0:
        _paintNovice(canvas, center, radius, size);
      case 1:
        _paintApprentice(canvas, center, radius, size);
      case 2:
        _paintTender(canvas, center, radius, size);
      case 3:
        _paintGardener(canvas, center, radius, size);
      case 4:
        _paintCultivator(canvas, center, radius, size);
      case 5:
        _paintHorticulturist(canvas, center, radius, size);
      case 6:
        _paintGuardian(canvas, center, radius, size);
      default:
        _paintSage(canvas, center, radius, size);
    }
  }

  double _u(Size size) => size.shortestSide / 160;

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _paintNovice(Canvas canvas, Offset c, double r, Size size) {
    final u = _u(size);
    canvas.drawCircle(c, r, _stroke(const Color(0xFF6F4B2E), 9 * u));

    // Short alternating arcs create a readable woven-twine braid.
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < 24; i++) {
      final start = i * math.pi / 12;
      canvas.drawArc(
        rect,
        start,
        math.pi / 17,
        false,
        _stroke(
          i.isEven ? const Color(0xFFD5A86C) : const Color(0xFF9A6A3E),
          3.2 * u,
        ),
      );
    }
    for (final angle in <double>[0.2, 1.9, 3.35, 5.15]) {
      _binding(canvas, c, r, angle, u);
    }
    _seed(canvas, _polar(c, r + 3 * u, -0.35), -0.35, u);
    _seed(canvas, _polar(c, r + 2 * u, 2.55), 2.55, u);
    _seed(canvas, _polar(c, r + 1 * u, 3.05), 3.05, u);
  }

  void _paintApprentice(Canvas canvas, Offset c, double r, Size size) {
    final u = _u(size);
    final dark = const Color(0xFF2E6F49);
    final light = const Color(0xFF70B66A);
    canvas.drawCircle(c, r - 3 * u, _stroke(dark, 5 * u));
    canvas.drawCircle(c, r + 3 * u, _stroke(light, 5 * u));

    // Highlights make the two soft vines read as separate intertwined stems.
    final rectA = Rect.fromCircle(center: c, radius: r - 3 * u);
    final rectB = Rect.fromCircle(center: c, radius: r + 3 * u);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + 0.18;
      canvas.drawArc(rectA, a, math.pi / 5.2, false, _stroke(light, 2 * u));
      canvas.drawArc(
        rectB,
        a + math.pi / 4,
        math.pi / 5.2,
        false,
        _stroke(const Color(0xFFB0D681), 1.8 * u),
      );
    }
    for (final angle in <double>[-0.62, 0.78, 2.25, 3.72]) {
      _leaf(
        canvas,
        _polar(c, r + 3 * u, angle),
        angle + math.pi / 2,
        12 * u,
        5.5 * u,
        const Color(0xFF4B955A),
        u,
      );
    }
    for (final angle in <double>[-0.84, 2.08]) {
      _bud(canvas, _polar(c, r + 7 * u, angle), angle, u);
    }
  }

  void _paintTender(Canvas canvas, Offset c, double r, Size size) {
    final u = _u(size);
    canvas.drawCircle(c, r, _stroke(const Color(0xFF2E6743), 8 * u));
    canvas.drawCircle(c, r, _stroke(const Color(0xFF76B66B), 3 * u));
    canvas.drawCircle(
      c,
      r - 7 * u,
      _stroke(const Color(0xFFB9D78F).withValues(alpha: 0.8), 1.4 * u),
    );

    for (final baseAngle in <double>[
      -math.pi / 4,
      math.pi / 4,
      3 * math.pi / 4,
      5 * math.pi / 4,
    ]) {
      final anchor = _polar(c, r + 1 * u, baseAngle);
      _leaf(
        canvas,
        anchor,
        baseAngle - 0.45,
        16 * u,
        7 * u,
        const Color(0xFF438D52),
        u,
      );
      _leaf(
        canvas,
        anchor,
        baseAngle + 0.45,
        14 * u,
        6 * u,
        const Color(0xFF6FB566),
        u,
      );
      _leaf(
        canvas,
        _polar(c, r + 2 * u, baseAngle + 0.12),
        baseAngle,
        12 * u,
        5 * u,
        const Color(0xFF397C4A),
        u,
      );
    }
    _sproutCrest(canvas, c, r, u);
  }

  void _paintGardener(Canvas canvas, Offset c, double r, Size size) {
    final u = _u(size);
    final outer = _stroke(const Color(0xFF6C401F), 12 * u);
    canvas.drawCircle(c, r, outer);
    canvas.drawCircle(c, r, _stroke(const Color(0xFFB97A3E), 7 * u));
    canvas.drawCircle(c, r - 8 * u, _stroke(const Color(0xFFE0A55F), 1.5 * u));

    // Trellis joints and slats.
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final a = _polar(c, r - 7 * u, angle);
      final b = _polar(c, r + 7 * u, angle);
      canvas.drawLine(a, b, _stroke(const Color(0xFF5A351D), 4 * u));
      canvas.drawCircle(
        _polar(c, r, angle),
        2.2 * u,
        Paint()..color = const Color(0xFFD9A15D),
      );
    }
    final rect = Rect.fromCircle(center: c, radius: r + 1 * u);
    for (var i = 0; i < 12; i += 2) {
      canvas.drawArc(
        rect,
        i * math.pi / 6 + 0.06,
        math.pi / 8,
        false,
        _stroke(const Color(0xFFE5B26E), 1.7 * u),
      );
    }
    _trowelCrest(canvas, c, r, u);
  }

  void _paintCultivator(Canvas canvas, Offset c, double r, Size size) {
    final u = _u(size);
    final silver = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF59656B), Color(0xFFE7EEF0), Color(0xFF87969D)],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11 * u;
    canvas.drawCircle(c, r, silver);
    canvas.drawCircle(c, r - 8 * u, _stroke(const Color(0xFF46535A), 2 * u));
    canvas.drawCircle(
      c,
      r + 7 * u,
      _stroke(const Color(0xFFC8D1D4).withValues(alpha: 0.9), 2 * u),
    );

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + math.pi / 8;
      final p = _polar(c, r, angle);
      canvas.drawCircle(p, 2.7 * u, Paint()..color = const Color(0xFF566269));
      canvas.drawCircle(p, 1.2 * u, Paint()..color = const Color(0xFFF2F5F4));
    }
    for (final angle in <double>[0.45, 1.0, 2.15, 2.7]) {
      _metalLeaf(
        canvas,
        _polar(c, r + 2 * u, angle),
        angle + math.pi / 2,
        14 * u,
        6 * u,
        const Color(0xFFAAB5B9),
        u,
      );
    }
    _shearsCrest(canvas, c, r, u);
  }

  void _paintHorticulturist(Canvas canvas, Offset c, double r, Size size) {
    final u = _u(size);
    final blue = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF183A65),
          Color(0xFF4F91BE),
          Color(0xFF224B78),
          Color(0xFF79B7CE),
          Color(0xFF183A65),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16 * u;
    canvas.drawCircle(c, r, blue);
    canvas.drawCircle(c, r - 10 * u, _stroke(const Color(0xFFBED9E1), 2 * u));
    canvas.drawCircle(c, r + 10 * u, _stroke(const Color(0xFF294765), 2.2 * u));

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final p = _polar(c, r, angle);
      _pressedLeaf(canvas, p, angle + math.pi / 2, 16 * u, 6 * u, u);
    }
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + math.pi / 8;
      canvas.drawCircle(
        _polar(c, r, angle),
        1.6 * u,
        Paint()..color = const Color(0xFFE0F1EE),
      );
    }
  }

  void _paintGuardian(Canvas canvas, Offset c, double r, Size size) {
    final u = _u(size);
    final glow = _stroke(const Color(0x99E9B33F), 14 * u)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * u);
    canvas.drawCircle(c, r, glow);
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFD66A), Color(0xFFB97817), Color(0xFFF0BB42)],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13 * u;
    canvas.drawCircle(c, r, gold);
    canvas.drawCircle(c, r - 9 * u, _stroke(const Color(0xFF815215), 2 * u));
    canvas.drawCircle(c, r + 9 * u, _stroke(const Color(0xFFFFD66A), 2 * u));

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final p = _polar(c, r + 4 * u, angle);
      _armorLeaf(canvas, p, angle + math.pi / 2, 21 * u, 9 * u, u);
    }
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + math.pi / 8;
      final p = _polar(c, r, angle);
      canvas.drawCircle(p, 3.1 * u, Paint()..color = const Color(0xFF70420E));
      canvas.drawCircle(p, 1.5 * u, Paint()..color = const Color(0xFFFFDB73));
    }
  }

  void _paintSage(Canvas canvas, Offset c, double r, Size size) {
    final u = _u(size);
    final glow = _stroke(const Color(0x99F5C34F), 18 * u)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * u);
    canvas.drawCircle(c, r, glow);
    canvas.drawCircle(c, r, _stroke(const Color(0xFF275E3B), 10 * u));
    canvas.drawCircle(c, r + 3 * u, _stroke(const Color(0xFFC9962E), 2 * u));
    canvas.drawCircle(c, r - 5 * u, _stroke(const Color(0xFF4E9B58), 3 * u));

    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final outward = i.isEven ? 3.0 : -3.0;
      _leaf(
        canvas,
        _polar(c, r + outward * u, angle),
        angle + (i.isEven ? 0.75 : -0.75),
        (i.isEven ? 15 : 12) * u,
        (i.isEven ? 6.5 : 5.5) * u,
        i % 3 == 0 ? const Color(0xFF78B95F) : const Color(0xFF3D894E),
        u,
      );
    }
    for (final entry in <(double, Color, double)>[
      (-0.42, Color(0xFFE97C82), 7.0),
      (0.70, Color(0xFFF2C85F), 6.2),
      (1.72, Color(0xFFD88ECB), 6.8),
      (2.72, Color(0xFFF1EEE2), 6.3),
      (3.70, Color(0xFFECA46B), 6.8),
      (4.72, Color(0xFFB68AD5), 6.1),
    ]) {
      _flower(
        canvas,
        _polar(c, r + 5 * u, entry.$1),
        entry.$2,
        entry.$3 * u,
        u,
      );
    }
    for (final angle in <double>[-0.9, 0.22, 1.23, 2.22, 3.25, 4.2]) {
      _sparkle(canvas, _polar(c, r + 18 * u, angle), 3.3 * u);
    }
  }

  Offset _polar(Offset center, double radius, double angle) =>
      center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);

  void _binding(Canvas canvas, Offset c, double r, double angle, double u) {
    final p = _polar(c, r, angle);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final paint = _stroke(const Color(0xFFE0B477), 1.7 * u);
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(i * 2.2 * u, -5 * u),
        Offset(i * 2.2 * u, 5 * u),
        paint,
      );
    }
    canvas.restore();
  }

  void _seed(Canvas canvas, Offset p, double angle, double u) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, -5 * u)
      ..quadraticBezierTo(4 * u, 0, 0, 6 * u)
      ..quadraticBezierTo(-4 * u, 0, 0, -5 * u)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFC6914D));
    canvas.drawLine(
      Offset.zero,
      Offset(0, 4 * u),
      _stroke(const Color(0xFF70482B), 0.9 * u),
    );
    canvas.restore();
  }

  void _leaf(
    Canvas canvas,
    Offset p,
    double angle,
    double length,
    double width,
    Color color,
    double u,
  ) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, -length / 2)
      ..quadraticBezierTo(width, -length * 0.1, 0, length / 2)
      ..quadraticBezierTo(-width, -length * 0.1, 0, -length / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawLine(
      Offset(0, -length * 0.3),
      Offset(0, length * 0.33),
      _stroke(Colors.white.withValues(alpha: 0.35), 0.8 * u),
    );
    canvas.restore();
  }

  void _metalLeaf(
    Canvas canvas,
    Offset p,
    double angle,
    double length,
    double width,
    Color color,
    double u,
  ) {
    _leaf(canvas, p, angle, length, width, color, u);
    canvas.drawCircle(p, 1.1 * u, Paint()..color = const Color(0xFFF5F7F7));
  }

  void _bud(Canvas canvas, Offset p, double angle, double u) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 7 * u, height: 10 * u),
      Paint()..color = const Color(0xFFF0A5A1),
    );
    canvas.drawLine(
      Offset(0, 4 * u),
      Offset(0, 9 * u),
      _stroke(const Color(0xFF3D7747), 1.7 * u),
    );
    canvas.restore();
  }

  void _sproutCrest(Canvas canvas, Offset c, double r, double u) {
    final stemTop = Offset(c.dx, c.dy - r - 13 * u);
    canvas.drawLine(
      Offset(c.dx, c.dy - r + 5 * u),
      stemTop,
      _stroke(const Color(0xFF377748), 3 * u),
    );
    _leaf(
      canvas,
      stemTop + Offset(-5 * u, 1 * u),
      -0.82,
      15 * u,
      6 * u,
      const Color(0xFF6FB566),
      u,
    );
    _leaf(
      canvas,
      stemTop + Offset(5 * u, 1 * u),
      0.82,
      15 * u,
      6 * u,
      const Color(0xFF8BC66F),
      u,
    );
  }

  void _trowelCrest(Canvas canvas, Offset c, double r, double u) {
    final top = c.dy - r - 15 * u;
    canvas.drawLine(
      Offset(c.dx, top + 10 * u),
      Offset(c.dx, top + 25 * u),
      _stroke(const Color(0xFF70401F), 4 * u),
    );
    final blade = Path()
      ..moveTo(c.dx, top - 1 * u)
      ..quadraticBezierTo(c.dx + 10 * u, top + 7 * u, c.dx, top + 14 * u)
      ..quadraticBezierTo(c.dx - 10 * u, top + 7 * u, c.dx, top - 1 * u)
      ..close();
    canvas.drawPath(blade, Paint()..color = const Color(0xFFD8DDDA));
    canvas.drawPath(blade, _stroke(const Color(0xFF606966), 1.5 * u));
    canvas.drawCircle(
      Offset(c.dx, top + 25 * u),
      2.3 * u,
      Paint()..color = const Color(0xFFE6B36F),
    );
  }

  void _shearsCrest(Canvas canvas, Offset c, double r, double u) {
    final pivot = Offset(c.dx, c.dy - r - 1 * u);
    final dark = _stroke(const Color(0xFF465159), 3.4 * u);
    canvas.drawLine(pivot, pivot + Offset(-10 * u, -13 * u), dark);
    canvas.drawLine(pivot, pivot + Offset(10 * u, -13 * u), dark);
    canvas.drawLine(pivot, pivot + Offset(-8 * u, 10 * u), dark);
    canvas.drawLine(pivot, pivot + Offset(8 * u, 10 * u), dark);
    canvas.drawCircle(pivot, 3 * u, Paint()..color = const Color(0xFFEDF1F1));
    canvas.drawCircle(pivot + Offset(-9 * u, -15 * u), 4 * u, dark);
    canvas.drawCircle(pivot + Offset(9 * u, -15 * u), 4 * u, dark);
  }

  void _pressedLeaf(
    Canvas canvas,
    Offset p,
    double angle,
    double length,
    double width,
    double u,
  ) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, -length / 2)
      ..quadraticBezierTo(width, 0, 0, length / 2)
      ..quadraticBezierTo(-width, 0, 0, -length / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFAED9D2));
    canvas.drawLine(
      Offset(0, -length * 0.4),
      Offset(0, length * 0.4),
      _stroke(const Color(0xFFF0F5E9), 0.8 * u),
    );
    for (final y in <double>[-0.2, 0.05, 0.28]) {
      canvas.drawLine(
        Offset(0, length * y),
        Offset(width * 0.65, length * (y - 0.1)),
        _stroke(const Color(0xFFF0F5E9), 0.55 * u),
      );
      canvas.drawLine(
        Offset(0, length * y),
        Offset(-width * 0.65, length * (y - 0.1)),
        _stroke(const Color(0xFFF0F5E9), 0.55 * u),
      );
    }
    canvas.restore();
  }

  void _armorLeaf(
    Canvas canvas,
    Offset p,
    double angle,
    double length,
    double width,
    double u,
  ) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, -length * 0.62)
      ..lineTo(width, -length * 0.08)
      ..lineTo(width * 0.45, length * 0.45)
      ..lineTo(0, length * 0.2)
      ..lineTo(-width * 0.45, length * 0.45)
      ..lineTo(-width, -length * 0.08)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFCF8F20));
    canvas.drawPath(path, _stroke(const Color(0xFFFFD96A), 1.3 * u));
    canvas.drawLine(
      Offset(0, -length * 0.48),
      Offset.zero,
      _stroke(const Color(0xFFFFE49A), 1 * u),
    );
    canvas.restore();
  }

  void _flower(Canvas canvas, Offset p, Color color, double radius, double u) {
    for (var i = 0; i < 5; i++) {
      final angle = i * 2 * math.pi / 5 - math.pi / 2;
      final petal =
          p + Offset(math.cos(angle), math.sin(angle)) * radius * 0.62;
      canvas.drawOval(
        Rect.fromCenter(center: petal, width: radius, height: radius * 1.25),
        Paint()..color = color,
      );
    }
    canvas.drawCircle(p, 2.2 * u, Paint()..color = const Color(0xFFFFD86D));
  }

  void _sparkle(Canvas canvas, Offset p, double radius) {
    final path = Path()
      ..moveTo(p.dx, p.dy - radius)
      ..lineTo(p.dx + radius * 0.22, p.dy - radius * 0.2)
      ..lineTo(p.dx + radius, p.dy)
      ..lineTo(p.dx + radius * 0.22, p.dy + radius * 0.2)
      ..lineTo(p.dx, p.dy + radius)
      ..lineTo(p.dx - radius * 0.22, p.dy + radius * 0.2)
      ..lineTo(p.dx - radius, p.dy)
      ..lineTo(p.dx - radius * 0.22, p.dy - radius * 0.2)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFE79A));
  }

  @override
  bool shouldRepaint(covariant _TierFramePainter oldDelegate) =>
      oldDelegate.index != index;
}

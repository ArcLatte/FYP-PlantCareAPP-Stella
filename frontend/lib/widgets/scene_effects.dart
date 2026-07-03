import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Code-drawn ambient "game feel" layers shared by the weather header and the
/// streak scene: sun rays, fireflies, pollen motes, shooting stars, birds,
/// parallax rain with ground splashes, drifting snow, lightning bolts,
/// butterflies, and one-shot sparkle bursts.
///
/// Every looping painter is driven by an external 0–1 loop value `t` from the
/// scene's AnimationController so a whole scene shares one ticker. All
/// periodic motion uses *integer* cycle counts per loop so the animation
/// wraps seamlessly when the controller restarts.

// ─── Rain (shared by weather header + streak scene) ────────────

/// Paints two parallax depths of rain streaks and, when [splashLine] is a
/// 0–1 fraction of the height (negative disables), small splash rings that
/// blip along that line as drops land.
void paintRain(
  Canvas canvas,
  Size size,
  double t,
  double intensity, {
  double splashLine = -1,
}) {
  const slant = 0.18;
  final mult = intensity.clamp(0.75, 1.6);

  void sheet(
    int seed,
    int count,
    double width,
    double len,
    int speed,
    double alpha,
  ) {
    final rng = math.Random(seed);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final sx = rng.nextDouble();
      final sy = rng.nextDouble();
      final fall = (t * speed + sy) % 1.0;
      final x = sx * size.width + fall * size.height * slant;
      final y = fall * (size.height + 20) - 10;
      canvas.drawLine(Offset(x, y), Offset(x + len * slant, y + len), paint);
    }
  }

  // Far sheet: thin, slow, faint — reads as depth behind the near sheet.
  sheet(3, 30, 1.0, 8, (4 * mult).round(), 0.16);
  sheet(4, 26, 1.6, 12, (6 * mult).round(), 0.34);

  if (splashLine >= 0) {
    final rng = math.Random(5);
    final y = splashLine * size.height;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 9; i++) {
      final sx = rng.nextDouble();
      final phase = rng.nextDouble();
      final cycle = (t * 12 + phase) % 1.0;
      if (cycle > 0.22) continue;
      final rp = cycle / 0.22;
      paint.color = Colors.white.withValues(alpha: (1 - rp) * 0.40);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sx * size.width, y),
          width: 6 + 22 * rp,
          height: 2 + 6 * rp,
        ),
        paint,
      );
    }
  }
}

/// Standalone rain painter for scenes without extra ground detail.
class AmbientRainPainter extends CustomPainter {
  final double t;
  final double intensity;
  final double splashLine;

  const AmbientRainPainter(this.t, this.intensity, {this.splashLine = -1});

  @override
  void paint(Canvas canvas, Size size) =>
      paintRain(canvas, size, t, intensity, splashLine: splashLine);

  @override
  bool shouldRepaint(AmbientRainPainter old) =>
      old.t != t || old.intensity != intensity;
}

// ─── Sun rays ──────────────────────────────────────────────────

/// Soft wedge rays rotating slowly around the box center; sized ~2x the sun
/// art and placed behind it.
class SunRaysPainter extends CustomPainter {
  final double t;
  final Color color;

  const SunRaysPainter(this.t, {this.color = const Color(0xFFFFE9A8)});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    // One full turn per loop keeps the wrap seamless.
    final base = t * 2 * math.pi;
    const rays = 10;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < rays; i++) {
      final a = base + i * 2 * math.pi / rays;
      final len = r * (i.isEven ? 1.0 : 0.76);
      const halfW = 0.11;
      paint.color = color.withValues(alpha: i.isEven ? 0.10 : 0.06);
      final path = Path()
        ..moveTo(
          c.dx + math.cos(a - halfW) * r * 0.34,
          c.dy + math.sin(a - halfW) * r * 0.34,
        )
        ..lineTo(c.dx + math.cos(a) * len, c.dy + math.sin(a) * len)
        ..lineTo(
          c.dx + math.cos(a + halfW) * r * 0.34,
          c.dy + math.sin(a + halfW) * r * 0.34,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(SunRaysPainter old) => old.t != t;
}

// ─── Fireflies ─────────────────────────────────────────────────

/// Wandering glow-dots that pulse on and off — night-time ambience.
class FirefliesPainter extends CustomPainter {
  final double t;
  final int count;
  final Color color;

  const FirefliesPainter(
    this.t, {
    this.count = 9,
    this.color = const Color(0xFFFFEF9E),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    for (var i = 0; i < count; i++) {
      final bx = rng.nextDouble();
      final by = 0.30 + rng.nextDouble() * 0.60;
      final wx = 0.03 + rng.nextDouble() * 0.05;
      final wy = 0.02 + rng.nextDouble() * 0.04;
      final fx = 1 + rng.nextInt(3);
      final fy = 1 + rng.nextInt(2);
      final ph = rng.nextDouble();
      final glowF = 3 + rng.nextInt(4);
      final glowP = rng.nextDouble();
      final x = (bx + wx * math.sin(2 * math.pi * (t * fx + ph))) * size.width;
      final y =
          (by + wy * math.sin(2 * math.pi * (t * fy + ph * 1.7))) *
          size.height;
      final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * (t * glowF + glowP));
      final a = 0.12 + 0.88 * pulse * pulse;
      canvas.drawCircle(
        Offset(x, y),
        4.5,
        Paint()
          ..color = color.withValues(alpha: 0.30 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        Offset(x, y),
        1.5,
        Paint()..color = color.withValues(alpha: 0.95 * a),
      );
    }
  }

  @override
  bool shouldRepaint(FirefliesPainter old) => old.t != t;
}

// ─── Pollen motes ──────────────────────────────────────────────

/// Tiny sunlit specks drifting slowly upward — daytime ambience.
class MotesPainter extends CustomPainter {
  final double t;
  final int count;
  final Color color;

  const MotesPainter(
    this.t, {
    this.count = 12,
    this.color = const Color(0xFFFFF6D8),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(13);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final sx = rng.nextDouble();
      final sy = rng.nextDouble();
      final rise = 1 + rng.nextInt(2);
      final swayF = 2 + rng.nextInt(3);
      final swayP = rng.nextDouble();
      final r = 0.9 + rng.nextDouble() * 1.3;
      final y = (sy - t * rise) % 1.0;
      final x =
          (sx + 0.02 * math.sin(2 * math.pi * (t * swayF + swayP))) *
          size.width;
      // Fade at the top and bottom edges so motes never pop in.
      paint.color = color.withValues(alpha: math.sin(y * math.pi) * 0.45);
      canvas.drawCircle(Offset(x, y * size.height), r, paint);
    }
  }

  @override
  bool shouldRepaint(MotesPainter old) => old.t != t;
}

// ─── Shooting stars ────────────────────────────────────────────

/// A couple of meteor streaks per loop on clear nights.
class ShootingStarsPainter extends CustomPainter {
  final double t;

  const ShootingStarsPainter(this.t);

  // (loop position, start x, start y) — all fractions.
  static const _events = [(0.30, 0.12, 0.10), (0.78, 0.55, 0.06)];

  @override
  void paint(Canvas canvas, Size size) {
    const window = 0.05;
    // Down-right heading, normalized.
    const dir = Offset(0.894, 0.447);
    for (final (t0, x0, y0) in _events) {
      final p = (t - t0) / window;
      if (p < 0 || p > 1) continue;
      final fade = math.sin(p * math.pi);
      final travel = size.width * 0.5;
      final head = Offset(x0 * size.width, y0 * size.height) + dir * travel * p;
      final tail = head - dir * size.width * 0.13 * (1 - 0.4 * p);
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.9 * fade),
            ],
          ).createShader(Rect.fromPoints(tail, head)),
      );
      canvas.drawCircle(
        head,
        2.4,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(ShootingStarsPainter old) => old.t != t;
}

// ─── Birds ─────────────────────────────────────────────────────

/// A small flock of flapping "m" birds crossing the sky twice per loop.
class BirdsPainter extends CustomPainter {
  final double t;

  const BirdsPainter(this.t);

  // (loop position the flock enters, base height fraction)
  static const _flights = [(0.08, 0.26), (0.56, 0.18)];
  static const _offsets = [Offset.zero, Offset(-16, 9), Offset(13, 12)];

  @override
  void paint(Canvas canvas, Size size) {
    const window = 0.20;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = const Color(0xFF44546A).withValues(alpha: 0.55);
    for (final (t0, yf) in _flights) {
      final p = (t - t0) / window;
      if (p < 0 || p > 1) continue;
      final baseX = (-0.10 + 1.20 * p) * size.width;
      final baseY = yf * size.height + 5 * math.sin(2 * math.pi * 3 * p);
      for (var i = 0; i < _offsets.length; i++) {
        final o = _offsets[i];
        final flap = math.sin(2 * math.pi * (t * 120 + i * 0.33));
        final c = Offset(baseX + o.dx, baseY + o.dy);
        final wingY = c.dy - 2.6 * flap - 1.2;
        final path = Path()
          ..moveTo(c.dx - 5, wingY)
          ..quadraticBezierTo(c.dx - 2, c.dy, c.dx, c.dy)
          ..quadraticBezierTo(c.dx + 2, c.dy, c.dx + 5, wingY);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(BirdsPainter old) => old.t != t;
}

// ─── Snow ──────────────────────────────────────────────────────

/// Code-drawn snowfall: seeded flakes at mixed depths, swaying as they fall.
class SnowPainter extends CustomPainter {
  final double t;

  const SnowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(17);
    final paint = Paint();
    for (var i = 0; i < 46; i++) {
      final sx = rng.nextDouble();
      final sy = rng.nextDouble();
      final r = 1.2 + rng.nextDouble() * 2.2;
      final speed = 3 + rng.nextInt(3);
      final swayF = 6 + rng.nextInt(6);
      final swayP = rng.nextDouble();
      final fall = (t * speed + sy) % 1.0;
      final x =
          (sx + 0.025 * math.sin(2 * math.pi * (t * swayF + swayP))) *
          size.width;
      final y = fall * (size.height + 12) - 6;
      // Bigger flakes read as nearer: brighter.
      paint.color = Colors.white.withValues(alpha: 0.35 + 0.45 * (r / 3.4));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(SnowPainter old) => old.t != t;
}

// ─── Lightning ─────────────────────────────────────────────────

/// Thunderstorm strikes: the sky flash plus a jagged bolt (with one branch)
/// dropping from the clouds, timed as a quick double-strike early in the loop
/// and a single strike later.
class LightningPainter extends CustomPainter {
  final double t;

  const LightningPainter(this.t);

  // (flash-spike center, spike width, bolt x as a width fraction)
  static const _strikes = [
    (0.18, 0.012, 0.30),
    (0.215, 0.010, 0.38),
    (0.63, 0.014, 0.66),
  ];

  static double _spike(double t, double center, double width) {
    final d = (t - center).abs();
    if (d >= width) return 0;
    final p = 1 - d / width;
    return p * p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    var flash = 0.0;
    for (final (c, w, _) in _strikes) {
      flash += _spike(t, c, w);
    }
    flash = flash.clamp(0.0, 1.0) * 0.30;
    if (flash > 0.004) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFEAF2FF).withValues(alpha: flash),
      );
    }

    for (final (c, w, xf) in _strikes) {
      final a = _spike(t, c, w * 1.6);
      if (a < 0.03) continue;
      _bolt(canvas, size, xf, a.clamp(0.0, 1.0));
    }
  }

  void _bolt(Canvas canvas, Size size, double xf, double a) {
    // Seeded by position so each strike reuses the same jag shape.
    final rng = math.Random((xf * 100).round());
    final path = Path();
    var x = xf * size.width;
    var y = size.height * 0.08;
    path.moveTo(x, y);
    Offset? branchAt;
    for (var i = 0; i < 5; i++) {
      x += (rng.nextDouble() - 0.5) * size.width * 0.10;
      y += size.height * (0.08 + rng.nextDouble() * 0.04);
      path.lineTo(x, y);
      if (i == 2) branchAt = Offset(x, y);
    }
    if (branchAt != null) {
      path.moveTo(branchAt.dx, branchAt.dy);
      path.lineTo(
        branchAt.dx - size.width * 0.06,
        branchAt.dy + size.height * 0.10,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 5
        ..color = const Color(0xFFBFD9FF).withValues(alpha: 0.35 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.8
        ..color = Colors.white.withValues(alpha: 0.95 * a),
    );
  }

  @override
  bool shouldRepaint(LightningPainter old) => old.t != t;
}

// ─── Butterflies ───────────────────────────────────────────────

/// One or two butterflies looping lazy figure-eights, wings flapping.
/// [flapCycles] is flaps per controller loop — keep it an integer and pick it
/// from the loop duration (aim for ~2–3 flaps per second).
class ButterfliesPainter extends CustomPainter {
  final double t;
  final int count;
  final int flapCycles;

  const ButterfliesPainter(this.t, {this.count = 2, this.flapCycles = 60});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(31);
    for (var i = 0; i < count; i++) {
      final cx = 0.30 + rng.nextDouble() * 0.40;
      final cy = 0.32 + rng.nextDouble() * 0.18;
      final ax = 0.20 + rng.nextDouble() * 0.14;
      final ay = 0.08 + rng.nextDouble() * 0.07;
      final fx = 2 + rng.nextInt(2);
      final fy = fx + 1;
      final px = rng.nextDouble();
      final py = rng.nextDouble();
      final pos = Offset(
        (cx + ax * math.sin(2 * math.pi * (t * fx + px))) * size.width,
        (cy + ay * math.sin(2 * math.pi * (t * fy + py))) * size.height,
      );
      // Bank into the direction of horizontal travel.
      final vx = math.cos(2 * math.pi * (t * fx + px));
      final flap =
          0.25 + 0.75 * math.sin(2 * math.pi * (t * flapCycles + px)).abs();
      final wing = Paint()
        ..color =
            (i.isEven ? const Color(0xFFF6A85C) : const Color(0xFFC9A0F0))
                .withValues(alpha: 0.9);
      final inner = Paint()..color = Colors.white.withValues(alpha: 0.45);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(-vx * 0.28);
      final w = 4.6 * flap;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(-w * 0.6, -0.5), width: w, height: 5.6),
        wing,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.6, -0.5), width: w, height: 5.6),
        wing,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-w * 0.5, 0),
          width: w * 0.45,
          height: 2.6,
        ),
        inner,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w * 0.5, 0),
          width: w * 0.45,
          height: 2.6,
        ),
        inner,
      );
      canvas.drawLine(
        const Offset(0, -2.6),
        const Offset(0, 2.8),
        Paint()
          ..color = const Color(0xFF5B4636)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ButterfliesPainter old) => old.t != t;
}

// ─── Sparkle burst ─────────────────────────────────────────────

/// One-shot radial celebration: sparkles + dots (and hearts when [hearts])
/// flung outward from the center, drifting down as they fade. Drive [p] with
/// a one-shot 0→1 controller; paints nothing at rest.
class SparkleBurstPainter extends CustomPainter {
  final double p;
  final int seed;
  final int count;
  final Color color;
  final Color accent;
  final bool hearts;

  const SparkleBurstPainter({
    required this.p,
    this.seed = 1,
    this.count = 16,
    this.color = const Color(0xFFFFD66B),
    this.accent = const Color(0xFFFF8FA3),
    this.hearts = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0.001 || p >= 0.999) return;
    final rng = math.Random(seed);
    final c = Offset(size.width / 2, size.height * 0.45);
    final maxR = size.shortestSide * 0.52;
    final ease = 1 - math.pow(1 - p, 3).toDouble();
    final a = (1 - p).clamp(0.0, 1.0);
    for (var i = 0; i < count; i++) {
      final ang = (i + rng.nextDouble() * 0.8) / count * 2 * math.pi;
      final dist = (0.4 + rng.nextDouble() * 0.6) * maxR;
      final spin = (rng.nextDouble() - 0.5) * 6;
      final kind = hearts ? i % 3 : i % 2; // 0 sparkle, 1 dot, 2 heart
      final pos = c +
          Offset(math.cos(ang), math.sin(ang)) * dist * ease +
          Offset(0, 26 * p * p); // a touch of gravity
      final s = (2.2 + rng.nextDouble() * 2.4) * (1 - 0.4 * p);
      if (kind == 0) {
        final stroke = Paint()
          ..color = color.withValues(alpha: a)
          ..strokeWidth = s * 0.55
          ..strokeCap = StrokeCap.round;
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(p * spin);
        canvas.drawLine(Offset(-s, 0), Offset(s, 0), stroke);
        canvas.drawLine(Offset(0, -s), Offset(0, s), stroke);
        canvas.restore();
      } else if (kind == 1) {
        canvas.drawCircle(
          pos,
          s * 0.5,
          Paint()..color = color.withValues(alpha: a),
        );
      } else {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(p * spin * 0.5);
        canvas.drawPath(
          _heart(s * 0.75),
          Paint()..color = accent.withValues(alpha: a),
        );
        canvas.restore();
      }
    }
  }

  static Path _heart(double s) {
    return Path()
      ..moveTo(0, s * 0.9)
      ..cubicTo(-1.4 * s, -0.1 * s, -0.55 * s, -1.05 * s, 0, -0.35 * s)
      ..cubicTo(0.55 * s, -1.05 * s, 1.4 * s, -0.1 * s, 0, s * 0.9);
  }

  @override
  bool shouldRepaint(SparkleBurstPainter old) =>
      old.p != p || old.seed != seed;
}

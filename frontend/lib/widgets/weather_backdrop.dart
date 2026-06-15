import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated, code-drawn **pixel-art** weather scene for the home header. No
/// asset files: everything (sun, moon, drifting clouds, rain, snow, stars,
/// lightning, fog) is painted by [_ScenePainter] as chunky squares snapped to
/// a fixed pixel grid, off a single repeating controller.
///
/// The scene is picked from the OpenWeather icon code ("10d", "01n", …) and
/// the background gradient from the local hour (dawn / day / sunset /
/// night), with the icon's d/n suffix taking priority.
class WeatherBackdrop extends StatefulWidget {
  final String iconCode;

  /// When true the animation controller is stopped (scene freezes on its
  /// current frame). The home screen pauses the backdrop once the header
  /// scrolls out of view so it stops burning frames.
  final bool paused;

  const WeatherBackdrop({
    super.key,
    required this.iconCode,
    this.paused = false,
  });

  /// Header gradient endpoints for the current time of day. The home screen
  /// uses the first color for its overscroll slab so pull-to-refresh blends in.
  static List<Color> gradientColors(String iconCode, [DateTime? when]) {
    final now = when ?? DateTime.now();
    final isNight = iconCode.endsWith('n');
    final h = now.hour;
    if (isNight || h < 5 || h >= 21) {
      // Night — deep indigo.
      return const [Color(0xFF2B3A67), Color(0xFF1B2845)];
    }
    if (h < 8) {
      // Dawn — peach into soft blue.
      return const [Color(0xFFFFB88C), Color(0xFF87A9D6)];
    }
    if (h < 17) {
      // Day — the existing sky blues.
      return const [Color(0xFF7EC0EE), Color(0xFF4F9FD9)];
    }
    // Sunset (17–21) — amber into dusk violet.
    return const [Color(0xFFF2A65A), Color(0xFF6C5B9C)];
  }

  /// The sky as discrete horizontal colour bands (no smooth blend), for a
  /// stepped 8-bit look. Built off [gradientColors].
  static LinearGradient skyGradient(String iconCode, [DateTime? when]) {
    final ends = gradientColors(iconCode, when);
    const bands = 7;
    final colors = <Color>[];
    final stops = <double>[];
    for (int i = 0; i < bands; i++) {
      final c = Color.lerp(ends.first, ends.last, i / (bands - 1))!;
      colors..add(c)..add(c);
      stops..add(i / bands)..add((i + 1) / bands);
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    );
  }

  @override
  State<WeatherBackdrop> createState() => _WeatherBackdropState();
}

class _WeatherBackdropState extends State<WeatherBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    if (!widget.paused) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant WeatherBackdrop old) {
    super.didUpdateWidget(old);
    if (widget.paused != old.paused) {
      widget.paused ? _controller.stop() : _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          // RepaintBoundary keeps the per-frame repaint inside this layer,
          // so the header text/stats above don't re-rasterize 60×/sec.
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _ScenePainter(
                  iconCode: widget.iconCode,
                  t: _controller.value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final String iconCode;
  final double t; // 0..1, loops every 24s

  _ScenePainter({required this.iconCode, required this.t});

  /// Size of one painted "pixel". Everything snaps to this grid.
  static const double px = 6;

  String get _group => iconCode.length >= 2 ? iconCode.substring(0, 2) : '01';
  bool get _isNight => iconCode.endsWith('n');

  // Fixed seeds so particles don't jump between frames.
  static final _rng = math.Random(7);
  static final List<Offset> _starSeeds =
      List.generate(26, (_) => Offset(_rng.nextDouble(), _rng.nextDouble()));
  static final List<double> _starPhases =
      List.generate(26, (_) => _rng.nextDouble());
  static final List<Offset> _dropSeeds =
      List.generate(40, (_) => Offset(_rng.nextDouble(), _rng.nextDouble()));
  static final List<Offset> _flakeSeeds =
      List.generate(28, (_) => Offset(_rng.nextDouble(), _rng.nextDouble()));
  static final List<double> _cloudYs =
      List.generate(4, (_) => 0.10 + _rng.nextDouble() * 0.32);
  static final List<double> _cloudOffsets =
      List.generate(4, (_) => _rng.nextDouble());
  static final List<double> _cloudScales =
      List.generate(4, (_) => 0.8 + _rng.nextDouble() * 0.6);

  // ── Grid helpers ──────────────────────────────────────────────────────
  double _snap(double v) => (v / px).floorToDouble() * px;

  /// Draw one grid-aligned square at (x, y) in pixel coordinates.
  void _cell(Canvas c, double x, double y, Paint p, [double span = 1]) {
    c.drawRect(Rect.fromLTWH(_snap(x), _snap(y), px * span, px * span), p);
  }

  /// Fill a disc with grid cells. Optionally cut a [biteCenter]/[biteR]
  /// crescent out (for the moon).
  void _pixelDisc(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    Offset? biteCenter,
    double biteR = 0,
  }) {
    for (double y = center.dy - radius; y <= center.dy + radius; y += px) {
      for (double x = center.dx - radius; x <= center.dx + radius; x += px) {
        final cc = Offset(x + px / 2, y + px / 2);
        if ((cc - center).distance > radius) continue;
        if (biteCenter != null && (cc - biteCenter).distance <= biteR) {
          continue;
        }
        _cell(canvas, x, y, paint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (_group) {
      case '01': // clear
        _isNight ? _paintNightSky(canvas, size) : _paintSun(canvas, size);
      case '02': // few clouds
        _isNight ? _paintNightSky(canvas, size) : _paintSun(canvas, size);
        _paintClouds(canvas, size, count: 2, alpha: 0.85);
      case '03':
      case '04': // clouds
        if (_isNight) _paintNightSky(canvas, size, starsOnly: true);
        _paintClouds(canvas, size, count: 4, alpha: 0.92);
      case '09':
      case '10': // rain
        _paintClouds(canvas, size, count: 3, alpha: 0.9);
        _paintRain(canvas, size);
      case '11': // thunder
        _paintClouds(canvas, size, count: 4, alpha: 0.95);
        _paintRain(canvas, size);
        _paintLightning(canvas, size);
      case '13': // snow
        if (_isNight) _paintNightSky(canvas, size, starsOnly: true);
        _paintClouds(canvas, size, count: 2, alpha: 0.85);
        _paintSnow(canvas, size);
      case '50': // fog
        _paintFog(canvas, size);
      default:
        _paintClouds(canvas, size, count: 3, alpha: 0.85);
    }
  }

  // ── Sun: blocky disc + flashing pixel rays, top-right. ──
  void _paintSun(Canvas canvas, Size size) {
    final center = Offset(_snap(size.width * 0.82), _snap(size.height * 0.26));
    final r = _snap(size.width * 0.075);

    // Rays: short pixel stubs in 8 directions, the diagonals blinking on the
    // alternate beat for a twinkly arcade sun.
    final rayPaint = Paint()..color = const Color(0xFFFFE082);
    final blink = (t * 4).floor().isEven;
    for (int i = 0; i < 8; i++) {
      final diagonal = i.isOdd;
      if (diagonal && !blink) continue;
      if (!diagonal && blink) continue;
      final a = i * math.pi / 4;
      for (int s = 0; s < 2; s++) {
        final dist = r + px * (2 + s);
        final p = center + Offset(math.cos(a), math.sin(a)) * dist;
        _cell(canvas, p.dx - px / 2, p.dy - px / 2, rayPaint);
      }
    }

    _pixelDisc(canvas, center, r * 1.18,
        Paint()..color = const Color(0xFFFFD54F));
    _pixelDisc(canvas, center, r, Paint()..color = const Color(0xFFFFF3C4));
  }

  // ── Moon + twinkling pixel stars. ──
  void _paintNightSky(Canvas canvas, Size size, {bool starsOnly = false}) {
    final starPaint = Paint();
    for (int i = 0; i < _starSeeds.length; i++) {
      final s = _starSeeds[i];
      // Twinkle = on/off, not a fade, so stars stay crisp pixels.
      final on = math.sin((t * 6 + _starPhases[i]) * 2 * math.pi) > -0.3;
      if (!on) continue;
      final pos = Offset(s.dx * size.width, s.dy * size.height * 0.55);
      starPaint.color = Colors.white.withValues(alpha: 0.9);
      _cell(canvas, pos.dx, pos.dy, starPaint, i % 6 == 0 ? 2 : 1);
    }
    if (starsOnly) return;

    final center = Offset(_snap(size.width * 0.82), _snap(size.height * 0.26));
    final r = _snap(size.width * 0.075);
    _pixelDisc(
      canvas,
      center,
      r,
      Paint()..color = const Color(0xFFF6F1DE),
      biteCenter: center + Offset(r * 0.55, -r * 0.2),
      biteR: r * 0.95,
    );
  }

  // ── Drifting pixel clouds, each from a small bitmap pattern. ──
  static const List<String> _cloudBitmap = [
    '..####..',
    '.######.',
    '########',
    '.######.',
  ];

  void _paintClouds(Canvas canvas, Size size,
      {required int count, required double alpha}) {
    final fill = Paint()..color = Colors.white.withValues(alpha: alpha);
    final edge = Paint()
      ..color = const Color(0xFFB8C6D9).withValues(alpha: alpha);
    for (int i = 0; i < count && i < _cloudYs.length; i++) {
      final scale = _cloudScales[i];
      final cell = px * (1.8 * scale).clamp(1.2, 2.4);
      final w = cell * _cloudBitmap.first.length;
      final speed = 0.5 + 0.4 * (1 - scale);
      final baseX = ((t * speed + _cloudOffsets[i]) % 1.3) * (size.width + w) - w;
      final baseY = size.height * _cloudYs[i];
      for (int row = 0; row < _cloudBitmap.length; row++) {
        final line = _cloudBitmap[row];
        for (int col = 0; col < line.length; col++) {
          if (line[col] != '#') continue;
          final x = _snap(baseX + col * cell);
          final y = _snap(baseY + row * cell);
          // Bottom row drawn a touch darker to fake a shaded underside.
          canvas.drawRect(
            Rect.fromLTWH(x, y, cell, cell),
            row == _cloudBitmap.length - 1 ? edge : fill,
          );
        }
      }
    }
  }

  // ── Falling pixel rain: 1-wide, 2-tall dashes. ──
  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFBFE2FF).withValues(alpha: 0.8);
    for (final seed in _dropSeeds) {
      final fall = (t * 6 + seed.dy) % 1.0;
      final x = seed.dx * size.width;
      final y = fall * (size.height + 24) - 12;
      canvas.drawRect(Rect.fromLTWH(_snap(x), _snap(y), px, px * 2), paint);
    }
  }

  // ── Snow: single pixels with a gentle sway. ──
  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    for (int i = 0; i < _flakeSeeds.length; i++) {
      final seed = _flakeSeeds[i];
      final fall = (t * 2.5 + seed.dy) % 1.0;
      final sway = math.sin((t * 4 + seed.dx) * 2 * math.pi) * px * 2;
      final x = seed.dx * size.width + sway;
      final y = fall * (size.height + 12) - 6;
      _cell(canvas, x, y, paint, i % 4 == 0 ? 2 : 1);
    }
  }

  // ── Blocky lightning bolt + flash. ──
  void _paintLightning(Canvas canvas, Size size) {
    final phase = (t * 2) % 1.0;
    if (phase > 0.1) return;
    final intensity = 1 - (phase / 0.1);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.25 * intensity),
    );

    final bolt = Paint()..color = const Color(0xFFFFF59D);
    // A staircase of cells zig-zagging down.
    final x0 = _snap(size.width * 0.34);
    final y0 = _snap(size.height * 0.16);
    final steps = <Offset>[
      Offset(x0, y0),
      Offset(x0 - px, y0 + px * 2),
      Offset(x0 - px * 2, y0 + px * 4),
      Offset(x0, y0 + px * 4),
      Offset(x0 - px, y0 + px * 6),
      Offset(x0 - px * 2, y0 + px * 8),
    ];
    for (final p in steps) {
      _cell(canvas, p.dx, p.dy, bolt);
    }
  }

  // ── Drifting fog bands (rows of low-alpha cells). ──
  void _paintFog(Canvas canvas, Size size) {
    for (int i = 0; i < 4; i++) {
      final y = size.height * (0.22 + i * 0.16);
      final drift = math.sin((t + i * 0.25) * 2 * math.pi) * size.width * 0.08;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.18 + (i % 2) * 0.08);
      for (double x = -px * 2; x < size.width + px * 2; x += px * 2) {
        // Skip some cells for a dithered, see-through band.
        if (((x / (px * 2)).floor() + i) % 3 == 0) continue;
        _cell(canvas, x + drift, y, paint, 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.t != t || old.iconCode != iconCode;
}

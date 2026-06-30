import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated, code-drawn weather scene for the home header. No asset files:
/// everything (sun rays, drifting clouds, rain, snow, lightning, stars,
/// fog) is painted by [_ScenePainter] off a single repeating controller.
///
/// The scene is picked from the OpenWeather icon code ("10d", "01n", …) and
/// the background gradient from the local hour (dawn / day / sunset /
/// night), with the icon's d/n suffix taking priority so the scene always
/// matches what the weather API says the sky is doing.
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

  /// Header gradient for the current time of day. The home screen also uses
  /// the first color for its overscroll slab so pull-to-refresh blends in.
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

  String get _group => iconCode.length >= 2 ? iconCode.substring(0, 2) : '01';
  bool get _isNight => iconCode.endsWith('n');

  // Fixed seed so particles don't jump between frames.
  static final _rng = math.Random(7);
  static final List<Offset> _starSeeds = List.generate(
    26,
    (_) => Offset(_rng.nextDouble(), _rng.nextDouble()),
  );
  static final List<double> _starPhases = List.generate(
    26,
    (_) => _rng.nextDouble(),
  );
  static final List<Offset> _dropSeeds = List.generate(
    42,
    (_) => Offset(_rng.nextDouble(), _rng.nextDouble()),
  );
  static final List<Offset> _flakeSeeds = List.generate(
    30,
    (_) => Offset(_rng.nextDouble(), _rng.nextDouble()),
  );
  static final List<double> _cloudYs = List.generate(
    4,
    (_) => 0.08 + _rng.nextDouble() * 0.35,
  );
  static final List<double> _cloudOffsets = List.generate(
    4,
    (_) => _rng.nextDouble(),
  );
  static final List<double> _cloudScales = List.generate(
    4,
    (_) => 0.7 + _rng.nextDouble() * 0.6,
  );

  @override
  void paint(Canvas canvas, Size size) {
    switch (_group) {
      case '01': // clear
        _isNight ? _paintNightSky(canvas, size) : _paintSun(canvas, size);
      case '02': // few clouds
        if (_isNight) {
          _paintNightSky(canvas, size);
        } else {
          _paintSun(canvas, size);
        }
        _paintClouds(canvas, size, count: 2, alpha: 0.5);
      case '03':
      case '04': // clouds
        if (_isNight) _paintNightSky(canvas, size, starsOnly: true);
        _paintClouds(canvas, size, count: 4, alpha: 0.6);
      case '09':
      case '10': // rain
        _paintClouds(canvas, size, count: 3, alpha: 0.55);
        _paintRain(canvas, size);
      case '11': // thunder
        _paintClouds(canvas, size, count: 4, alpha: 0.65);
        _paintRain(canvas, size);
        _paintLightning(canvas, size);
      case '13': // snow
        if (_isNight) _paintNightSky(canvas, size, starsOnly: true);
        _paintClouds(canvas, size, count: 2, alpha: 0.45);
        _paintSnow(canvas, size);
      case '50': // fog
        _paintFog(canvas, size);
      default:
        _paintClouds(canvas, size, count: 3, alpha: 0.5);
    }
  }

  // ── Sun: glowing disc + slowly rotating rays, top-right. ──
  void _paintSun(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.82, size.height * 0.24);
    final r = size.width * 0.085;

    final glow = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9);
    canvas.drawCircle(center, r * 1.7, glow);

    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final angle0 = t * 2 * math.pi * 0.5; // half a turn per loop
    for (int i = 0; i < 8; i++) {
      final a = angle0 + i * math.pi / 4;
      final from = center + Offset(math.cos(a), math.sin(a)) * (r * 1.45);
      final to = center + Offset(math.cos(a), math.sin(a)) * (r * 1.95);
      canvas.drawLine(from, to, rayPaint);
    }

    final body = Paint()..color = const Color(0xFFFFF3C4);
    canvas.drawCircle(center, r, body);
  }

  // ── Moon + twinkling stars. ──
  void _paintNightSky(Canvas canvas, Size size, {bool starsOnly = false}) {
    final starPaint = Paint();
    for (int i = 0; i < _starSeeds.length; i++) {
      final s = _starSeeds[i];
      // Stars stay in the top ~55% of the header.
      final pos = Offset(s.dx * size.width, s.dy * size.height * 0.55);
      final twinkle =
          0.35 +
          0.65 * (0.5 + 0.5 * math.sin((t * 6 + _starPhases[i]) * 2 * math.pi));
      starPaint.color = Colors.white.withValues(alpha: 0.75 * twinkle);
      canvas.drawCircle(pos, i % 5 == 0 ? 1.8 : 1.1, starPaint);
    }
    if (starsOnly) return;

    final center = Offset(size.width * 0.82, size.height * 0.24);
    final r = size.width * 0.07;
    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8);
    canvas.drawCircle(center, r * 1.5, glow);

    // Crescent: full disc minus an offset shadow disc.
    final moon = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: center + Offset(r * 0.42, -r * 0.18),
          radius: r * 0.88,
        ),
      );
    final crescent = Path.combine(PathOperation.difference, moon, bite);
    canvas.drawPath(crescent, Paint()..color = const Color(0xFFF6F1DE));
  }

  // ── Drifting stylized clouds. Each cloud is ONE path (pill base + two
  // bumps) filled in a single pass, so the translucent white stays uniform
  // with no darker overlap seams — clean flat-design look.
  void _paintClouds(
    Canvas canvas,
    Size size, {
    required int count,
    required double alpha,
  }) {
    final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
    for (int i = 0; i < count && i < _cloudYs.length; i++) {
      final scale = _cloudScales[i];
      final w = size.width * 0.32 * scale;
      final h = w * 0.30;
      // Each cloud loops at its own speed; widest drift slowest.
      final speed = 0.5 + 0.4 * (1 - scale);
      final x = ((t * speed + _cloudOffsets[i]) % 1.3) * (size.width + w) - w;
      final y = size.height * _cloudYs[i];
      final cloud = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, y + h * 0.30),
              width: w,
              height: h,
            ),
            Radius.circular(h / 2),
          ),
        )
        ..addOval(
          Rect.fromCircle(
            center: Offset(x - w * 0.16, y - h * 0.02),
            radius: h * 0.52,
          ),
        )
        ..addOval(
          Rect.fromCircle(
            center: Offset(x + w * 0.14, y - h * 0.22),
            radius: h * 0.70,
          ),
        );
      canvas.drawPath(cloud, paint);
    }
  }

  // ── Falling rain streaks. ──
  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const slant = 0.18; // slight wind
    for (final seed in _dropSeeds) {
      // Drops cycle fast: 6 falls per loop, staggered by seed.dy.
      final fall = ((t * 6 + seed.dy) % 1.0);
      final x = seed.dx * size.width + fall * size.height * slant;
      final y = fall * (size.height + 20) - 10;
      canvas.drawLine(Offset(x, y), Offset(x + 2.4, y + 11), paint);
    }
  }

  // ── Snowflakes with sideways sway. ──
  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (int i = 0; i < _flakeSeeds.length; i++) {
      final seed = _flakeSeeds[i];
      final fall = ((t * 2.5 + seed.dy) % 1.0);
      final sway = math.sin((t * 4 + seed.dx) * 2 * math.pi) * 10;
      final x = seed.dx * size.width + sway;
      final y = fall * (size.height + 12) - 6;
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 2.6 : 1.7, paint);
    }
  }

  // ── Occasional lightning flash + bolt. ──
  void _paintLightning(Canvas canvas, Size size) {
    // Two flashes per loop, each lasting ~4% of the cycle.
    final phase = (t * 2) % 1.0;
    if (phase > 0.08) return;
    final intensity = 1 - (phase / 0.08);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.22 * intensity),
    );

    final boltPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * intensity)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x0 = size.width * 0.32;
    final y0 = size.height * 0.18;
    final bolt = Path()
      ..moveTo(x0, y0)
      ..lineTo(x0 - size.width * 0.03, y0 + size.height * 0.16)
      ..lineTo(x0 + size.width * 0.015, y0 + size.height * 0.17)
      ..lineTo(x0 - size.width * 0.025, y0 + size.height * 0.34);
    canvas.drawPath(bolt, boltPaint);
  }

  // ── Drifting fog bands. ──
  void _paintFog(Canvas canvas, Size size) {
    for (int i = 0; i < 4; i++) {
      final y = size.height * (0.2 + i * 0.18);
      final w = size.width * 1.1;
      final drift = math.sin((t + i * 0.25) * 2 * math.pi) * size.width * 0.06;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.16 + (i % 2) * 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2 + drift, y),
            width: w,
            height: size.height * 0.1,
          ),
          const Radius.circular(40),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.t != t || old.iconCode != iconCode;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'scene_effects.dart';

/// Loads a weather-scene asset, auto-picking the loader by file extension so
/// the SVGs can be swapped for your own `.png` / `.jpg` / `.webp` art just by
/// dropping a file with the matching name into `assets/weather/`.
Widget _sceneAsset(String path, {BoxFit? fit, double? width, double? height}) {
  if (path.toLowerCase().endsWith('.svg')) {
    return SvgPicture.asset(
      path,
      fit: fit ?? BoxFit.contain,
      width: width,
      height: height,
    );
  }
  return Image.asset(
    path,
    fit: fit ?? BoxFit.contain,
    width: width,
    height: height,
  );
}

/// Watercolor / art-style weather scene for the home header, composited from
/// the hand-painted SVGs in `assets/weather/`.
///
/// Layers, back to front: a full-bleed sky wash (picked by local time of day),
/// a star field on clear/cloudy nights, the sun or crescent moon top-right,
/// drifting clouds, and rain/snow when it's wet out. The scene is
/// chosen from the OpenWeather icon code ("10d", "01n", …) just like the old
/// code-drawn [WeatherBackdrop] it replaces.
class WeatherSceneArt extends StatefulWidget {
  final String iconCode;
  final double rainIntensity;
  final double celestialScale;
  final double celestialRightFraction;
  final double celestialTopFraction;
  final double celestialOpacity;
  final double sunRaysOpacity;

  /// When true the drift animation is stopped (scene freezes). The home screen
  /// pauses the scene once the header scrolls out of view to save frames.
  final bool paused;

  const WeatherSceneArt({
    super.key,
    required this.iconCode,
    this.rainIntensity = 1.0,
    this.paused = false,
    this.celestialScale = 1.0,
    this.celestialRightFraction = 0.06,
    this.celestialTopFraction = 0.06,
    this.celestialOpacity = 1.0,
    this.sunRaysOpacity = 1.0,
  });

  static const _base = 'assets/weather';

  /// Sky wash asset for the current time of day, nudged by the icon's day/night
  /// suffix. Mirrors [WeatherBackdrop.gradientColors] buckets so the static
  /// sky and the header gradient stay in sync.
  static String skyAsset(String iconCode, [DateTime? when]) {
    final now = when ?? DateTime.now();
    final isNight = iconCode.endsWith('n');
    final group = iconCode.length >= 2 ? iconCode.substring(0, 2) : '01';
    final h = now.hour;
    if (isNight || h < 5 || h >= 21) return '$_base/${_A.skyNight}';
    if (group == '09' || group == '10' || group == '11') {
      return '$_base/${_A.skyRain}';
    }
    if (h < 8) return '$_base/${_A.skyDawn}';
    if (h < 17) return '$_base/${_A.skyDay}';
    return '$_base/${_A.skySunset}';
  }

  @override
  State<WeatherSceneArt> createState() => _WeatherSceneArtState();
}

class _WeatherSceneArtState extends State<WeatherSceneArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );
    if (!widget.paused) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant WeatherSceneArt old) {
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

  String get _group =>
      widget.iconCode.length >= 2 ? widget.iconCode.substring(0, 2) : '01';
  bool get _isNight {
    final h = DateTime.now().hour;
    return widget.iconCode.endsWith('n') || h < 5 || h >= 21;
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _SceneConfig.forGroup(_group, _isNight);
    // Extra ambient life on clear-ish scenes: motes + birds by day,
    // fireflies (and, fully clear, shooting stars) by night.
    final clearish = _group == '01' || _group == '02';
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;
                final celestialSize = w * 0.30 * widget.celestialScale;
                final raySize = w * 0.58 * widget.celestialScale;
                final celestialRight = w * widget.celestialRightFraction;
                final celestialTop = h * widget.celestialTopFraction;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Sky wash.
                    _sceneAsset(
                      WeatherSceneArt.skyAsset(widget.iconCode),
                      fit: BoxFit.cover,
                    ),
                    // Stars on clear / cloudy nights, with a slow twinkle.
                    if (cfg.stars)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: h * 0.62,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) => Opacity(
                            opacity:
                                0.72 +
                                0.28 *
                                    (0.5 +
                                        0.5 *
                                            math.sin(
                                              _controller.value *
                                                  2 *
                                                  math.pi *
                                                  5,
                                            )),
                            child: child,
                          ),
                          child: _sceneAsset(
                            '${WeatherSceneArt._base}/${_A.stars}',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    // Meteor streaks on fully clear nights.
                    if (cfg.stars && _group == '01')
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CustomPaint(
                          painter: ShootingStarsPainter(_controller.value),
                        ),
                      ),
                    // Rotating soft rays behind the daytime sun.
                    if (cfg.celestial != null && !_isNight)
                      Positioned(
                        right: celestialRight + celestialSize / 2 - raySize / 2,
                        top: celestialTop + celestialSize / 2 - raySize / 2,
                        width: raySize,
                        height: raySize,
                        child: Opacity(
                          opacity: widget.sunRaysOpacity,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) => CustomPaint(
                              painter: SunRaysPainter(_controller.value),
                            ),
                          ),
                        ),
                      ),
                    // Sun or moon, top-right — gently pulsing and bobbing.
                    if (cfg.celestial != null)
                      Positioned(
                        right: celestialRight,
                        top: celestialTop,
                        width: celestialSize,
                        height: celestialSize,
                        child: Opacity(
                          opacity: widget.celestialOpacity,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final t = _controller.value;
                              return Transform.translate(
                                offset: Offset(
                                  0,
                                  3 * math.sin(t * 2 * math.pi * 2),
                                ),
                                child: Transform.scale(
                                  scale:
                                      1 + 0.035 * math.sin(t * 2 * math.pi * 4),
                                  child: child,
                                ),
                              );
                            },
                            child: _sceneAsset(cfg.celestial!),
                          ),
                        ),
                      ),
                    // Sunlit pollen motes drifting up on gentle days.
                    if (clearish && !_isNight)
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CustomPaint(
                          painter: MotesPainter(_controller.value),
                        ),
                      ),
                    // Drifting clouds.
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          for (final cl in cfg.clouds)
                            _drift(cl, w, h, _controller.value),
                        ],
                      ),
                    ),
                    // A flock crossing the sky on clear-ish days; fireflies
                    // wandering low on clear-ish nights.
                    if (clearish)
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CustomPaint(
                          painter: _isNight
                              ? FirefliesPainter(_controller.value, count: 7)
                              : BirdsPainter(_controller.value),
                        ),
                      ),
                    // Rain / snow, code-drawn with parallax depth.
                    if (cfg.precip != null)
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => IgnorePointer(
                          child: CustomPaint(
                            painter: cfg.precip == _A.rain
                                ? AmbientRainPainter(
                                    _controller.value,
                                    widget.rainIntensity,
                                  )
                                : SnowPainter(_controller.value),
                          ),
                        ),
                      ),
                    // Thunderstorm: sky flash + jagged bolts a few times per
                    // drift cycle (a double-strike and a single).
                    if (cfg.lightning)
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => IgnorePointer(
                          child: CustomPaint(
                            painter: LightningPainter(_controller.value),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Positions one cloud, looping it left→right across the header with a
  /// slight vertical bob so the drift doesn't read as a flat slide.
  Widget _drift(_Cloud cl, double w, double h, double t) {
    final cloudW = w * cl.scale;
    final span = w + cloudW;
    final x = ((t * cl.speed + cl.phase) % 1.2) * span - cloudW;
    final bob = 3.0 * math.sin(2 * math.pi * (t * 2 + cl.phase));
    return Positioned(
      left: x,
      top: h * cl.y + bob,
      width: cloudW,
      child: Opacity(
        opacity: cl.opacity,
        child: _sceneAsset(
          '${WeatherSceneArt._base}/${cl.asset}',
          fit: BoxFit.fitWidth,
        ),
      ),
    );
  }
}

/// One drifting cloud instance.
class _Cloud {
  final String asset;
  final double y; // top, fraction of header height
  final double scale; // width, fraction of header width
  final double phase; // 0..1 start offset along the loop
  final double speed; // loops per controller cycle
  final double opacity;
  const _Cloud(
    this.asset,
    this.y,
    this.scale,
    this.phase,
    this.speed, [
    this.opacity = 1,
  ]);
}

/// Resolved per-condition layer set.
class _SceneConfig {
  final String? celestial; // sun / moon asset, or null
  final bool stars;
  final List<_Cloud> clouds;
  final String? precip; // 'rain.svg' / 'snow.svg' / null
  final bool lightning; // thunderstorm flash overlay

  const _SceneConfig({
    this.celestial,
    this.stars = false,
    this.clouds = const [],
    this.precip,
    this.lightning = false,
  });

  static const _sun = '${WeatherSceneArt._base}/${_A.sun}';
  static const _moon = '${WeatherSceneArt._base}/${_A.moon}';

  factory _SceneConfig.forGroup(String group, bool isNight) {
    final body = isNight ? _moon : _sun;
    switch (group) {
      case '01': // clear
        return _SceneConfig(celestial: body, stars: isNight);
      case '02': // few clouds
        return _SceneConfig(
          celestial: body,
          stars: isNight,
          clouds: const [
            _Cloud(_A.cloudSoft, 0.30, 0.42, 0.10, 0.5, 0.9),
            _Cloud(_A.cloudBig, 0.46, 0.52, 0.60, 0.35, 0.8),
          ],
        );
      case '03': // scattered
      case '04': // broken / overcast
        return _SceneConfig(
          stars: isNight,
          clouds: const [
            _Cloud(_A.cloudBig, 0.16, 0.58, 0.05, 0.32, 0.95),
            _Cloud(_A.cloudSoft, 0.34, 0.46, 0.45, 0.48, 0.9),
            _Cloud(_A.cloudGrey, 0.28, 0.55, 0.80, 0.4, 0.85),
          ],
        );
      case '09': // shower
      case '10': // rain
        return _SceneConfig(
          clouds: const [
            _Cloud(_A.cloudGrey, 0.18, 0.52, 0.1, 0.3, 0.76),
            _Cloud(_A.cloudGrey, 0.36, 0.44, 0.6, 0.42, 0.70),
          ],
          precip: _A.rain,
        );
      case '11': // thunderstorm
        return _SceneConfig(
          clouds: const [
            _Cloud(_A.cloudGrey, 0.17, 0.58, 0.05, 0.28, 0.82),
            _Cloud(_A.cloudGrey, 0.37, 0.48, 0.55, 0.4, 0.74),
          ],
          precip: _A.rain,
          lightning: true,
        );
      case '13': // snow
        return _SceneConfig(
          stars: isNight,
          clouds: const [
            _Cloud(_A.cloudSoft, 0.14, 0.58, 0.1, 0.3, 0.95),
            _Cloud(_A.cloudGrey, 0.30, 0.5, 0.6, 0.42, 0.8),
          ],
          precip: _A.snow,
        );
      case '50': // mist / fog
        return _SceneConfig(
          clouds: const [
            _Cloud(_A.cloudSoft, 0.22, 0.7, 0.0, 0.22, 0.6),
            _Cloud(_A.cloudSoft, 0.40, 0.8, 0.5, 0.18, 0.5),
            _Cloud(_A.cloudSoft, 0.58, 0.75, 0.25, 0.2, 0.45),
          ],
        );
      default:
        return _SceneConfig(
          celestial: body,
          stars: isNight,
          clouds: const [_Cloud(_A.cloudSoft, 0.30, 0.45, 0.2, 0.4, 0.85)],
        );
    }
  }
}

/// Every weather-scene filename in one place. To use your own art, drop a file
/// into `assets/weather/` and point the matching entry at it — keep the `.svg`
/// name to reuse the loader as-is, or switch the extension to `.png` / `.jpg` /
/// `.webp` and `_sceneAsset` picks the right loader automatically. Filenames
/// are relative to `assets/weather/`.
class _A {
  static const skyDawn = 'sky_dawn.svg';
  static const skyDay = 'sky_day.svg';
  static const skyRain = 'sky_rain.svg';
  static const skySunset = 'sky_sunset.svg';
  static const skyNight = 'sky_night.svg';
  static const sun = 'sun.svg';
  static const moon = 'moon.svg';
  static const stars = 'stars.svg';
  static const cloudSoft = 'cloud_soft.svg';
  static const cloudBig = 'cloud_big.svg';
  static const cloudGrey = 'cloud_grey.svg';
  static const rain = 'rain.svg';
  static const snow = 'snow.svg';
}

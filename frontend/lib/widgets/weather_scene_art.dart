import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Loads a weather-scene asset, auto-picking the loader by file extension so
/// the SVGs can be swapped for your own `.png` / `.jpg` / `.webp` art just by
/// dropping a file with the matching name into `assets/weather/`.
Widget _sceneAsset(String path, {BoxFit? fit, double? width, double? height}) {
  if (path.toLowerCase().endsWith('.svg')) {
    return SvgPicture.asset(path, fit: fit ?? BoxFit.contain,
        width: width, height: height);
  }
  return Image.asset(path,
      fit: fit ?? BoxFit.contain, width: width, height: height);
}

/// Watercolor / art-style weather scene for the home header, composited from
/// the hand-painted SVGs in `assets/weather/`.
///
/// Layers, back to front: a full-bleed sky wash (picked by local time of day),
/// a star field on clear/cloudy nights, the sun or crescent moon top-right,
/// drifting clouds, and a rain/snow texture when it's wet out. The scene is
/// chosen from the OpenWeather icon code ("10d", "01n", …) just like the old
/// code-drawn [WeatherBackdrop] it replaces.
class WeatherSceneArt extends StatefulWidget {
  final String iconCode;

  /// When true the drift animation is stopped (scene freezes). The home screen
  /// pauses the scene once the header scrolls out of view to save frames.
  final bool paused;

  const WeatherSceneArt({
    super.key,
    required this.iconCode,
    this.paused = false,
  });

  static const _base = 'assets/weather';

  /// Sky wash asset for the current time of day, nudged by the icon's day/night
  /// suffix. Mirrors [WeatherBackdrop.gradientColors] buckets so the static
  /// sky and the header gradient stay in sync.
  static String skyAsset(String iconCode, [DateTime? when]) {
    final now = when ?? DateTime.now();
    final isNight = iconCode.endsWith('n');
    final h = now.hour;
    if (isNight || h < 5 || h >= 21) return '$_base/${_A.skyNight}';
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
  bool get _isNight => widget.iconCode.endsWith('n');

  @override
  Widget build(BuildContext context) {
    final cfg = _SceneConfig.forGroup(_group, _isNight);
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Sky wash.
                    _sceneAsset(
                      WeatherSceneArt.skyAsset(widget.iconCode),
                      fit: BoxFit.cover,
                    ),
                    // Stars on clear / cloudy nights.
                    if (cfg.stars)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: h * 0.62,
                        child: _sceneAsset(
                          '${WeatherSceneArt._base}/${_A.stars}',
                          fit: BoxFit.cover,
                        ),
                      ),
                    // Sun or moon, top-right.
                    if (cfg.celestial != null)
                      Positioned(
                        right: w * 0.06,
                        top: h * 0.06,
                        width: w * 0.30,
                        height: w * 0.30,
                        child: _sceneAsset(cfg.celestial!),
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
                    // Rain / snow.
                    if (cfg.precip != null)
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => _PrecipLayer(
                          asset: '${WeatherSceneArt._base}/${cfg.precip}',
                          t: _controller.value,
                          slow: cfg.precip == _A.snow,
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

  /// Positions one cloud, looping it left→right across the header.
  Widget _drift(_Cloud cl, double w, double h, double t) {
    final cloudW = w * cl.scale;
    final span = w + cloudW;
    final x = ((t * cl.speed + cl.phase) % 1.2) * span - cloudW;
    return Positioned(
      left: x,
      top: h * cl.y,
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
  const _Cloud(this.asset, this.y, this.scale, this.phase, this.speed,
      [this.opacity = 1]);
}

/// Resolved per-condition layer set.
class _SceneConfig {
  final String? celestial; // sun / moon asset, or null
  final bool stars;
  final List<_Cloud> clouds;
  final String? precip; // 'rain.svg' / 'snow.svg' / null

  const _SceneConfig({
    this.celestial,
    this.stars = false,
    this.clouds = const [],
    this.precip,
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
            _Cloud(_A.cloudGrey, 0.14, 0.6, 0.1, 0.3, 0.95),
            _Cloud(_A.cloudGrey, 0.30, 0.5, 0.6, 0.42, 0.85),
          ],
          precip: _A.rain,
        );
      case '11': // thunderstorm
        return _SceneConfig(
          clouds: const [
            _Cloud(_A.cloudGrey, 0.12, 0.66, 0.05, 0.28, 1.0),
            _Cloud(_A.cloudGrey, 0.30, 0.54, 0.55, 0.4, 0.9),
          ],
          precip: _A.rain,
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
          clouds: const [
            _Cloud(_A.cloudSoft, 0.30, 0.45, 0.2, 0.4, 0.85),
          ],
        );
    }
  }
}

/// Tiles a precipitation texture across the section and scrolls it downward.
class _PrecipLayer extends StatelessWidget {
  final String asset;
  final double t;
  final bool slow;

  const _PrecipLayer({required this.asset, required this.t, this.slow = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const tile = 120.0;
        final cols = (c.maxWidth / tile).ceil() + 1;
        final rows = (c.maxHeight / tile).ceil() + 2;
        // Scroll one tile-height per (slow) loop, wrapping seamlessly.
        final cycles = slow ? 3.0 : 8.0;
        final dy = ((t * cycles) % 1.0) * tile;
        return ClipRect(
          child: Transform.translate(
            offset: Offset(0, dy - tile),
            child: OverflowBox(
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: double.infinity,
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int r = 0; r < rows; r++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int col = 0; col < cols; col++)
                          _sceneAsset(asset, width: tile, height: tile),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/plant_stage.dart';
import 'pot.dart';
import 'scene_effects.dart';

/// Layered, per-part animated streak plant for the Tasks page.
///
/// Each growth stage is composed from separate SVG layers in
/// `assets/plant_stages/` so they can move independently, planted in a
/// code-drawn pot (see `pot.dart`; the style is a shop cosmetic):
///
///   pot back/soil (static) → sprout_stem → `stage` body (+head leaves,
///   face) → `stage_sideL` / `stage_sideR` leaves → pot front (static)
///
/// The pot never moves. The body does a gentle idle sway + breathe that
/// *rests* between bursts (a cooldown, so it isn't constantly wobbling), the
/// side leaves flutter up/down pivoting on their base near the soil, and the
/// sprout's single leaf sways on its stem. `seed` is fully still; `sprout`
/// only moves its stem/leaf. Open dot-eyed stages also blink.
///
/// Splitting keeps each layer on the same `0 0 100 100` canvas, so the
/// composited result is identical to the single-file art — just riggable.

const String _base = 'assets/plant_stages';

/// Pivot at the base of the creature (hidden behind the pot's front rim), so
/// the sway/breathe rotates the visible body while the root stays planted.
const Alignment _basePivot = Alignment(0, 0.8);

/// Which parts animate, per stage image name.
class _Rig {
  final bool bodySway; // body gently sways + breathes (idle, with cooldown)
  final bool sides; // has fluttering side-leaf layers
  final bool stem; // sprout's swaying stem+leaf layer
  const _Rig({this.bodySway = false, this.sides = false, this.stem = false});
}

const Map<String, _Rig> _rigs = {
  'seed': _Rig(),
  'sprout': _Rig(stem: true),
  'seedling': _Rig(bodySway: true),
  'young': _Rig(bodySway: true, sides: true),
  'leafy': _Rig(bodySway: true, sides: true),
  'budding': _Rig(bodySway: true, sides: true),
  'bloom': _Rig(bodySway: true, sides: true),
};

/// Eye positions for the blink overlay, as fractions of the (square) stage box,
/// mirroring the dot-eyes baked into the matching `<stage>.svg`. Only the open
/// dot-eyed stages blink; the rest have closed/expressive eyes (seed & sprout
/// sleep, leafy `^^`, budding rests).
const Map<String, ({double dx, double cy, double r})> _eyeGeometry = {
  'seedling': (dx: 0.075, cy: 0.62, r: 0.033),
  'young': (dx: 0.08, cy: 0.58, r: 0.034),
  'bloom': (dx: 0.08, cy: 0.61, r: 0.034),
};

Widget _svg(String name, double size, {ColorFilter? colorFilter}) =>
    SvgPicture.asset(
      '$_base/$name.svg',
      width: size,
      height: size,
      colorFilter: colorFilter,
    );

/// Static pot layers (shared by every stage). The optional [colorFilter] is
/// the scene's time-of-day soil tint, applied to the whole painted layer.
Widget streakPotBack(
  double size,
  PotStyle style, {
  ColorFilter? colorFilter,
}) =>
    _potLayer(PotBackPainter(style), size, colorFilter);
Widget streakPotFront(
  double size,
  PotStyle style, {
  ColorFilter? colorFilter,
}) =>
    _potLayer(PotFrontPainter(style), size, colorFilter);

Widget _potLayer(CustomPainter painter, double size, ColorFilter? filter) {
  final paint = CustomPaint(
    size: Size(size, size),
    painter: painter,
  );
  return filter == null ? paint : ColorFiltered(colorFilter: filter, child: paint);
}

/// Builds just the creature (no soil) for [stage] at [size], applying the
/// given animation values. Pass `sway: 0, leaf: 0, breathe: 1, blink: 0` for a
/// frozen pose (used by the grow-pop crossfade).
Widget streakCreatureLayers({
  required PlantStage stage,
  required double size,
  required double sway,
  required double leaf,
  required double breathe,
  required double blink,
  double squash = 0,
  ColorFilter? colorFilter,
}) {
  final rig = _rigs[stage.image] ?? const _Rig();

  // Body (+ baked head leaves / bud / flower) with the blink overlay.
  Widget body = _svg(stage.image, size, colorFilter: colorFilter);
  final geo = _eyeGeometry[stage.image];
  if (geo != null && blink > 0.01) {
    body = Stack(
      alignment: Alignment.center,
      children: [
        body,
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _EyelidPainter(geo, blink)),
        ),
      ],
    );
  }
  if (rig.bodySway) {
    // Breathe mostly vertically (squash-and-stretch reads more alive than a
    // uniform pulse); `squash` adds the tap-bounce's extra stretch on top.
    body = Transform.scale(
      scaleX: (1 + (breathe - 1) * 0.45) * (1 + squash * 0.9),
      scaleY: breathe * (1 - squash),
      alignment: _basePivot,
      child: Transform.rotate(angle: sway, alignment: _basePivot, child: body),
    );
  }

  final layers = <Widget>[];
  // Sprout stem sits behind the seed body, swaying on its base.
  if (rig.stem) {
    layers.add(
      Transform.rotate(
        angle: leaf * 1.1,
        alignment: const Alignment(0, 0.36),
        child: _svg('sprout_stem', size, colorFilter: colorFilter),
      ),
    );
  }
  layers.add(body);
  // Side leaves overlap the front of the body, fluttering up/down on their
  // base (opposite phase left vs right). Their roots tuck behind the pot rim.
  if (rig.sides) {
    layers.add(
      Transform.rotate(
        angle: leaf,
        alignment: const Alignment(-0.32, 0.70),
        child: _svg('${stage.image}_sideL', size, colorFilter: colorFilter),
      ),
    );
    layers.add(
      Transform.rotate(
        angle: -leaf,
        alignment: const Alignment(0.32, 0.70),
        child: _svg('${stage.image}_sideR', size, colorFilter: colorFilter),
      ),
    );
  }

  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [for (final w in layers) Positioned.fill(child: w)],
    ),
  );
}

/// Animated idle streak plant (pot + creature + pot), self-driving.
class StreakPlant extends StatefulWidget {
  final PlantStage stage;
  final double size;
  final ColorFilter? colorFilter;
  final ColorFilter? soilColorFilter;
  final PotStyle potStyle;
  const StreakPlant({
    super.key,
    required this.stage,
    required this.size,
    this.colorFilter,
    this.soilColorFilter,
    this.potStyle = PotStyle.terracotta,
  });

  @override
  State<StreakPlant> createState() => _StreakPlantState();
}

class _StreakPlantState extends State<StreakPlant>
    with TickerProviderStateMixin {
  static final math.Random _rng = math.Random();

  // Idle body sway with a built-in rest period (see [_swayValue]).
  late final AnimationController _sway;
  // Side-leaf / stem flutter.
  late final AnimationController _leaf;
  // Slow breathing pulse.
  late final AnimationController _breathe;
  // One blink (close→open, ~260ms). Fired at randomized intervals by
  // [_scheduleBlink] — sometimes twice in a row — instead of a fixed loop,
  // so the creature reads as alive rather than metronomic.
  late final AnimationController _blink;
  // Tap response: an excited wiggle + squash-stretch bounce.
  late final AnimationController _pounce;
  // Tap celebration: a one-shot heart/sparkle burst over the creature.
  late final AnimationController _burst;
  int _burstSeed = 1;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _sway = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    )..repeat();
    _leaf = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _pounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
      value: 1,
    );
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
      value: 1,
    );
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 2400 + _rng.nextInt(3200)),
      () async {
        if (!mounted) return;
        await _blink.forward(from: 0);
        // Occasional quick double-blink.
        if (_rng.nextDouble() < 0.28) {
          await Future.delayed(const Duration(milliseconds: 110));
          if (!mounted) return;
          await _blink.forward(from: 0);
        }
        if (mounted) _scheduleBlink();
      },
    );
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _pounce.forward(from: 0);
    // A fresh seed each tap gives the burst a new scatter pattern.
    _burstSeed = _rng.nextInt(1 << 16);
    _burst.forward(from: 0);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _sway.dispose();
    _leaf.dispose();
    _breathe.dispose();
    _blink.dispose();
    _pounce.dispose();
    _burst.dispose();
    super.dispose();
  }

  // Sway that ramps in, oscillates a couple of times, then rests for the
  // remainder of the cycle — an idle "tic" rather than a constant wobble.
  double _swayValue() {
    final t = _sway.value;
    const active = 0.42;
    if (t >= active) return 0;
    final p = t / active;
    return math.sin(p * math.pi) * math.sin(p * 4 * math.pi) * 0.04;
  }

  double _leafValue() => math.sin(_leaf.value * 2 * math.pi) * 0.05;

  double _breatheValue() => 1 + math.sin(_breathe.value * 2 * math.pi) * 0.02;

  double _blinkAmount() {
    final v = _blink.value;
    if (v <= 0 || v >= 1) return 0;
    return v < 0.5 ? v / 0.5 : (1 - v) / 0.5;
  }

  // Tap bounce: a damped wiggle + stretch that settles within ~0.6s.
  double _pounceSway() {
    final p = _pounce.value;
    if (p >= 1) return 0;
    return math.sin(p * math.pi * 3) * 0.075 * (1 - p);
  }

  double _pounceSquash() {
    final p = _pounce.value;
    if (p >= 1) return 0;
    return math.sin(p * math.pi * 2) * 0.06 * (1 - p);
  }

  // The tap bounce also excites the side leaves a little.
  double _pounceLeaf() {
    final p = _pounce.value;
    if (p >= 1) return 0;
    return math.sin(p * math.pi * 4) * 0.05 * (1 - p);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: Listenable.merge(
            [_sway, _leaf, _breathe, _blink, _pounce, _burst],
          ),
          builder: (context, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: streakPotBack(
                    size,
                    widget.potStyle,
                    colorFilter: widget.soilColorFilter,
                  ),
                ),
                Positioned.fill(
                  child: streakCreatureLayers(
                    stage: widget.stage,
                    size: size,
                    sway: _swayValue() + _pounceSway(),
                    leaf: _leafValue() + _pounceLeaf(),
                    breathe: _breatheValue(),
                    blink: _blinkAmount(),
                    squash: _pounceSquash(),
                    colorFilter: widget.colorFilter,
                  ),
                ),
                Positioned.fill(
                  child: streakPotFront(
                    size,
                    widget.potStyle,
                    colorFilter: widget.soilColorFilter,
                  ),
                ),
                // Hearts + sparkles fly out when the creature is petted.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: SparkleBurstPainter(
                        p: _burst.value,
                        seed: _burstSeed,
                        count: 14,
                        hearts: true,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Paints two short "closed eyelid" strokes over the baked-in dot-eyes during a
/// blink. The stroke thickens with [amount] (0 = open, 1 = shut).
class _EyelidPainter extends CustomPainter {
  final ({double dx, double cy, double r}) geo;
  final double amount;
  const _EyelidPainter(this.geo, this.amount);

  @override
  void paint(Canvas canvas, Size size) {
    if (amount <= 0.01) return;
    final r = geo.r * size.width;
    final cy = geo.cy * size.height;
    final cxL = size.width * (0.5 - geo.dx);
    final cxR = size.width * (0.5 + geo.dx);
    final half = 1.2 * r;
    final paint = Paint()
      ..color = const Color(0xFF34433A)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2 * r * amount;
    canvas.drawLine(Offset(cxL - half, cy), Offset(cxL + half, cy), paint);
    canvas.drawLine(Offset(cxR - half, cy), Offset(cxR + half, cy), paint);
  }

  @override
  bool shouldRepaint(_EyelidPainter old) =>
      old.amount != amount || old.geo != geo;
}

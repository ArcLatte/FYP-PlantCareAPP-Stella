import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/plant_stage.dart';

/// Layered, per-part animated streak plant for the Tasks page.
///
/// Each growth stage is composed from separate SVG layers in
/// `assets/plant_stages/` so they can move independently:
///
///   soil_back (static) → sprout_stem → `stage` body (+head leaves, face)
///   → `stage_sideL` / `stage_sideR` leaves → soil_front (static)
///
/// The soil never moves. The body does a gentle idle sway + breathe that
/// *rests* between bursts (a cooldown, so it isn't constantly wobbling), the
/// side leaves flutter up/down pivoting on their base near the soil, and the
/// sprout's single leaf sways on its stem. `seed` is fully still; `sprout`
/// only moves its stem/leaf. Open dot-eyed stages also blink.
///
/// Splitting keeps each layer on the same `0 0 100 100` canvas, so the
/// composited result is identical to the single-file art — just riggable.

const String _base = 'assets/plant_stages';

/// Pivot at the base of the creature (hidden behind the front soil lip), so
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

/// Static soil layers (shared by every stage).
Widget streakSoilBack(double size, {ColorFilter? colorFilter}) =>
    _svg('soil_back', size, colorFilter: colorFilter);
Widget streakSoilFront(double size, {ColorFilter? colorFilter}) =>
    _svg('soil_front', size, colorFilter: colorFilter);

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
    body = Transform.scale(
      scale: breathe,
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
  // base (opposite phase left vs right). Their roots tuck behind the soil lip.
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

/// Animated idle streak plant (soil + creature + soil), self-driving.
class StreakPlant extends StatefulWidget {
  final PlantStage stage;
  final double size;
  final ColorFilter? colorFilter;
  final ColorFilter? soilColorFilter;
  const StreakPlant({
    super.key,
    required this.stage,
    required this.size,
    this.colorFilter,
    this.soilColorFilter,
  });

  @override
  State<StreakPlant> createState() => _StreakPlantState();
}

class _StreakPlantState extends State<StreakPlant>
    with TickerProviderStateMixin {
  // Idle body sway with a built-in rest period (see [_swayValue]).
  late final AnimationController _sway;
  // Side-leaf / stem flutter.
  late final AnimationController _leaf;
  // Slow breathing pulse.
  late final AnimationController _breathe;
  // Periodic eye blink.
  late final AnimationController _blink;

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
      duration: const Duration(milliseconds: 4400),
    )..repeat();
  }

  @override
  void dispose() {
    _sway.dispose();
    _leaf.dispose();
    _breathe.dispose();
    _blink.dispose();
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
    const start = 0.94;
    final v = _blink.value;
    if (v < start) return 0;
    final t = (v - start) / (1 - start);
    return t < 0.5 ? t / 0.5 : (1 - t) / 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_sway, _leaf, _breathe, _blink]),
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: streakSoilBack(
                  size,
                  colorFilter: widget.soilColorFilter,
                ),
              ),
              Positioned.fill(
                child: streakCreatureLayers(
                  stage: widget.stage,
                  size: size,
                  sway: _swayValue(),
                  leaf: _leafValue(),
                  breathe: _breatheValue(),
                  blink: _blinkAmount(),
                  colorFilter: widget.colorFilter,
                ),
              ),
              Positioned.fill(
                child: streakSoilFront(
                  size,
                  colorFilter: widget.soilColorFilter,
                ),
              ),
            ],
          );
        },
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

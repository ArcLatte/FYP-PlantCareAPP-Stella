import 'package:flutter/material.dart';

import '../models/cosmetic.dart';

/// Code-drawn pot for the streak companion.
///
/// The pot replaces the old bare-soil mound: [PotBackPainter] paints the
/// rim interior + soil (behind the creature) and [PotFrontPainter] paints
/// the rim band + tapered body (in front of it), on the same `0..1` square
/// the plant SVGs use. Geometry mirrors the soil layers it replaced — front
/// coverage starts at y≈0.83 so every stage (the seed sits at y 0.62-0.87)
/// still tucks into it the way it tucked into the soil lip.
class PotStyle {
  final Color body;
  final Color rim;
  final Color accent;
  final String pattern; // none | stripes | dots | wave

  const PotStyle({
    required this.body,
    required this.rim,
    required this.accent,
    this.pattern = 'none',
  });

  /// The built-in default: classic terracotta, owned by everyone.
  static const PotStyle terracotta = PotStyle(
    body: Color(0xFFC97B54),
    rim: Color(0xFFB4623E),
    accent: Color(0xFFE8C4A8),
  );

  /// Parse a `{'body': '#hex', 'rim': '#hex', 'accent': '#hex',
  /// 'pattern': '...'}` shop payload; falls back to [terracotta] when the
  /// payload is missing or malformed.
  static PotStyle fromPayload(Map<String, dynamic>? payload) {
    final body = Cosmetic.parseTint({'tint': payload?['body']});
    if (payload == null || body == null) return terracotta;
    return PotStyle(
      body: body,
      rim: Cosmetic.parseTint({'tint': payload['rim']}) ?? body,
      accent: Cosmetic.parseTint({'tint': payload['accent']}) ?? Colors.white,
      pattern: payload['pattern']?.toString() ?? 'none',
    );
  }

  Color get _soil => const Color(0xFF6E4326);
  Color get _inner => Color.lerp(rim, Colors.black, 0.30)!;
}

/// Rim interior + soil surface, painted behind the creature so it rises
/// out of the pot.
class PotBackPainter extends CustomPainter {
  final PotStyle style;
  const PotBackPainter(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ground shadow under the pot (same spot the soil mound cast its own).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.96),
        width: w * 0.54,
        height: h * 0.07,
      ),
      Paint()..color = const Color(0x295A3A22),
    );

    // Inner back wall of the rim, peeking above the front band.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.825),
        width: w * 0.57,
        height: h * 0.095,
      ),
      Paint()..color = style._inner,
    );

    // Soil the creature is planted in.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.835),
        width: w * 0.48,
        height: h * 0.075,
      ),
      Paint()..color = style._soil,
    );
  }

  @override
  bool shouldRepaint(PotBackPainter old) => old.style != style;
}

/// Rim band + tapered body (+ glaze pattern), painted in front of the
/// creature's base.
class PotFrontPainter extends CustomPainter {
  final PotStyle style;
  const PotFrontPainter(this.style);

  Path _bodyPath(double w, double h) => Path()
    ..moveTo(w * 0.245, h * 0.905)
    ..lineTo(w * 0.755, h * 0.905)
    ..lineTo(w * 0.705, h * 0.975)
    ..quadraticBezierTo(w * 0.70, h * 0.985, w * 0.68, h * 0.985)
    ..lineTo(w * 0.32, h * 0.985)
    ..quadraticBezierTo(w * 0.30, h * 0.985, w * 0.295, h * 0.975)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Tapered body below the rim.
    final body = _bodyPath(w, h);
    canvas.drawPath(body, Paint()..color = style.body);

    // Glaze pattern, clipped to the body.
    if (style.pattern != 'none') {
      canvas.save();
      canvas.clipPath(body);
      final paint = Paint()..color = style.accent.withValues(alpha: 0.85);
      switch (style.pattern) {
        case 'stripes':
          for (final fx in const [0.32, 0.44, 0.56, 0.68]) {
            canvas.drawRect(
              Rect.fromLTWH(w * fx, h * 0.9, w * 0.035, h * 0.1),
              paint,
            );
          }
        case 'dots':
          for (final (fx, fy) in const [
            (0.34, 0.928), (0.50, 0.935), (0.66, 0.928),
            (0.42, 0.962), (0.58, 0.962),
          ]) {
            canvas.drawCircle(Offset(w * fx, h * fy), w * 0.016, paint);
          }
        case 'wave':
          final wave = Path()..moveTo(w * 0.24, h * 0.945);
          for (var i = 0; i < 4; i++) {
            final x0 = 0.24 + i * 0.13;
            wave.quadraticBezierTo(
              w * (x0 + 0.0325), h * 0.925,
              w * (x0 + 0.065), h * 0.945,
            );
            wave.quadraticBezierTo(
              w * (x0 + 0.0975), h * 0.965,
              w * (x0 + 0.13), h * 0.945,
            );
          }
          canvas.drawPath(
            wave,
            Paint()
              ..color = style.accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = h * 0.018
              ..strokeCap = StrokeCap.round,
          );
      }
      canvas.restore();
    }

    // Side shading + a soft left highlight so the body reads round.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.64, h * 0.9, w * 0.13, h * 0.1),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.28, h * 0.9, w * 0.05, h * 0.1),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();

    // Rim band on top, slightly wider than the body.
    final rimRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.20, h * 0.828, w * 0.80, h * 0.905),
      Radius.circular(w * 0.022),
    );
    canvas.drawRRect(rimRect, Paint()..color = style.rim);
    // Light catching the rim's top edge; a hairline shadow under it.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.21, h * 0.832, w * 0.79, h * 0.848),
        Radius.circular(w * 0.02),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawRect(
      Rect.fromLTRB(w * 0.245, h * 0.905, w * 0.755, h * 0.917),
      Paint()..color = Colors.black.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(PotFrontPainter old) => old.style != style;
}

/// Small standalone pot (both layers, no creature) — used as the swatch on
/// shop cards. Drawn slightly zoomed so the pot fills the box.
class PotIcon extends StatelessWidget {
  final PotStyle style;
  final double size;
  const PotIcon({super.key, required this.style, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: size * 1.9,
          maxHeight: size * 1.9,
          alignment: Alignment.center,
          child: Transform.translate(
            // The pot occupies the bottom ~22% of its square canvas; shift
            // it up so the zoomed pot sits centered in the icon box.
            offset: Offset(0, -size * 0.72),
            child: SizedBox(
              width: size * 1.9,
              height: size * 1.9,
              child: CustomPaint(
                painter: _PotIconPainter(style),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PotIconPainter extends CustomPainter {
  final PotStyle style;
  const _PotIconPainter(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    PotBackPainter(style).paint(canvas, size);
    PotFrontPainter(style).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_PotIconPainter old) => old.style != style;
}

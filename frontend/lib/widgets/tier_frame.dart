import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Decorative avatar frames for the 8 level tiers. Ornamentation ramps up
/// with tier: a plain ring for Seedling all the way to a radiant, leafed,
/// glowing wreath for Garden Sage.
///
/// Usage: wrap any circular avatar. The frame paints in the padding band
/// around the child, so pass the avatar at its natural size and let the
/// frame add ~12-16% on each side.
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

  static const _tierOrder = [
    'Seedling',
    'Sprout',
    'Sapling',
    'Gardener',
    'Cultivator',
    'Botanist',
    'Plantsmith',
    'Garden Sage',
  ];

  /// 0..7 index of [tier]; unknown labels clamp to Seedling.
  static int tierIndex(String tier) {
    final i = _tierOrder.indexOf(tier);
    return i < 0 ? 0 : i;
  }

  /// Mirror of the backend tier curve (CustomUser.tier in models.py) so the
  /// level-up toast can name the tier without an extra profile fetch.
  static String tierForLevel(int level) {
    if (level < 5) return 'Seedling';
    if (level < 10) return 'Sprout';
    if (level < 20) return 'Sapling';
    if (level < 35) return 'Gardener';
    if (level < 50) return 'Cultivator';
    if (level < 75) return 'Botanist';
    if (level < 100) return 'Plantsmith';
    return 'Garden Sage';
  }

  /// Accent color used for the frame of each tier stage.
  static Color tierColor(String tier) {
    switch (tierIndex(tier)) {
      case 0:
        return const Color(0xFF9CB5A0); // Seedling — soft sage
      case 1:
        return const Color(0xFF4CAF7D); // Sprout — primary green
      case 2:
        return const Color(0xFF3D9466); // Sapling — deep green
      case 3:
        return const Color(0xFF26A69A); // Gardener — teal
      case 4:
        return const Color(0xFF9AA5B1); // Cultivator — silver
      case 5:
        return const Color(0xFF4F9FD9); // Botanist — sky blue
      case 6:
        return const Color(0xFFE5A722); // Plantsmith — gold
      case 7:
      default:
        return const Color(0xFFFFC83D); // Garden Sage — radiant gold
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = size * 0.14;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TierFramePainter(tierIndex(tier)),
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: child,
        ),
      ),
    );
  }
}

class _TierFramePainter extends CustomPainter {
  final int index;
  _TierFramePainter(this.index);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final color = TierFrame.tierColor(TierFrame._tierOrder[index]);
    final outerR = size.width / 2 - 1.5;
    final strokeW = size.width * 0.035;

    // Radiant glow for the top tiers.
    if (index >= 6) {
      final glow = Paint()
        ..color = color.withValues(alpha: index == 7 ? 0.45 : 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW * 2.4
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.05);
      canvas.drawCircle(center, outerR - strokeW, glow);
    }

    // Main ring.
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;
    canvas.drawCircle(center, outerR - strokeW / 2, ring);

    // Inner companion ring from Sprout up.
    if (index >= 1) {
      final inner = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW * 0.5;
      canvas.drawCircle(center, outerR - strokeW * 2.2, inner);
    }

    // Dot accents from Sapling up: 4 dots, 8 from Cultivator.
    if (index >= 2) {
      final dotCount = index >= 4 ? 8 : 4;
      final dotR = strokeW * 0.8;
      final dotPaint = Paint()..color = color;
      for (int i = 0; i < dotCount; i++) {
        // Offset by half a slot so dots sit between leaves when both shown.
        final angle = (2 * math.pi * i / dotCount) + math.pi / dotCount;
        final pos = center +
            Offset(math.cos(angle), math.sin(angle)) *
                (outerR - strokeW / 2);
        canvas.drawCircle(pos, dotR, dotPaint);
      }
    }

    // Leaf motifs from Gardener up: 4 leaves → 6 → 8.
    if (index >= 3) {
      final leafCount = index >= 7 ? 8 : (index >= 5 ? 6 : 4);
      final leafPaint = Paint()..color = color;
      final leafLen = size.width * 0.085;
      final leafWid = size.width * 0.042;
      for (int i = 0; i < leafCount; i++) {
        final angle = 2 * math.pi * i / leafCount - math.pi / 2;
        canvas.save();
        canvas.translate(
          center.dx + math.cos(angle) * (outerR - strokeW / 2),
          center.dy + math.sin(angle) * (outerR - strokeW / 2),
        );
        canvas.rotate(angle + math.pi / 2);
        // Simple leaf: two mirrored quadratic arcs meeting at a point.
        final path = Path()
          ..moveTo(0, -leafLen / 2)
          ..quadraticBezierTo(leafWid, 0, 0, leafLen / 2)
          ..quadraticBezierTo(-leafWid, 0, 0, -leafLen / 2)
          ..close();
        canvas.drawPath(path, leafPaint);
        canvas.restore();
      }
    }

    // Sparkles for Garden Sage only: tiny 4-point stars between leaves.
    if (index >= 7) {
      final sparkle = Paint()..color = Colors.white.withValues(alpha: 0.9);
      const count = 8;
      final sparkleR = strokeW * 0.55;
      for (int i = 0; i < count; i++) {
        final angle = (2 * math.pi * i / count) + math.pi / count - math.pi / 2;
        final pos = center +
            Offset(math.cos(angle), math.sin(angle)) *
                (outerR - strokeW / 2);
        final path = Path()
          ..moveTo(pos.dx, pos.dy - sparkleR * 2)
          ..quadraticBezierTo(pos.dx, pos.dy, pos.dx + sparkleR * 2, pos.dy)
          ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + sparkleR * 2)
          ..quadraticBezierTo(pos.dx, pos.dy, pos.dx - sparkleR * 2, pos.dy)
          ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - sparkleR * 2)
          ..close();
        canvas.drawPath(path, sparkle);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TierFramePainter old) => old.index != index;
}

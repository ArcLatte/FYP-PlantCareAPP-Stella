import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../models/medal_series.dart';
import 'medal.dart';

/// Full-screen gacha-style reveal for newly unlocked medals: dark scrim,
/// rotating ray burst, medallion springing in with its rarity glow, stars
/// popping in one by one. Multiple unlocks chain back-to-back.
class MedalReveal {
  MedalReveal._();

  static Future<void> show(
    BuildContext context,
    List<Achievement> unlocked,
  ) async {
    for (final a in unlocked) {
      if (!context.mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false, // the content handles taps itself
        barrierColor: Colors.black.withValues(alpha: 0.75),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (dialogContext, _, _) =>
            _RevealOverlay(achievement: a),
        transitionBuilder: (context, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      );
    }
  }
}

class _RevealOverlay extends StatefulWidget {
  final Achievement achievement;
  const _RevealOverlay({required this.achievement});

  @override
  State<_RevealOverlay> createState() => _RevealOverlayState();
}

class _RevealOverlayState extends State<_RevealOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _intro; // one-shot entrance
  late final AnimationController _spin; // looping ray rotation

  late final Animation<double> _medalScale;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _medalScale = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
    );
    _textFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    super.dispose();
  }

  /// Each star pops in its own late slice of the intro.
  Animation<double> _starPop(int i, int count) {
    final start = 0.45 + 0.4 * (i / count);
    return CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.18).clamp(0.0, 1.0),
          curve: Curves.elasticOut),
    );
  }

  void _dismiss() {
    // Let a tap skip the intro first, close on the second tap.
    if (_intro.value < 1.0) {
      _intro.value = 1.0;
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final info = medalInfoFor(a);
    final color = info.metal.color;
    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.opaque,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _textFade,
                child: const Text(
                  'MEDAL UNLOCKED',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              // Ray burst + medallion
              SizedBox(
                width: 230,
                height: 230,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _spin,
                      builder: (context, _) => Transform.rotate(
                        angle: _spin.value * 2 * math.pi,
                        child: CustomPaint(
                          size: const Size(230, 230),
                          painter: _RayBurstPainter(
                              color.withValues(alpha: 0.25)),
                        ),
                      ),
                    ),
                    ScaleTransition(
                      scale: _medalScale,
                      child: Medal(
                        metal: info.metal,
                        shape: info.shape,
                        icon: a.iconData,
                        level: info.level,
                        maxLevel: info.maxLevel,
                        size: 124,
                        glow: true,
                        // The reveal animates its own star row below.
                        showStars: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < info.maxLevel; i++)
                    if (i < info.level)
                      ScaleTransition(
                        scale: _starPop(i, info.level),
                        child: Icon(Icons.star_rounded,
                            size: 30, color: color),
                      )
                    else
                      const Icon(Icons.star_outline_rounded,
                          size: 30, color: Colors.white24),
                ],
              ),
              const SizedBox(height: 12),
              FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: [
                    Text(
                      a.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      info.maxLevel > 1
                          ? '${info.seriesName} · ${info.metal.label} · Lv ${info.level} · +${a.xpReward} XP'
                          : '${info.metal.label} · +${a.xpReward} XP',
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        a.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Tap to continue',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft rotating sunburst behind the medallion.
class _RayBurstPainter extends CustomPainter {
  final Color color;
  _RayBurstPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()..color = color;
    const rays = 12;
    for (int i = 0; i < rays; i++) {
      final a0 = 2 * math.pi * i / rays;
      const halfWidth = math.pi / rays * 0.45;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(a0 - halfWidth) * r,
            center.dy + math.sin(a0 - halfWidth) * r)
        ..lineTo(center.dx + math.cos(a0 + halfWidth) * r,
            center.dy + math.sin(a0 + halfWidth) * r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RayBurstPainter old) => old.color != color;
}

import 'package:flutter/material.dart';
import '../core/theme.dart';

/// A shimmering rounded rectangle, used as a placeholder while real content
/// loads. Drives a single AnimationController that slides a highlight
/// gradient across the box.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Tuned for the light theme: slightly darker than `surface` for the base
  // so the shape reads against the page background, with a softer highlight.
  static const _base = Color(0xFFE9EEEA);
  static const _highlight = Color(0xFFF7F9F7);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // t goes 0 → 1; map it onto gradient stops that slide left → right.
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2 * t - 0.6, 0),
              end: Alignment(-1.0 + 2 * t + 0.6, 0),
              colors: const [_base, _highlight, _base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton stand-in for `_PlantGridCard` on the home screen. Shape matches
/// the real tile (image area on top, two text rows below) so the grid
/// doesn't jump when real data lands.
class PlantCardSkeleton extends StatelessWidget {
  const PlantCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image area
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: const SkeletonBox(radius: 0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 110, height: 14, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 70, height: 11, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

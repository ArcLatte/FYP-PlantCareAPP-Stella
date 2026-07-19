import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Gold-coin art + helpers for the spendable currency. The backend still
/// stores/serialises the balance as `seeds` — only the presentation is
/// coin-branded, so nothing on the API surface changes.

/// Gold palette shared by the coin art and coin-tinted chrome. Softened
/// toward a warm honey-gold (rather than a saturated neon-orange) so it sits
/// gently next to the blue shop chrome.
class CoinColors {
  CoinColors._();
  static const Color light = Color(0xFFFFE0A0);
  static const Color mid = Color(0xFFF0C868); // coin face
  static const Color deep = Color(0xFFD9AC4A);
  static const Color rim = Color(0xFFC99A38); // coin edge disc + star emblem
  // Dark "ink" for text sitting on gold surfaces (rim is too low-contrast).
  static const Color dark = Color(0xFF6B4708);
}

/// Code-drawn gold coin in a flat style: solid rim disc, solid face nudged
/// upward (the thicker rim below fakes the depth — no gradients, so it stays
/// crisp and coin-like even at chip sizes), and a solid star emblem.
/// Drop-in wherever an `Icon` used to mark the currency.
class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _CoinPainter(),
    );
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Rim disc — the darkest gold, so the silhouette reads at any size.
    canvas.drawCircle(c, r, Paint()..color = CoinColors.rim);
    // Face sits high on the rim: the thicker band left showing at the
    // bottom is the whole (flat, solid-color) 3D effect.
    final fc = c.translate(0, -r * 0.08);
    canvas.drawCircle(fc, r * 0.78, Paint()..color = CoinColors.mid);

    // Solid 4-point sparkle star in the centre of the face.
    final sr = r * 0.44; // long points
    final wr = r * 0.13; // waist
    final star = Path()
      ..moveTo(fc.dx, fc.dy - sr)
      ..quadraticBezierTo(fc.dx + wr, fc.dy - wr, fc.dx + sr, fc.dy)
      ..quadraticBezierTo(fc.dx + wr, fc.dy + wr, fc.dx, fc.dy + sr)
      ..quadraticBezierTo(fc.dx - wr, fc.dy + wr, fc.dx - sr, fc.dy)
      ..quadraticBezierTo(fc.dx - wr, fc.dy - wr, fc.dx, fc.dy - sr)
      ..close();
    canvas.drawPath(star, Paint()..color = CoinColors.rim);
  }

  @override
  bool shouldRepaint(covariant _CoinPainter oldDelegate) => false;
}

/// Gold balance pill (coin icon + amount). Tapping opens the "how to earn
/// coins" sheet unless a custom [onTap] is supplied.
class CoinPill extends StatelessWidget {
  final int coins;
  final VoidCallback? onTap;
  const CoinPill({super.key, required this.coins, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => showCoinGuideSheet(context, coins: coins),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: CoinColors.mid.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CoinColors.mid.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 16),
            const SizedBox(width: 5),
            Text(
              '$coins',
              style: const TextStyle(
                color: CoinColors.dark,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet explaining where coins come from. Reward numbers mirror the
/// backend tunables (SEEDS_PER_LEVEL_UP, SEED_REWARDS, weekly SEEDS_REWARD)
/// — update both sides together.
Future<void> showCoinGuideSheet(BuildContext context, {required int coins}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  const CoinIcon(size: 54),
                  const SizedBox(height: 8),
                  Text(
                    '$coins coins',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'HOW TO EARN COINS',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            const _EarnRow(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.primary,
              title: 'Level up',
              subtitle: 'Earn XP from caring for plants and scanning',
              reward: '+25',
            ),
            const _EarnRow(
              icon: Icons.emoji_events_rounded,
              color: Color(0xFFE5A722),
              title: 'Unlock medals',
              subtitle: 'Bronze +10 · Silver +25 · Gold +50',
              reward: '+10–50',
            ),
            const _EarnRow(
              icon: Icons.flag_rounded,
              color: Color(0xFF4F9FD9),
              title: 'Weekly challenges',
              subtitle: 'Complete the challenge before the week ends',
              reward: '+40',
            ),
            const SizedBox(height: 8),
            Text(
              'Spend coins in the Shop on pots and namecards for your '
              'companion.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _EarnRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String reward;
  const _EarnRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.reward,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  subtitle,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: CoinColors.mid.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 13),
                const SizedBox(width: 4),
                Text(
                  reward,
                  style: const TextStyle(
                    color: CoinColors.dark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

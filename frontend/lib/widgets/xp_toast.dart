import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/xp_result.dart';
import '../services/api_service.dart';
import 'medal_reveal.dart';
import 'tier_frame.dart';

/// Celebration toasts for XP gain, level-ups, and achievement unlocks.
/// Reads from `ApiService.lastXpResult` (populated transparently by every
/// XP-granting API call). Call [flush] right after care/scan/plant-create
/// to display whichever toasts apply.
class XpToast {
  XpToast._();

  /// Read and clear `ApiService.lastXpResult`, then surface a small
  /// sequence: per-unlock badge toast → level-up toast → bare "+N XP" pill.
  /// Toasts are 2 seconds each; we let them stack via the messenger queue.
  static void flush(BuildContext context) {
    final result = ApiService.consumeLastXpResult();
    if (result == null || !result.hasAnything) return;
    show(context, result);
  }

  static void show(BuildContext context, XpResult r) {
    final messenger = ScaffoldMessenger.of(context);
    Future<void> run() async {
      // Unlocks get the full-screen gacha reveal; level/XP toasts queue
      // after the reveal is dismissed so they don't fight for attention.
      if (r.unlocked.isNotEmpty) {
        await MedalReveal.show(context, r.unlocked);
      }
      if (r.leveledUpTo != null) {
        messenger.showSnackBar(_levelUpSnack(r.leveledUpTo!));
      }
      // Plain gain only if nothing flashier already conveyed it.
      if (r.unlocked.isEmpty && r.leveledUpTo == null && r.xpGained > 0) {
        messenger.showSnackBar(_xpSnack(r.xpGained));
      }
    }

    run();
  }

  static SnackBar _xpSnack(int amount) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            '+$amount XP',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      duration: const Duration(seconds: 2),
    );
  }

  static SnackBar _levelUpSnack(int newLevel) {
    final tier = TierFrame.tierForLevel(newLevel);
    // Crossing into a new tier (the previous level mapped to a different
    // one) earns a longer toast that names the tier + shows its frame.
    final newTier = TierFrame.tierForLevel(newLevel - 1) != tier;
    return SnackBar(
      content: Row(
        children: [
          TierFrame(
            tier: tier,
            size: 44,
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level $newLevel reached!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (newTier)
                  Text(
                    'New tier: $tier',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.amber,
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      duration: Duration(seconds: newTier ? 4 : 3),
    );
  }

}

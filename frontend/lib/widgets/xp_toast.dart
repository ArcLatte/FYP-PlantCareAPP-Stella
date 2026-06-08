import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/achievement.dart';
import '../models/xp_result.dart';
import '../services/api_service.dart';

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
    // Unlocks first — the user wants to see what they earned.
    for (final ach in r.unlocked) {
      messenger.showSnackBar(_achievementSnack(ach));
    }
    if (r.leveledUpTo != null) {
      messenger.showSnackBar(_levelUpSnack(r.leveledUpTo!));
    }
    // Plain gain only if nothing flashier already conveyed it.
    if (r.unlocked.isEmpty && r.leveledUpTo == null && r.xpGained > 0) {
      messenger.showSnackBar(_xpSnack(r.xpGained));
    }
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
    return SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Level $newLevel reached!',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
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
      duration: const Duration(seconds: 3),
    );
  }

  static SnackBar _achievementSnack(Achievement a) {
    return SnackBar(
      content: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(a.iconData, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Achievement unlocked',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  a.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (a.xpReward > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+${a.xpReward}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      backgroundColor: a.tierColor,
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      duration: const Duration(seconds: 3),
    );
  }
}

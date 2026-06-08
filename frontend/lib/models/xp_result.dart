import 'achievement.dart';

/// Side-channel returned by every XP-granting backend action (login + care
/// + scan + plant create). Carried back via `ApiService.lastXpResult` so
/// individual call-site signatures don't have to change.
class XpResult {
  final int xpGained;
  final int? leveledUpTo;
  final List<Achievement> unlocked;

  const XpResult({
    required this.xpGained,
    required this.leveledUpTo,
    required this.unlocked,
  });

  bool get hasAnything =>
      xpGained > 0 || leveledUpTo != null || unlocked.isNotEmpty;

  /// Parse the three side-channel fields from any response JSON. Returns
  /// null when none of them are present (so non-XP responses don't trigger
  /// a phantom toast).
  static XpResult? fromJsonOrNull(Map<String, dynamic> json) {
    final xp = (json['xp_gained'] as num?)?.toInt() ?? 0;
    final lvl = (json['leveled_up_to'] as num?)?.toInt();
    final rawUnlocked = json['unlocked'];
    final unlocked = (rawUnlocked is List)
        ? rawUnlocked
              .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
              .toList()
        : <Achievement>[];
    if (xp == 0 && lvl == null && unlocked.isEmpty) return null;
    return XpResult(xpGained: xp, leveledUpTo: lvl, unlocked: unlocked);
  }
}

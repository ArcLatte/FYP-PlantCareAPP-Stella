import 'achievement.dart';
import 'weekly_challenge.dart';

/// Side-channel returned by every XP-granting backend action (login + care
/// + scan + plant create). Carried back via `ApiService.lastXpResult` so
/// individual call-site signatures don't have to change.
class XpResult {
  final int xpGained;
  final int seedsGained;
  final int? leveledUpTo;
  final List<Achievement> unlocked;

  /// True when a banked streak save was auto-consumed to bridge missed days
  /// on this action (`streak_saved` in the care response).
  final bool streakSaved;

  /// Set when this action completed the weekly challenge.
  final WeeklyCompletion? weeklyCompleted;

  const XpResult({
    required this.xpGained,
    this.seedsGained = 0,
    required this.leveledUpTo,
    required this.unlocked,
    this.streakSaved = false,
    this.weeklyCompleted,
  });

  bool get hasAnything =>
      xpGained > 0 ||
      leveledUpTo != null ||
      unlocked.isNotEmpty ||
      streakSaved ||
      weeklyCompleted != null;

  /// Parse the side-channel fields from any response JSON. Returns null when
  /// none of them are present (so non-XP responses don't trigger a phantom
  /// toast).
  static XpResult? fromJsonOrNull(Map<String, dynamic> json) {
    final xp = (json['xp_gained'] as num?)?.toInt() ?? 0;
    final lvl = (json['leveled_up_to'] as num?)?.toInt();
    final rawUnlocked = json['unlocked'];
    final unlocked = (rawUnlocked is List)
        ? rawUnlocked
              .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
              .toList()
        : <Achievement>[];
    final seeds = (json['seeds_gained'] as num?)?.toInt() ?? 0;
    final saved = json['streak_saved'] == true;
    final weekly = WeeklyCompletion.fromJsonOrNull(json['weekly_completed']);
    if (xp == 0 && lvl == null && unlocked.isEmpty && !saved && weekly == null) {
      return null;
    }
    return XpResult(
      xpGained: xp,
      seedsGained: seeds,
      leveledUpTo: lvl,
      unlocked: unlocked,
      streakSaved: saved,
      weeklyCompleted: weekly,
    );
  }
}

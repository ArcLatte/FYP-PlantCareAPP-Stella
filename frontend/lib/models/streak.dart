/// Care streak summary, mirrored from `GET /api/streak/`.
class Streak {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCareDate;
  final bool activeToday;

  /// Banked streak saves (auto-consumed to bridge missed days).
  final int freezes;

  /// True while a gap in care is currently being held by banked saves —
  /// the streak is alive but shielded, not yet re-earned.
  final bool freezeActive;

  const Streak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastCareDate,
    required this.activeToday,
    this.freezes = 0,
    this.freezeActive = false,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    final raw = json['last_care_date']?.toString();
    return Streak(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastCareDate: (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw),
      activeToday: json['active_today'] == true,
      freezes: (json['freezes'] as num?)?.toInt() ?? 0,
      freezeActive: json['freeze_active'] == true,
    );
  }
}

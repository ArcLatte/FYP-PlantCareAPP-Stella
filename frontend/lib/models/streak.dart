/// Care streak summary, mirrored from `GET /api/streak/`.
class Streak {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCareDate;
  final bool activeToday;

  const Streak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastCareDate,
    required this.activeToday,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    final raw = json['last_care_date']?.toString();
    return Streak(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastCareDate: (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw),
      activeToday: json['active_today'] == true,
    );
  }
}

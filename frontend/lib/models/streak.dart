/// Care streak summary, mirrored from `GET /api/streak/`.
class Streak {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCareDate;
  final bool activeToday;

  /// The server's current date (its "today"). Care days are dated on the
  /// server clock, so the day strip centers on this rather than the device
  /// clock — otherwise a device a day off would shift the window and hide a
  /// just-logged care day. Falls back to the device date when absent.
  final DateTime? today;

  /// Banked streak saves (auto-consumed to bridge missed days).
  final int freezes;

  /// True while a gap in care is currently being held by banked saves —
  /// the streak is alive but shielded, not yet re-earned.
  final bool freezeActive;

  /// Days of the last week that actually had a care action, as
  /// local-midnight dates. The day strip lights these directly instead of
  /// counting back from the streak length (which drifts across save-bridged
  /// days). Null when the backend didn't send them.
  final Set<DateTime>? recentCareDays;

  /// Equipped creature-skin payload (`{'tint': '#hex', 'amount': 0.x}`)
  /// or null when no skin is equipped.
  final Map<String, dynamic>? equippedSkin;

  /// Equipped pot-style payload (`{'body': '#hex', 'rim': '#hex', ...}`)
  /// or null — the UI falls back to the default terracotta pot.
  final Map<String, dynamic>? equippedPot;

  const Streak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastCareDate,
    required this.activeToday,
    this.today,
    this.freezes = 0,
    this.freezeActive = false,
    this.recentCareDays,
    this.equippedSkin,
    this.equippedPot,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    final raw = json['last_care_date']?.toString();
    final rawToday = json['today']?.toString();
    return Streak(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastCareDate: (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw),
      activeToday: json['active_today'] == true,
      today: (rawToday == null || rawToday.isEmpty)
          ? null
          : DateTime.tryParse(rawToday),
      freezes: (json['freezes'] as num?)?.toInt() ?? 0,
      freezeActive: json['freeze_active'] == true,
      recentCareDays: parseDates(json['recent_care_days']),
      equippedSkin: (json['equipped_skin'] is Map<String, dynamic>)
          ? json['equipped_skin'] as Map<String, dynamic>
          : null,
      equippedPot: (json['equipped_pot'] is Map<String, dynamic>)
          ? json['equipped_pot'] as Map<String, dynamic>
          : null,
    );
  }

  /// Parses a JSON list of `YYYY-MM-DD` strings into local-midnight dates.
  static Set<DateTime>? parseDates(dynamic list) {
    if (list is! List) return null;
    final out = <DateTime>{};
    for (final e in list) {
      final d = DateTime.tryParse(e.toString());
      if (d != null) out.add(DateTime(d.year, d.month, d.day));
    }
    return out;
  }
}

/// Full care-day history for the streak calendar, mirrored from
/// `GET /api/streak/calendar/`.
class StreakCalendar {
  /// Every local calendar day with at least one care action.
  final Set<DateTime> careDates;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCareDate;
  final bool activeToday;
  final bool freezeActive;

  /// The server's current date, so the calendar highlights "today" and dims
  /// future days by the same clock the care days were recorded on. Falls
  /// back to the device date when absent.
  final DateTime? today;

  const StreakCalendar({
    required this.careDates,
    required this.currentStreak,
    required this.longestStreak,
    this.lastCareDate,
    required this.activeToday,
    required this.freezeActive,
    this.today,
  });

  factory StreakCalendar.fromJson(Map<String, dynamic> json) {
    final raw = json['last_care_date']?.toString();
    final rawToday = json['today']?.toString();
    return StreakCalendar(
      careDates: Streak.parseDates(json['care_dates']) ?? {},
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastCareDate: (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw),
      activeToday: json['active_today'] == true,
      freezeActive: json['freeze_active'] == true,
      today: (rawToday == null || rawToday.isEmpty)
          ? null
          : DateTime.tryParse(rawToday),
    );
  }
}

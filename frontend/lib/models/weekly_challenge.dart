/// The current week's challenge + the user's live progress, mirrored from
/// `GET /api/weekly-challenge/`. One challenge is active per ISO week (same
/// for everyone); completing it banks a streak save on top of the XP.
class WeeklyChallenge {
  final String code;
  final String name;
  final String description;
  final String icon; // Material icon name string (same scheme as medals)
  final int target;
  final int progress;
  final bool completed;
  final int xpReward;
  final int saveReward;
  final int daysLeft;

  const WeeklyChallenge({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.target,
    required this.progress,
    required this.completed,
    required this.xpReward,
    required this.saveReward,
    required this.daysLeft,
  });

  double get fraction =>
      target == 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  factory WeeklyChallenge.fromJson(Map<String, dynamic> json) {
    return WeeklyChallenge(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      target: (json['target'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      completed: json['completed'] == true,
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 0,
      saveReward: (json['save_reward'] as num?)?.toInt() ?? 0,
      daysLeft: (json['days_left'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Side-channel payload when a care/scan/note action completes the weekly
/// challenge (`weekly_completed` in the response JSON).
class WeeklyCompletion {
  final String code;
  final String name;
  final int xpReward;
  final int savesBanked;

  const WeeklyCompletion({
    required this.code,
    required this.name,
    required this.xpReward,
    required this.savesBanked,
  });

  static WeeklyCompletion? fromJsonOrNull(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    return WeeklyCompletion(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 0,
      savesBanked: (json['saves_banked'] as num?)?.toInt() ?? 0,
    );
  }
}

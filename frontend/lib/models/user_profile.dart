/// User profile + level + streak summary, mirrored from `GET /api/profile/`.
class UserProfile {
  final String username;
  final String email;
  final int level;
  final String tier;
  final int xp;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int currentStreak;
  final int longestStreak;
  final int achievementsUnlocked;
  final int achievementsTotal;

  const UserProfile({
    required this.username,
    required this.email,
    required this.level,
    required this.tier,
    required this.xp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.currentStreak,
    required this.longestStreak,
    required this.achievementsUnlocked,
    required this.achievementsTotal,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
      tier: json['tier']?.toString() ?? 'Seedling',
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      xpIntoLevel: (json['xp_into_level'] as num?)?.toInt() ?? 0,
      xpForNextLevel: (json['xp_for_next_level'] as num?)?.toInt() ?? 100,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      achievementsUnlocked:
          (json['achievements_unlocked'] as num?)?.toInt() ?? 0,
      achievementsTotal: (json['achievements_total'] as num?)?.toInt() ?? 0,
    );
  }

  double get progressFraction {
    if (xpForNextLevel <= 0) return 1.0;
    final f = xpIntoLevel / xpForNextLevel;
    return f.clamp(0.0, 1.0);
  }
}

import '../core/constants.dart';

/// User profile + level + streak summary, mirrored from `GET /api/profile/`.
class UserProfile {
  final String username;
  final String email;
  final String? avatarUrl;
  final int level;
  final String tier;
  final int xp;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int currentStreak;
  final int longestStreak;
  final int seeds;
  final int achievementsUnlocked;
  final int achievementsTotal;

  const UserProfile({
    required this.username,
    required this.email,
    this.avatarUrl,
    required this.level,
    required this.tier,
    required this.xp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.currentStreak,
    required this.longestStreak,
    this.seeds = 0,
    required this.achievementsUnlocked,
    required this.achievementsTotal,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatarUrl: _absoluteUrl(json['avatar']),
      level: (json['level'] as num?)?.toInt() ?? 1,
      tier: json['tier']?.toString() ?? 'Seedling',
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      xpIntoLevel: (json['xp_into_level'] as num?)?.toInt() ?? 0,
      xpForNextLevel: (json['xp_for_next_level'] as num?)?.toInt() ?? 100,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      seeds: (json['seeds'] as num?)?.toInt() ?? 0,
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

/// Absolutize a relative `/media/...` URL returned by Django (same convention
/// as plant.dart / post.dart).
String? _absoluteUrl(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('/')) return '${AppConstants.mediaHost}$s';
  return '${AppConstants.mediaHost}/$s';
}

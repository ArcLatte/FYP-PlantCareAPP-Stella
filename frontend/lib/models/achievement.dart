import 'package:flutter/material.dart';

/// A badge definition + this user's unlock state. Mirrors entries in
/// `GET /api/achievements/`. Also used for the `unlocked` items inside
/// care/scan/login response payloads (where `unlocked`/`isPinned` aren't
/// present — they default to true/false).
class Achievement {
  final String code;
  final String name;
  final String description;
  final String icon; // Material icon name string from the backend
  final String tier; // 'bronze' | 'silver' | 'gold'
  final int xpReward;
  final bool unlocked;
  final bool isPinned;
  final DateTime? unlockedAt;

  const Achievement({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.tier,
    required this.xpReward,
    required this.unlocked,
    required this.isPinned,
    this.unlockedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    final ts = json['unlocked_at']?.toString();
    return Achievement(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'emoji_events',
      tier: json['tier']?.toString() ?? 'bronze',
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 0,
      // Achievements list rows include `unlocked`; toast payloads omit
      // it (a toast item is, by definition, just-unlocked).
      unlocked: json['unlocked'] is bool ? json['unlocked'] as bool : true,
      isPinned: json['is_pinned'] == true,
      unlockedAt: (ts == null || ts.isEmpty) ? null : DateTime.tryParse(ts),
    );
  }

  /// Tier-tinted accent color used for the badge background + level pip.
  Color get tierColor {
    switch (tier) {
      case 'gold':
        return const Color(0xFFE5A722);
      case 'silver':
        return const Color(0xFF9AA5B1);
      case 'bronze':
      default:
        return const Color(0xFFB87333);
    }
  }

  String get tierLabel {
    if (tier.isEmpty) return '';
    return tier[0].toUpperCase() + tier.substring(1);
  }

  /// Map the backend's icon-name string to an actual [IconData]. The set is
  /// small and matches what `seed_achievements` writes — extend when new
  /// achievement codes ship with new icons.
  IconData get iconData {
    switch (icon) {
      case 'eco':
        return Icons.eco_rounded;
      case 'local_florist':
        return Icons.local_florist_rounded;
      case 'park':
        return Icons.park_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'shower':
        return Icons.shower_rounded;
      case 'compost':
        return Icons.compost_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'whatshot':
        return Icons.whatshot_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      case 'document_scanner':
        return Icons.document_scanner_rounded;
      case 'biotech':
        return Icons.biotech_rounded;
      case 'diversity_3':
        return Icons.diversity_3_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }
}

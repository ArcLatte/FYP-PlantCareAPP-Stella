import 'package:flutter/material.dart';
import 'achievement.dart';

/// Disc silhouette of a medal. Series in the same achievement category
/// share a shape: growing your collection = shield, daily care = circle,
/// streaks = hexagon, scanning/health = seal, progression = diamond.
enum MedalShape { circle, shield, hexagon, seal, diamond }

/// Frontend grouping of achievement codes into leveled medal series.
/// Purely presentational: the backend still tracks 24 independent
/// achievements; the medal book shows each series as ONE medal whose star
/// count and metal upgrade as its levels unlock.
class MedalSeriesSpec {
  final String id;
  final String name;
  final List<String> codes; // level order, index 0 = level 1
  final MedalShape shape;
  const MedalSeriesSpec(this.id, this.name, this.codes, this.shape);
}

const kMedalSeriesSpecs = <MedalSeriesSpec>[
  // Growth — shield
  MedalSeriesSpec('gardener', 'Gardener', [
    'first_plant',
    'garden_of_five',
    'green_collector',
    'grand_garden',
  ], MedalShape.shield),
  // Daily care — circle
  MedalSeriesSpec('waterer', 'Waterer', [
    'first_water',
    'hydration_hero',
    'water_centurion',
  ], MedalShape.circle),
  MedalSeriesSpec('fertilizer', 'Fertilizer', [
    'first_fertilize',
    'fertilizer_fanatic',
  ], MedalShape.circle),
  MedalSeriesSpec('mister', 'Mister', [
    'first_mist',
    'mist_maestro',
  ], MedalShape.circle),
  // Streaks — hexagon
  MedalSeriesSpec('streak', 'Streak Keeper', [
    'streak_3',
    'streak_7',
    'streak_14',
    'streak_30',
    'streak_100',
  ], MedalShape.hexagon),
  // Scanning & plant health — seal
  MedalSeriesSpec('scanner', 'Plant Doctor', [
    'first_scan',
    'scan_addict',
  ], MedalShape.seal),
  MedalSeriesSpec('spotter', 'Disease Spotter', ['disease_spotter'],
      MedalShape.seal),
  MedalSeriesSpec('clean_bill', 'Clean Bill', ['clean_bill'],
      MedalShape.seal),
  // Variety & progression — diamond
  MedalSeriesSpec('botanist', 'Botanist', [
    'species_explorer',
    'species_master',
  ], MedalShape.diamond),
  MedalSeriesSpec('rising', 'Rising Star', [
    'level_5',
    'level_10',
  ], MedalShape.diamond),
];

/// Medal metal stages, in upgrade order.
enum MedalMetal { locked, bronze, silver, gold, amethyst, diamond }

extension MedalMetalColors on MedalMetal {
  /// Light → dark gradient pair for the disc.
  (Color, Color) get gradient {
    switch (this) {
      case MedalMetal.locked:
        return (const Color(0xFFD8D8D2), const Color(0xFFB5B5AD));
      case MedalMetal.bronze:
        return (const Color(0xFFCD8A4D), const Color(0xFF8C5A2B));
      case MedalMetal.silver:
        return (const Color(0xFFD7DEE8), const Color(0xFF8F99A6));
      case MedalMetal.gold:
        return (const Color(0xFFF7D774), const Color(0xFFC9971C));
      case MedalMetal.amethyst:
        return (const Color(0xFFC49BEF), const Color(0xFF7E4DBF));
      case MedalMetal.diamond:
        return (const Color(0xFFB5EBF2), const Color(0xFF5BB7C9));
    }
  }

  /// Representative solid color (glows, ribbons, accents).
  Color get color => gradient.$2;

  String get label {
    switch (this) {
      case MedalMetal.locked:
        return 'Locked';
      case MedalMetal.bronze:
        return 'Bronze';
      case MedalMetal.silver:
        return 'Silver';
      case MedalMetal.gold:
        return 'Gold';
      case MedalMetal.amethyst:
        return 'Amethyst';
      case MedalMetal.diamond:
        return 'Diamond';
    }
  }
}

/// One medal in the book: a spec resolved against the user's fetched
/// achievement list.
class MedalSeries {
  final String id;
  final String name;
  final MedalShape shape;

  /// Achievements in level order. Specs reference seeded codes; any the
  /// backend didn't return are skipped.
  final List<Achievement> levels;

  MedalSeries({
    required this.id,
    required this.name,
    required this.levels,
    this.shape = MedalShape.circle,
  });

  /// Group [all] into series. Codes not covered by any spec become
  /// singleton series so new backend achievements never silently vanish.
  static List<MedalSeries> fromAchievements(List<Achievement> all) {
    final byCode = {for (final a in all) a.code: a};
    final covered = <String>{};
    final result = <MedalSeries>[];

    for (final spec in kMedalSeriesSpecs) {
      final levels = [
        for (final code in spec.codes)
          if (byCode.containsKey(code)) byCode[code]!,
      ];
      covered.addAll(spec.codes);
      if (levels.isNotEmpty) {
        result.add(MedalSeries(
          id: spec.id,
          name: spec.name,
          levels: levels,
          shape: spec.shape,
        ));
      }
    }
    for (final a in all) {
      if (!covered.contains(a.code)) {
        result.add(MedalSeries(id: a.code, name: a.name, levels: [a]));
      }
    }
    return result;
  }

  /// Highest consecutive unlocked level (levels unlock in order by
  /// design, but count defensively in case of out-of-order data).
  int get level => levels.where((a) => a.unlocked).length;
  int get maxLevel => levels.length;
  bool get anyUnlocked => level > 0;
  bool get completed => level == maxLevel;

  /// Highest unlocked achievement (for pinning + unlock dates).
  Achievement? get current => level > 0 ? levels[level - 1] : null;

  /// Next achievement to earn, if any.
  Achievement? get next => completed ? null : levels[level];

  /// Metal for the current level. Singletons respect their backend tier
  /// so a gold one-off achievement still reads as gold.
  MedalMetal get metal {
    if (level == 0) return MedalMetal.locked;
    if (maxLevel == 1) {
      switch (levels.first.tier) {
        case 'gold':
          return MedalMetal.gold;
        case 'silver':
          return MedalMetal.silver;
        default:
          return MedalMetal.bronze;
      }
    }
    const ladder = [
      MedalMetal.bronze,
      MedalMetal.silver,
      MedalMetal.gold,
      MedalMetal.amethyst,
      MedalMetal.diamond,
    ];
    return ladder[(level - 1).clamp(0, ladder.length - 1)];
  }

  /// Icon: the series' top achievement defines the family glyph.
  IconData get icon => levels.last.iconData;

  /// Progress fraction toward the next level (null when complete or the
  /// backend sent no progress data).
  double? get nextProgressFraction => next?.progressFraction;
}

// ─── Categories (gacha-style achievement series) ─────────────────

/// One themed chapter of the achievement book, Genshin-style: a banner
/// grouping several medal series. Completing every achievement inside
/// unlocks the category's namecard (a profile-card background).
class MedalCategorySpec {
  final String id;
  final String name;
  final String tagline;
  final IconData icon;
  final List<String> seriesIds; // MedalSeriesSpec ids in display order
  final String namecardId; // ProfileCardTheme id awarded at 100%
  const MedalCategorySpec(
    this.id,
    this.name,
    this.tagline,
    this.icon,
    this.seriesIds,
    this.namecardId,
  );
}

const kMedalCategorySpecs = <MedalCategorySpec>[
  MedalCategorySpec(
    'growth',
    'The Verdant Path',
    'Grow your garden, one pot at a time.',
    Icons.park_rounded,
    ['gardener'],
    'nc_verdant',
  ),
  MedalCategorySpec(
    'care',
    'Tender Hands',
    'Water, feed and mist — every single day.',
    Icons.water_drop_rounded,
    ['waterer', 'fertilizer', 'mister'],
    'nc_rain',
  ),
  MedalCategorySpec(
    'streak',
    'The Eternal Flame',
    'Never let the streak go out.',
    Icons.local_fire_department_rounded,
    ['streak'],
    'nc_hive',
  ),
  MedalCategorySpec(
    'health',
    'The Keen Eye',
    'Scan, diagnose, and keep every leaf healthy.',
    Icons.biotech_rounded,
    ['scanner', 'spotter', 'clean_bill'],
    'nc_lens',
  ),
  MedalCategorySpec(
    'mastery',
    'Ascension',
    'Master new species and rise through the ranks.',
    Icons.rocket_launch_rounded,
    ['botanist', 'rising'],
    'nc_summit',
  ),
];

/// A category resolved against the user's fetched series.
class MedalCategory {
  final MedalCategorySpec spec;
  final List<MedalSeries> series;
  MedalCategory({required this.spec, required this.series});

  int get earned =>
      series.fold(0, (sum, s) => sum + s.level);
  int get total =>
      series.fold(0, (sum, s) => sum + s.maxLevel);
  double get fraction => total == 0 ? 0.0 : earned / total;
  bool get completed => total > 0 && earned == total;

  /// Group [all] series into categories. Series not claimed by any spec
  /// land in a trailing "Wonders of the Garden" catch-all so new backend
  /// achievements never silently vanish.
  static List<MedalCategory> fromSeries(List<MedalSeries> all) {
    final bySeriesId = {for (final s in all) s.id: s};
    final covered = <String>{};
    final result = <MedalCategory>[];
    for (final spec in kMedalCategorySpecs) {
      final members = [
        for (final id in spec.seriesIds)
          if (bySeriesId.containsKey(id)) bySeriesId[id]!,
      ];
      covered.addAll(spec.seriesIds);
      if (members.isNotEmpty) {
        result.add(MedalCategory(spec: spec, series: members));
      }
    }
    final leftovers =
        [for (final s in all) if (!covered.contains(s.id)) s];
    if (leftovers.isNotEmpty) {
      result.add(MedalCategory(
        spec: const MedalCategorySpec(
          'wonders',
          'Wonders of the Garden',
          'Curious feats beyond the beaten path.',
          Icons.auto_awesome_rounded,
          [],
          'nc_wonders',
        ),
        series: leftovers,
      ));
    }
    return result;
  }
}

/// Series position of a single achievement, resolved from the static spec
/// alone — used by the unlock reveal, which only has the just-unlocked
/// achievement (not the full fetched list).
({
  String seriesName,
  int level,
  int maxLevel,
  MedalMetal metal,
  MedalShape shape,
}) medalInfoFor(Achievement a) {
  for (final spec in kMedalSeriesSpecs) {
    final idx = spec.codes.indexOf(a.code);
    if (idx == -1) continue;
    final level = idx + 1;
    final MedalMetal metal;
    if (spec.codes.length == 1) {
      metal = switch (a.tier) {
        'gold' => MedalMetal.gold,
        'silver' => MedalMetal.silver,
        _ => MedalMetal.bronze,
      };
    } else {
      const ladder = [
        MedalMetal.bronze,
        MedalMetal.silver,
        MedalMetal.gold,
        MedalMetal.amethyst,
        MedalMetal.diamond,
      ];
      metal = ladder[(level - 1).clamp(0, ladder.length - 1)];
    }
    return (
      seriesName: spec.name,
      level: level,
      maxLevel: spec.codes.length,
      metal: metal,
      shape: spec.shape,
    );
  }
  // Unknown code → singleton fallback keyed off the backend tier.
  return (
    seriesName: a.name,
    level: 1,
    maxLevel: 1,
    metal: switch (a.tier) {
      'gold' => MedalMetal.gold,
      'silver' => MedalMetal.silver,
      _ => MedalMetal.bronze,
    },
    shape: MedalShape.circle,
  );
}

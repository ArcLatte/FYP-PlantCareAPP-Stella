import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tier_frame.dart';

/// Gacha-style illustrated backgrounds for the profile hero card.
///
/// One theme per level tier — each is a code-drawn scene (sky wash, layered
/// hills, and a tier-flavored motif) so no image assets are needed. Themes
/// unlock with their tier: reaching Sapling unlocks the "Deep Forest" card,
/// and the user can equip any unlocked theme from the picker sheet.
enum CardMotif {
  meadow, //   Seedling — tiny sprouts dotting the hill
  fields, //   Sprout — drifting leaves over rolling fields
  forest, //   Sapling — pine silhouettes
  trellis, //  Gardener — lattice + climbing vine
  moonlit, //  Cultivator — crescent moon + stars
  botanical, //Botanist — big outlined leaves
  gilded, //   Plantsmith — forge rays + emblem ring
  radiant, //  Garden Sage — rays, rings and sparkles
  // Namecard motifs — awarded by completing an achievement category.
  verdant, //  The Verdant Path — great tree + drifting leaves
  rain, //     Tender Hands — falling rain + droplets
  hive, //     The Eternal Flame — honeycomb + rising embers
  lens, //     The Keen Eye — concentric lens rings + ticks
  summit, //   Ascension — mountain peaks + rising sun
  wonders, //  Wonders of the Garden — swirl of sparkles
  // Shop-exclusive namecard motifs — bought with seeds in the Seed Shop.
  sakura, //   Sakura Drift — blossom branch + drifting petals
  koi, //      Koi Pond — ripples, lily pads and a koi
  aurora, //   Aurora Peaks — light ribbons over night mountains
}

/// SharedPreferences key holding the chosen profile-card theme id (or
/// 'auto'). Shared by the profile picker and the Seed Shop's namecard
/// "Use" action so both write the same choice.
const String kCardThemePrefKey = 'profile_card_theme';

class ProfileCardTheme {
  final String id;
  final String name;
  final int tierIndex; // unlocked once TierFrame.tierIndex(tier) >= this
  final Color skyTop;
  final Color skyBottom;
  final Color hillBack;
  final Color hillFront;
  final Color accent;
  final CardMotif motif;

  /// When set, this theme is a namecard: it unlocks by completing the
  /// achievement category with this display name (not by tier).
  final String? namecardOf;

  /// True for namecards sold in the Seed Shop: they unlock by purchase
  /// (ownership flows into the same unlocked-namecards set) instead of by
  /// tier or achievements.
  final bool shopExclusive;

  const ProfileCardTheme({
    required this.id,
    required this.name,
    required this.tierIndex,
    required this.skyTop,
    required this.skyBottom,
    required this.hillBack,
    required this.hillFront,
    required this.accent,
    required this.motif,
    this.namecardOf,
    this.shopExclusive = false,
  });

  bool get isNamecard => namecardOf != null || shopExclusive;

  /// Name of the tier that unlocks this theme.
  String get tierName => const [
        'Seedling',
        'Sprout',
        'Sapling',
        'Gardener',
        'Cultivator',
        'Botanist',
        'Plantsmith',
        'Garden Sage',
      ][tierIndex];
}

/// All card themes, index-aligned with the tier ladder.
const kProfileCardThemes = <ProfileCardTheme>[
  ProfileCardTheme(
    id: 'meadow',
    name: 'Morning Meadow',
    tierIndex: 0,
    skyTop: Color(0xFF9CCDAA),
    skyBottom: Color(0xFF63A87C),
    hillBack: Color(0xFF579B70),
    hillFront: Color(0xFF447F5B),
    accent: Color(0xFFEAF6E2),
    motif: CardMotif.meadow,
  ),
  ProfileCardTheme(
    id: 'fields',
    name: 'Fresh Fields',
    tierIndex: 1,
    skyTop: Color(0xFF7CC98F),
    skyBottom: Color(0xFF44A06B),
    hillBack: Color(0xFF3B8F5F),
    hillFront: Color(0xFF2E734C),
    accent: Color(0xFFD9F2C8),
    motif: CardMotif.fields,
  ),
  ProfileCardTheme(
    id: 'forest',
    name: 'Deep Forest',
    tierIndex: 2,
    skyTop: Color(0xFF5FA97C),
    skyBottom: Color(0xFF2E6E4C),
    hillBack: Color(0xFF275F42),
    hillFront: Color(0xFF1E4D35),
    accent: Color(0xFFBFE8C9),
    motif: CardMotif.forest,
  ),
  ProfileCardTheme(
    id: 'trellis',
    name: 'Teal Trellis',
    tierIndex: 3,
    skyTop: Color(0xFF4FB8AC),
    skyBottom: Color(0xFF23837A),
    hillBack: Color(0xFF1F746D),
    hillFront: Color(0xFF175D58),
    accent: Color(0xFFC8F0E8),
    motif: CardMotif.trellis,
  ),
  ProfileCardTheme(
    id: 'moonlit',
    name: 'Moonlit Garden',
    tierIndex: 4,
    skyTop: Color(0xFF7C90A6),
    skyBottom: Color(0xFF465A72),
    hillBack: Color(0xFF3D5064),
    hillFront: Color(0xFF2F3F51),
    accent: Color(0xFFEAF0FA),
    motif: CardMotif.moonlit,
  ),
  ProfileCardTheme(
    id: 'botanical',
    name: 'Sky Botanica',
    tierIndex: 5,
    skyTop: Color(0xFF6FB4E4),
    skyBottom: Color(0xFF3A7DB4),
    hillBack: Color(0xFF33709F),
    hillFront: Color(0xFF285A83),
    accent: Color(0xFFDDF0FF),
    motif: CardMotif.botanical,
  ),
  ProfileCardTheme(
    id: 'gilded',
    name: 'Gilded Forge',
    tierIndex: 6,
    skyTop: Color(0xFFE8B84E),
    skyBottom: Color(0xFFB07E1A),
    hillBack: Color(0xFFA07016),
    hillFront: Color(0xFF7F5811),
    accent: Color(0xFFFFF2C8),
    motif: CardMotif.gilded,
  ),
  ProfileCardTheme(
    id: 'radiant',
    name: 'Radiant Grove',
    tierIndex: 7,
    skyTop: Color(0xFFFFD873),
    skyBottom: Color(0xFFC08A1E),
    hillBack: Color(0xFFA9761A),
    hillFront: Color(0xFF875D12),
    accent: Color(0xFFFFFBEA),
    motif: CardMotif.radiant,
  ),
];

/// Namecard themes, keyed to achievement categories (see
/// `MedalCategorySpec.namecardId`). Completing every achievement in a
/// category unlocks its namecard as an extra card background.
const kNamecardThemes = <ProfileCardTheme>[
  ProfileCardTheme(
    id: 'nc_verdant',
    name: 'The Verdant Path',
    namecardOf: 'The Verdant Path',
    tierIndex: 0,
    skyTop: Color(0xFFF7F0D2),
    skyBottom: Color(0xFF74AE89),
    hillBack: Color(0xFF84BB97),
    hillFront: Color(0xFF639D78),
    accent: Color(0xFFF7DD8A),
    motif: CardMotif.verdant,
  ),
  ProfileCardTheme(
    id: 'nc_rain',
    name: 'Tender Hands',
    namecardOf: 'Tender Hands',
    tierIndex: 0,
    skyTop: Color(0xFFC2E0F2),
    skyBottom: Color(0xFF84AACA),
    hillBack: Color(0xFF6C94B2),
    hillFront: Color(0xFF5C84A2),
    accent: Color(0xFFD6EDFA),
    motif: CardMotif.rain,
  ),
  ProfileCardTheme(
    id: 'nc_hive',
    name: 'The Eternal Flame',
    namecardOf: 'The Eternal Flame',
    tierIndex: 0,
    skyTop: Color(0xFF6E4E6A),
    skyBottom: Color(0xFFEAB078),
    hillBack: Color(0xFFB47862),
    hillFront: Color(0xFF5E4A40),
    accent: Color(0xFFF7DE9A),
    motif: CardMotif.hive,
  ),
  ProfileCardTheme(
    id: 'nc_lens',
    name: 'The Keen Eye',
    namecardOf: 'The Keen Eye',
    tierIndex: 0,
    skyTop: Color(0xFF48647E),
    skyBottom: Color(0xFF649E94),
    hillBack: Color(0xFF56847C),
    hillFront: Color(0xFF3A5468),
    accent: Color(0xFFB4E6B0),
    motif: CardMotif.lens,
  ),
  ProfileCardTheme(
    id: 'nc_summit',
    name: 'Ascension',
    namecardOf: 'Ascension',
    tierIndex: 0,
    skyTop: Color(0xFF5E5088),
    skyBottom: Color(0xFFEFC494),
    hillBack: Color(0xFF6E6098),
    hillFront: Color(0xFF524678),
    accent: Color(0xFFF2C878),
    motif: CardMotif.summit,
  ),
  ProfileCardTheme(
    id: 'nc_wonders',
    name: 'Wonders of the Garden',
    namecardOf: 'Wonders of the Garden',
    tierIndex: 0,
    skyTop: Color(0xFF5A5088),
    skyBottom: Color(0xFFC493B4),
    hillBack: Color(0xFFAEA2CE),
    hillFront: Color(0xFFA093C2),
    accent: Color(0xFFE3C878),
    motif: CardMotif.wonders,
  ),
];

/// Namecards sold in the Seed Shop (matched by the `theme_id` in the shop
/// cosmetic's payload). Owning the cosmetic unlocks the theme in the card
/// picker, exactly like an achievement namecard.
const kShopNamecardThemes = <ProfileCardTheme>[
  ProfileCardTheme(
    id: 'nc_sakura',
    name: 'Sakura Drift',
    shopExclusive: true,
    tierIndex: 0,
    skyTop: Color(0xFFF7E3EC),
    skyBottom: Color(0xFFD898B8),
    hillBack: Color(0xFFC48CAC),
    hillFront: Color(0xFFA87096),
    accent: Color(0xFFF7C8DC),
    motif: CardMotif.sakura,
  ),
  ProfileCardTheme(
    id: 'nc_koi',
    name: 'Koi Pond',
    shopExclusive: true,
    tierIndex: 0,
    skyTop: Color(0xFF7FC8C4),
    skyBottom: Color(0xFF35707E),
    hillBack: Color(0xFF2E6270),
    hillFront: Color(0xFF26525E),
    accent: Color(0xFFF2B279),
    motif: CardMotif.koi,
  ),
  ProfileCardTheme(
    id: 'nc_aurora',
    name: 'Aurora Peaks',
    shopExclusive: true,
    tierIndex: 0,
    skyTop: Color(0xFF1E2448),
    skyBottom: Color(0xFF4A3E78),
    hillBack: Color(0xFF322A58),
    hillFront: Color(0xFF221E40),
    accent: Color(0xFF7FE8C8),
    motif: CardMotif.aurora,
  ),
];

/// Theme lookup by id (tier scenes + namecards + shop namecards), or null.
ProfileCardTheme? profileCardThemeById(String? id) {
  for (final t in kProfileCardThemes) {
    if (t.id == id) return t;
  }
  for (final t in kNamecardThemes) {
    if (t.id == id) return t;
  }
  for (final t in kShopNamecardThemes) {
    if (t.id == id) return t;
  }
  return null;
}

/// Resolves the active theme: an explicitly chosen unlocked theme wins
/// (tier scenes unlock by tier, namecards by completed achievement
/// categories), otherwise the card follows the user's current tier.
ProfileCardTheme resolveProfileCardTheme(
  String? chosenId,
  String tier, {
  Set<String> unlockedNamecards = const {},
}) {
  final tierIdx = TierFrame.tierIndex(tier);
  final chosen = profileCardThemeById(chosenId);
  if (chosen != null) {
    final unlocked = chosen.isNamecard
        ? unlockedNamecards.contains(chosen.id)
        : chosen.tierIndex <= tierIdx;
    if (unlocked) return chosen;
  }
  return kProfileCardThemes[tierIdx];
}

/// Paints one full card scene: sky gradient, two hill bands, the theme's
/// motif, and a soft darkening toward the bottom so white text stays
/// readable on every palette.
class ProfileCardScenePainter extends CustomPainter {
  final ProfileCardTheme theme;

  const ProfileCardScenePainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    if (theme.isNamecard) {
      // Namecards are full custom illustrations: their own multi-stop
      // palettes and unique grounds, no shared sky/hill template.
      _namecardScene(canvas, size);
    } else {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.skyTop, theme.skyBottom],
          ).createShader(rect),
      );

      _motif(canvas, size);

      // Hill bands ground the card (and the companion standing on it).
      canvas.drawPath(
        _hill(w, h, 0.80, 0.10),
        Paint()..color = theme.hillBack,
      );
      canvas.drawPath(
        _hill(w, h, 0.90, 0.07),
        Paint()..color = theme.hillFront,
      );
    }

    // Legibility scrim.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.06),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.20),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
  }

  /// Gentle two-bump hill whose ridge sits at [ridge] (height fraction),
  /// bumping up by [lift].
  Path _hill(double w, double h, double ridge, double lift) {
    final y = h * ridge;
    final rise = h * lift;
    return Path()
      ..moveTo(0, y)
      ..quadraticBezierTo(w * 0.25, y - rise, w * 0.5, y - rise * 0.35)
      ..quadraticBezierTo(w * 0.75, y + rise * 0.25, w, y - rise * 0.55)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  void _motif(Canvas canvas, Size size) {
    switch (theme.motif) {
      case CardMotif.meadow:
        _meadow(canvas, size);
      case CardMotif.fields:
        _fields(canvas, size);
      case CardMotif.forest:
        _forest(canvas, size);
      case CardMotif.trellis:
        _trellis(canvas, size);
      case CardMotif.moonlit:
        _moonlit(canvas, size);
      case CardMotif.botanical:
        _botanical(canvas, size);
      case CardMotif.gilded:
        _gilded(canvas, size);
      case CardMotif.radiant:
        _radiant(canvas, size);
      // Namecard motifs paint complete scenes (own background included),
      // normally routed through _namecardScene.
      case CardMotif.verdant:
        _sceneVerdant(canvas, size);
      case CardMotif.rain:
        _sceneRain(canvas, size);
      case CardMotif.hive:
        _sceneFlame(canvas, size);
      case CardMotif.lens:
        _sceneLens(canvas, size);
      case CardMotif.summit:
        _sceneSummit(canvas, size);
      case CardMotif.wonders:
        _sceneWonders(canvas, size);
      case CardMotif.sakura:
        _sceneSakura(canvas, size);
      case CardMotif.koi:
        _sceneKoi(canvas, size);
      case CardMotif.aurora:
        _sceneAurora(canvas, size);
    }
  }

  // ─── Namecard scenes ─────────────────────────────────────────
  // Full illustrations, one per achievement series. Unlike the tier
  // scenes these own the whole canvas: multi-stop palettes with more
  // than one hue, unique grounds, and gacha-style flourishes.

  void _namecardScene(Canvas canvas, Size size) {
    switch (theme.motif) {
      case CardMotif.verdant:
        _sceneVerdant(canvas, size);
      case CardMotif.rain:
        _sceneRain(canvas, size);
      case CardMotif.hive:
        _sceneFlame(canvas, size);
      case CardMotif.lens:
        _sceneLens(canvas, size);
      case CardMotif.summit:
        _sceneSummit(canvas, size);
      case CardMotif.wonders:
        _sceneWonders(canvas, size);
      case CardMotif.sakura:
        _sceneSakura(canvas, size);
      case CardMotif.koi:
        _sceneKoi(canvas, size);
      case CardMotif.aurora:
        _sceneAurora(canvas, size);
      default:
        // Tier motif mislabelled as a namecard — paint the plain sky so
        // the card never renders empty.
        _bg(canvas, size, [theme.skyTop, theme.skyBottom]);
    }
  }

  // Multi-stop vertical background wash.
  void _bg(Canvas canvas, Size size, List<Color> colors,
      {List<double>? stops}) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(rect),
    );
  }

  // Soft cumulus puff.
  void _cloud(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(0, r * 0.35),
          width: r * 3.3,
          height: r * 1.3),
      paint,
    );
    canvas.drawCircle(c.translate(-r * 0.95, 0), r * 0.72, paint);
    canvas.drawCircle(c, r, paint);
    canvas.drawCircle(c.translate(r * 0.95, r * 0.08), r * 0.66, paint);
  }

  // Decorative filigree curl, like gacha namecard backgrounds.
  void _curl(Canvas canvas, Offset c, double r0, Paint paint) {
    final path = Path()..moveTo(c.dx + r0, c.dy);
    const steps = 36;
    for (var i = 1; i <= steps; i++) {
      final a = i / steps * math.pi * 3.0;
      final r = r0 * (1 - 0.75 * i / steps);
      path.lineTo(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    }
    canvas.drawPath(path, paint);
  }

  // Four-point sparkle.
  void _spark(Canvas canvas, Offset c, double s, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - s * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + s * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - s * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s * 2)
        ..close(),
      paint,
    );
  }

  // Tapered comet streak between two points.
  void _streak(Canvas canvas, Offset a, Offset b, double w, Paint paint) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final n = Offset(-d.dy / len * w, d.dx / len * w);
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, b.dx, b.dy)
        ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, a.dx, a.dy)
        ..close(),
      paint,
    );
  }

  // The Verdant Path: dawn light over a meadow, a winding footpath
  // leading to the horizon, a grand oak, and blossom petals adrift.
  void _sceneVerdant(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _bg(
      canvas,
      size,
      const [Color(0xFFF7F0D2), Color(0xFFC2E3B0), Color(0xFF74AE89)],
      stops: const [0.0, 0.45, 1.0],
    );

    // Morning sun with a soft halo.
    final sun = Offset(w * 0.16, h * 0.20);
    canvas.drawCircle(
        sun, h * 0.24, Paint()..color = const Color(0x40F7DD8A));
    canvas.drawCircle(
        sun, h * 0.12, Paint()..color = const Color(0xE6F7DD8A));

    // Distant canopy line.
    final far = Paint()..color = const Color(0x73689E7E);
    final rng = math.Random(31);
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(
        Offset((0.02 + i * 0.12) * w, h * (0.56 + rng.nextDouble() * 0.03)),
        h * (0.05 + rng.nextDouble() * 0.04),
        far,
      );
    }

    // Meadow bands in two greens.
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.66)
        ..quadraticBezierTo(w * 0.35, h * 0.60, w, h * 0.64)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF84BB97),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.84)
        ..quadraticBezierTo(w * 0.55, h * 0.78, w, h * 0.86)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF639D78),
    );

    // The winding path.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.20, h)
        ..quadraticBezierTo(w * 0.52, h * 0.86, w * 0.63, h * 0.645)
        ..lineTo(w * 0.685, h * 0.645)
        ..quadraticBezierTo(w * 0.60, h * 0.90, w * 0.44, h)
        ..close(),
      Paint()..color = const Color(0xFFF0E8C8),
    );

    // Grand oak on the right.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.83, h * 0.76)
        ..quadraticBezierTo(w * 0.845, h * 0.50, w * 0.84, h * 0.36)
        ..lineTo(w * 0.865, h * 0.36)
        ..quadraticBezierTo(w * 0.875, h * 0.52, w * 0.90, h * 0.76)
        ..close(),
      Paint()..color = const Color(0xFF8A6E58),
    );
    final leaf = Paint()..color = const Color(0xFF52886A);
    for (final (fx, fy, fr) in const [
      (0.85, 0.26, 0.15),
      (0.74, 0.33, 0.10),
      (0.95, 0.32, 0.10),
      (0.85, 0.40, 0.11),
    ]) {
      canvas.drawCircle(Offset(w * fx, h * fy), h * fr, leaf);
    }

    // Blossom petals on the breeze + sparkles.
    final petal = Paint()..color = const Color(0xCCF2A8C0);
    final rng2 = math.Random(8);
    for (var i = 0; i < 8; i++) {
      final c = Offset(
          rng2.nextDouble() * w, (0.10 + rng2.nextDouble() * 0.5) * h);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rng2.nextDouble() * math.pi);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 7, height: 4), petal);
      canvas.restore();
    }
    _spark(canvas, Offset(w * 0.36, h * 0.24), 2.4,
        Paint()..color = Colors.white70);
    _spark(canvas, Offset(w * 0.55, h * 0.40), 1.8,
        Paint()..color = Colors.white54);
  }

  // Tender Hands: a watering can up in the clouds, a rainbow, falling
  // drops, and a pond with ripples and a lily pad.
  void _sceneRain(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _bg(canvas, size, const [Color(0xFFC2E0F2), Color(0xFF84AACA)]);

    // Rainbow rising behind everything — drawn as top arcs only and
    // clipped above the pond so the bands never spill over the water
    // or wrap around the card edges.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, w, h * 0.76));
    for (final (color, f) in const [
      (Color(0x4DF2B4A2), 0.94),
      (Color(0x4DF2E3B0), 0.87),
      (Color(0x4DA8DFC0), 0.80),
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.25, h * 1.35), radius: h * f),
        -math.pi * 0.80,
        math.pi * 0.60,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = h * 0.05,
      );
    }
    canvas.restore();

    // Cloud shelf + tilted watering can pouring.
    _cloud(canvas, Offset(w * 0.80, h * 0.14), h * 0.10,
        const Color(0xE6FFFFFF));
    _cloud(canvas, Offset(w * 0.12, h * 0.30), h * 0.06,
        const Color(0xB3FFFFFF));
    canvas.save();
    canvas.translate(w * 0.78, h * 0.30);
    canvas.rotate(0.45);
    final can = Paint()..color = const Color(0xFFEFF6FB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset.zero, width: h * 0.30, height: h * 0.20),
        Radius.circular(h * 0.05),
      ),
      can,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-h * 0.13, 0)
        ..lineTo(-h * 0.30, -h * 0.14)
        ..lineTo(-h * 0.13, -h * 0.08)
        ..close(),
      can,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(h * 0.15, -h * 0.10), radius: h * 0.09),
      -math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFEFF6FB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.03,
    );
    canvas.restore();

    // Falling drops along the pour line.
    final rng = math.Random(17);
    for (var i = 0; i < 12; i++) {
      final t = rng.nextDouble();
      final p = Offset(
        w * (0.58 - t * 0.22) + rng.nextDouble() * w * 0.06,
        h * (0.34 + t * 0.42),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: p, width: h * 0.018, height: h * 0.036),
        Paint()
          ..color =
              Colors.white.withValues(alpha: 0.45 + rng.nextDouble() * 0.4),
      );
    }

    // Pond band with ripples and a lily pad.
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.80)
        ..quadraticBezierTo(w * 0.30, h * 0.76, w * 0.55, h * 0.80)
        ..quadraticBezierTo(w * 0.80, h * 0.84, w, h * 0.79)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF5C84A2),
    );
    final ripple = Paint()
      ..color = const Color(0x80C4E0F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final (fx, fy, fw) in const [
      (0.34, 0.88, 0.13),
      (0.58, 0.92, 0.09),
      (0.80, 0.87, 0.11),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * fx, h * fy),
            width: w * fw,
            height: w * fw * 0.28),
        ripple,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.15, h * 0.90),
          width: w * 0.13,
          height: h * 0.045),
      Paint()..color = const Color(0xFF82BC90),
    );
  }

  // The Eternal Flame: a dusk-to-ember sky, a layered flame with gold
  // swash linework, rising sparks, and a charcoal ground.
  void _sceneFlame(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _bg(
      canvas,
      size,
      const [Color(0xFF6E4E6A), Color(0xFFB47862), Color(0xFFEAB078)],
      stops: const [0.0, 0.55, 1.0],
    );

    // Faint honeycomb keepsake, top-left.
    final hexPaint = Paint()
      ..color = const Color(0x2EF7DE9A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const hexR = 11.0;
    for (final (fx, fy) in const [
      (0.10, 0.16),
      (0.155, 0.245),
      (0.045, 0.245),
      (0.10, 0.33),
    ]) {
      final hc = Offset(w * fx, h * fy);
      final hex = Path();
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        final p =
            Offset(hc.dx + hexR * math.cos(a), hc.dy + hexR * math.sin(a));
        i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(hex..close(), hexPaint);
    }

    // The flame, three tongues deep.
    final c = Offset(w * 0.62, h * 0.50);
    void tongue(double r, Color col, double sway) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + sway, c.dy - r * 1.55)
          ..quadraticBezierTo(
              c.dx + r * 0.95, c.dy - r * 0.55, c.dx + r * 0.70, c.dy + r * 0.35)
          ..quadraticBezierTo(
              c.dx + r * 0.45, c.dy + r * 0.95, c.dx, c.dy + r * 0.95)
          ..quadraticBezierTo(
              c.dx - r * 0.75, c.dy + r * 0.95, c.dx - r * 0.70, c.dy + r * 0.15)
          ..quadraticBezierTo(
              c.dx - r * 0.60, c.dy - r * 0.45, c.dx + sway, c.dy - r * 1.55)
          ..close(),
        Paint()..color = col,
      );
    }

    tongue(h * 0.30, const Color(0xFFCE7860), w * 0.02);
    tongue(h * 0.21, const Color(0xFFF0AC70), w * 0.01);
    tongue(h * 0.13, const Color(0xFFF7DE9A), 0);
    canvas.drawCircle(c.translate(0, h * 0.06), h * 0.055,
        Paint()..color = const Color(0xFFFFF4D0));

    // Gold swashes hugging the flame.
    final gold = Paint()
      ..color = const Color(0xFFDCC272)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.012
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: h * 0.36),
        math.pi * 0.35, math.pi * 0.55, false, gold);
    canvas.drawArc(Rect.fromCircle(center: c, radius: h * 0.42),
        math.pi * 0.75, math.pi * 0.35, false, gold);

    // Rising embers.
    final rng = math.Random(7);
    for (var i = 0; i < 10; i++) {
      final p = Offset(
        w * (0.45 + rng.nextDouble() * 0.4),
        h * (0.08 + rng.nextDouble() * 0.35),
      );
      canvas.drawCircle(
        p,
        1.0 + rng.nextDouble() * 2.0,
        Paint()
          ..color = (rng.nextBool()
                  ? const Color(0xFFF7DE9A)
                  : Colors.white)
              .withValues(alpha: 0.35 + rng.nextDouble() * 0.5),
      );
    }
    _spark(canvas, Offset(w * 0.30, h * 0.42), 2.6,
        Paint()..color = const Color(0xCCF7DE9A));

    // Charcoal ground with a gold rim.
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.88)
        ..quadraticBezierTo(w * 0.40, h * 0.82, w, h * 0.87)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF5E4A40),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.88)
        ..quadraticBezierTo(w * 0.40, h * 0.82, w, h * 0.87),
      Paint()
        ..color = const Color(0x88DCC272)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  // The Keen Eye: a night nursery under stars, a golden loupe revealing
  // a bright leaf, scan ticks, fireflies, and a grass silhouette.
  void _sceneLens(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _bg(canvas, size, const [Color(0xFF48647E), Color(0xFF649E94)]);

    // Star field.
    final rng = math.Random(23);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.5),
        0.7 + rng.nextDouble() * 1.2,
        Paint()
          ..color =
              Colors.white.withValues(alpha: 0.25 + rng.nextDouble() * 0.5),
      );
    }

    // Dashed scan line through the loupe.
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.4;
    for (var x = 0.0; x < w; x += 12) {
      canvas.drawLine(
          Offset(x, h * 0.42), Offset(x + 6, h * 0.42), dash);
    }

    final c = Offset(w * 0.63, h * 0.42);
    final r = h * 0.26;
    // Handle first, so the ring overlaps it.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r * 0.9, -r * 0.10, r * 1.05, r * 0.20),
        Radius.circular(r * 0.1),
      ),
      Paint()..color = const Color(0xFFC0A258),
    );
    canvas.restore();
    // Glass — the world inside is brighter.
    canvas.drawCircle(c, r, Paint()..color = const Color(0x59B8EAD8));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final leafLen = r * 1.25;
    canvas.save();
    canvas.translate(c.dx, c.dy + leafLen * 0.45);
    canvas.rotate(-0.25);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(leafLen * 0.45, -leafLen * 0.5, 0, -leafLen)
        ..quadraticBezierTo(-leafLen * 0.45, -leafLen * 0.5, 0, 0)
        ..close(),
      Paint()..color = const Color(0xFFB4E6B0),
    );
    final vein = Paint()
      ..color = const Color(0xFF5E9878)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045;
    canvas.drawLine(Offset.zero, Offset(0, -leafLen * 0.92), vein);
    for (var i = 1; i <= 3; i++) {
      final y = -leafLen * 0.22 * i;
      canvas.drawLine(Offset(0, y),
          Offset(leafLen * 0.18, y - leafLen * 0.10), vein);
      canvas.drawLine(Offset(0, y),
          Offset(-leafLen * 0.18, y - leafLen * 0.10), vein);
    }
    canvas.restore();
    canvas.restore();
    // Gold ring, inner highlight, tick marks.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.035
        ..color = const Color(0xFFDCC272),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.80),
      -math.pi * 0.85,
      math.pi * 0.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.018
        ..strokeCap = StrokeCap.round
        ..color = Colors.white54,
    );
    final tick = Paint()
      ..color = const Color(0xCCDCC272)
      ..strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + math.pi / 4;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * r * 1.12, c.dy + math.sin(a) * r * 1.12),
        Offset(c.dx + math.cos(a) * r * 1.30, c.dy + math.sin(a) * r * 1.30),
        tick,
      );
    }

    // Fireflies.
    for (final (fx, fy) in const [(0.16, 0.60), (0.26, 0.44), (0.10, 0.32)]) {
      final p = Offset(w * fx, h * fy);
      canvas.drawCircle(
          p, 5, Paint()..color = const Color(0x33F7DE9A));
      canvas.drawCircle(
          p, 1.6, Paint()..color = const Color(0xFFF7DE9A));
    }

    // Grass silhouette along the bottom.
    final grass = Paint()..color = const Color(0xFF3A5468);
    canvas.drawRect(Rect.fromLTRB(0, h * 0.93, w, h), grass);
    for (var i = 0; i < 12; i++) {
      final x = i / 12 * w + w * 0.02;
      final bladeH = h * (0.08 + (i % 3) * 0.035);
      canvas.drawPath(
        Path()
          ..moveTo(x, h)
          ..quadraticBezierTo(
              x + w * 0.012, h * 0.93 - bladeH, x + w * 0.030, h * 0.94)
          ..lineTo(x + w * 0.040, h)
          ..close(),
        grass,
      );
    }
  }

  // Ascension: violet-to-gold dusk, comet streaks, a setting sun, and
  // snow-capped ridge lines in three hues.
  void _sceneSummit(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _bg(
      canvas,
      size,
      const [Color(0xFF5E5088), Color(0xFF9C749A), Color(0xFFEFC494)],
      stops: const [0.0, 0.60, 1.0],
    );

    // Stars.
    final rng = math.Random(41);
    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.42),
        0.7 + rng.nextDouble() * 1.1,
        Paint()
          ..color =
              Colors.white.withValues(alpha: 0.30 + rng.nextDouble() * 0.5),
      );
    }

    // Comet streaks climbing the sky.
    _streak(canvas, Offset(w * 0.14, h * 0.16), Offset(w * 0.47, h * 0.34),
        h * 0.030, Paint()..color = Colors.white.withValues(alpha: 0.85));
    _streak(canvas, Offset(w * 0.30, h * 0.10), Offset(w * 0.52, h * 0.22),
        h * 0.018, Paint()..color = Colors.white.withValues(alpha: 0.55));
    _streak(canvas, Offset(w * 0.20, h * 0.30), Offset(w * 0.40, h * 0.42),
        h * 0.012, Paint()..color = const Color(0xAADCC272));
    _spark(canvas, Offset(w * 0.50, h * 0.36), 2.6,
        Paint()..color = Colors.white70);

    // Setting sun on the ridge.
    final sun = Offset(w * 0.62, h * 0.60);
    canvas.drawCircle(
        sun, h * 0.20, Paint()..color = const Color(0x40FFD98A));
    canvas.drawCircle(
        sun, h * 0.11, Paint()..color = const Color(0xFFF7CE7A));

    // Back ridge with snow caps.
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.72)
        ..lineTo(w * 0.18, h * 0.42)
        ..lineTo(w * 0.34, h * 0.66)
        ..lineTo(w * 0.52, h * 0.38)
        ..lineTo(w * 0.72, h * 0.68)
        ..lineTo(w * 0.88, h * 0.50)
        ..lineTo(w, h * 0.66)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF6E6098),
    );
    final snow = Paint()..color = const Color(0xFFF3E9C8);
    for (final (fx, fy) in const [(0.18, 0.42), (0.52, 0.38), (0.88, 0.50)]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * fx - w * 0.035, h * fy + h * 0.065)
          ..lineTo(w * fx, h * fy)
          ..lineTo(w * fx + w * 0.035, h * fy + h * 0.065)
          ..close(),
        snow,
      );
    }

    // Front ridge, darker.
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.86)
        ..lineTo(w * 0.22, h * 0.66)
        ..lineTo(w * 0.44, h * 0.84)
        ..lineTo(w * 0.66, h * 0.62)
        ..lineTo(w * 0.84, h * 0.82)
        ..lineTo(w, h * 0.72)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF524678),
    );
  }

  // Wonders of the Garden: an indigo-rose sky filled with filigree
  // curls, dream clouds, and a comet-koi garden spirit traced in gold.
  void _sceneWonders(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A5088), Color(0xFF7E70A8), Color(0xFFC493B4)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Filigree curls, barely there.
    final curlPaint = Paint()
      ..color = const Color(0x2EDCD2F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    _curl(canvas, Offset(w * 0.12, h * 0.18), h * 0.10, curlPaint);
    _curl(canvas, Offset(w * 0.30, h * 0.08), h * 0.07, curlPaint);
    _curl(canvas, Offset(w * 0.88, h * 0.12), h * 0.09, curlPaint);
    _curl(canvas, Offset(w * 0.70, h * 0.80), h * 0.08, curlPaint);

    // Star dust.
    final rng = math.Random(13);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.7),
        0.7 + rng.nextDouble() * 1.2,
        Paint()
          ..color =
              Colors.white.withValues(alpha: 0.25 + rng.nextDouble() * 0.5),
      );
    }

    // The garden spirit: a comet-koi gliding between the clouds.
    final head = Offset(w * 0.38, h * 0.58);
    _streak(canvas, Offset(w * 0.86, h * 0.22), head, h * 0.085,
        Paint()..color = const Color(0xFF8FC4F2));
    _streak(canvas, Offset(w * 0.80, h * 0.30), head, h * 0.045,
        Paint()..color = const Color(0xFFD6EAFF));
    // Fins flicking off the body.
    _streak(canvas, Offset(w * 0.55, h * 0.36), Offset(w * 0.63, h * 0.52),
        h * 0.020, Paint()..color = const Color(0xCC8FC4F2));
    _streak(canvas, Offset(w * 0.48, h * 0.62), Offset(w * 0.58, h * 0.70),
        h * 0.020, Paint()..color = const Color(0xCC8FC4F2));
    // Gold swash accents tracing the glide.
    final gold = Paint()
      ..color = const Color(0xFFDCC272)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.012
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.58, h * 0.44), radius: h * 0.16),
        math.pi * 0.1,
        math.pi * 0.5,
        false,
        gold);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.44, h * 0.56), radius: h * 0.12),
        math.pi * 0.2,
        math.pi * 0.6,
        false,
        gold);
    // Head glow.
    canvas.drawCircle(
        head, h * 0.09, Paint()..color = const Color(0x338FD9FF));
    canvas.drawCircle(
        head, h * 0.035, Paint()..color = const Color(0xFFD6EAFF));
    _spark(canvas, head.translate(-h * 0.10, h * 0.08), 3,
        Paint()..color = const Color(0xFF9EE3FF));

    // Dream clouds hugging the bottom corners.
    _cloud(canvas, Offset(w * 0.10, h * 0.88), h * 0.11,
        const Color(0xCCAEA2CE));
    _cloud(canvas, Offset(w * 0.30, h * 0.97), h * 0.09,
        const Color(0xCCA093C2));
    _cloud(canvas, Offset(w * 0.90, h * 0.90), h * 0.12,
        const Color(0xCCAEA2CE));
    _cloud(canvas, Offset(w * 0.68, h * 1.00), h * 0.09,
        const Color(0xCCA093C2));
  }

  // ─── Shop namecard scenes ────────────────────────────────────
  // Seed-Shop exclusives: same bespoke-illustration treatment as the
  // achievement namecards, unlocked by purchase instead of progress.

  // Sakura Drift: a blossom branch reaching in from the corner, petals
  // adrift on a warm spring-evening sky.
  void _sceneSakura(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _bg(
      canvas,
      size,
      const [Color(0xFFF9E9EF), Color(0xFFEFC2D6), Color(0xFFD898B8)],
      stops: const [0.0, 0.55, 1.0],
    );

    // Hazy sun low in the sky.
    canvas.drawCircle(Offset(w * 0.24, h * 0.62), h * 0.16,
        Paint()..color = const Color(0x40FFF2D8));
    canvas.drawCircle(Offset(w * 0.24, h * 0.62), h * 0.09,
        Paint()..color = const Color(0xB8FFE8C2));

    // Soft rose hills grounding the card.
    canvas.drawPath(_hill(w, h, 0.84, 0.09),
        Paint()..color = const Color(0xFFC48CAC));
    canvas.drawPath(_hill(w, h, 0.93, 0.06),
        Paint()..color = const Color(0xFFA87096));

    // Branch sweeping in from the top-right corner.
    final branch = Paint()
      ..color = const Color(0xFF6E4A50)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 1.02, h * 0.06)
        ..quadraticBezierTo(w * 0.78, h * 0.14, w * 0.60, h * 0.34),
      branch..strokeWidth = h * 0.030,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.84, h * 0.14)
        ..quadraticBezierTo(w * 0.74, h * 0.30, w * 0.76, h * 0.44),
      branch..strokeWidth = h * 0.018,
    );

    // Blossom clusters along the branch.
    for (final (fx, fy, r) in const [
      (0.62, 0.34, 0.055), (0.70, 0.24, 0.045), (0.80, 0.16, 0.05),
      (0.76, 0.42, 0.042), (0.90, 0.10, 0.045), (0.68, 0.40, 0.032),
    ]) {
      final c = Offset(w * fx, h * fy);
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + i * math.pi * 2 / 5;
        canvas.drawCircle(
          c.translate(math.cos(a) * h * r * 0.85, math.sin(a) * h * r * 0.85),
          h * r * 0.62,
          Paint()..color = const Color(0xFFF7C8DC),
        );
      }
      canvas.drawCircle(
          c, h * r * 0.45, Paint()..color = const Color(0xFFE89CC0));
    }

    // Petals drifting down-wind (toward the lower left).
    final rng = math.Random(27);
    for (var i = 0; i < 12; i++) {
      final c = Offset(
        rng.nextDouble() * w,
        (0.10 + rng.nextDouble() * 0.75) * h,
      );
      final s = h * (0.012 + rng.nextDouble() * 0.014);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.6 + rng.nextDouble() * 1.2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 2.4, height: s * 1.3),
        Paint()
          ..color = const Color(0xFFF4B8D2)
              .withValues(alpha: 0.45 + rng.nextDouble() * 0.4),
      );
      canvas.restore();
    }
    _spark(canvas, Offset(w * 0.16, h * 0.20), 2.6,
        Paint()..color = Colors.white70);
  }

  // Koi Pond: still water seen from above — ripple rings, lily pads and
  // a bright koi gliding through.
  void _sceneKoi(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _bg(
      canvas,
      size,
      const [Color(0xFF8FD0CA), Color(0xFF4E9CA4), Color(0xFF2E6270)],
      stops: const [0.0, 0.55, 1.0],
    );

    // Ripple rings spreading from where the koi broke the surface.
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.30);
    final rc = Offset(w * 0.40, h * 0.46);
    for (final (r, sw) in [(0.10, 0.012), (0.19, 0.009), (0.29, 0.006)]) {
      canvas.drawOval(
        Rect.fromCenter(
            center: rc, width: w * r * 1.6, height: h * r * 1.15),
        ripple..strokeWidth = h * sw,
      );
    }

    // The koi: a tapering comet-body with a flick of tail.
    final head = Offset(w * 0.46, h * 0.42);
    _streak(canvas, Offset(w * 0.24, h * 0.66), head, h * 0.075,
        Paint()..color = const Color(0xFFF2B279));
    _streak(canvas, Offset(w * 0.30, h * 0.60), head, h * 0.040,
        Paint()..color = const Color(0xFFFBE3C4));
    canvas.drawCircle(head, h * 0.045, Paint()..color = const Color(0xFFF2B279));
    canvas.drawCircle(head.translate(-h * 0.012, -h * 0.008), h * 0.016,
        Paint()..color = const Color(0xFFE05B3C));
    // Tail flick.
    _streak(canvas, Offset(w * 0.24, h * 0.66), Offset(w * 0.17, h * 0.76),
        h * 0.022, Paint()..color = const Color(0xCCF2B279));

    // Lily pads: discs with a wedge notch, plus one small lotus.
    for (final (fx, fy, r, a0) in const [
      (0.78, 0.26, 0.11, 0.6), (0.66, 0.72, 0.085, 2.4), (0.16, 0.22, 0.075, 4.0),
    ]) {
      final c = Offset(w * fx, h * fy);
      canvas.drawOval(
        Rect.fromCenter(
            center: c, width: h * r * 2.3, height: h * r * 1.7),
        Paint()..color = const Color(0xFF3E7E58),
      );
      // Notch cut toward the pad's edge.
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a0) * h * r * 1.3,
              c.dy + math.sin(a0) * h * r * 1.0)
          ..lineTo(c.dx + math.cos(a0 + 0.55) * h * r * 1.3,
              c.dy + math.sin(a0 + 0.55) * h * r * 1.0)
          ..close(),
        Paint()..color = const Color(0xFF4E9CA4),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(-h * r * 0.3, -h * r * 0.25),
            width: h * r * 1.1,
            height: h * r * 0.7),
        Paint()..color = const Color(0x33FFFFFF),
      );
    }
    // Lotus on the big pad.
    final lotus = Offset(w * 0.78, h * 0.24);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawOval(
        Rect.fromCenter(
          center: lotus.translate(math.cos(a) * h * 0.022, math.sin(a) * h * 0.016),
          width: h * 0.038,
          height: h * 0.026,
        ),
        Paint()..color = const Color(0xFFF4B8D2),
      );
    }
    canvas.drawCircle(lotus, h * 0.012, Paint()..color = const Color(0xFFF7DD8A));

    // Sun glints on the water.
    final rng = math.Random(31);
    for (var i = 0; i < 8; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(rng.nextDouble() * w, rng.nextDouble() * h),
          width: w * (0.03 + rng.nextDouble() * 0.05),
          height: h * 0.008,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15 + rng.nextDouble() * 0.2),
      );
    }
  }

  // Aurora Peaks: ribbons of light rolling over midnight mountains.
  void _sceneAurora(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _bg(
      canvas,
      size,
      const [Color(0xFF161C3E), Color(0xFF2E3860), Color(0xFF4A3E78)],
      stops: const [0.0, 0.60, 1.0],
    );

    // Stars.
    final rng = math.Random(19);
    for (var i = 0; i < 16; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.55),
        0.6 + rng.nextDouble() * 1.1,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30 + rng.nextDouble() * 0.5),
      );
    }
    _spark(canvas, Offset(w * 0.86, h * 0.14), 2.4,
        Paint()..color = Colors.white70);

    // Aurora ribbons: soft blurred bands weaving across the sky.
    Path ribbon(double y0, double amp) => Path()
      ..moveTo(-w * 0.05, h * y0)
      ..quadraticBezierTo(w * 0.25, h * (y0 - amp), w * 0.5, h * y0)
      ..quadraticBezierTo(w * 0.75, h * (y0 + amp), w * 1.05, h * (y0 - amp * 0.6));
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawPath(
      ribbon(0.26, 0.14),
      glow
        ..color = const Color(0xFF7FE8C8).withValues(alpha: 0.45)
        ..strokeWidth = h * 0.085,
    );
    canvas.drawPath(
      ribbon(0.18, 0.10),
      glow
        ..color = const Color(0xFFB48CE8).withValues(alpha: 0.32)
        ..strokeWidth = h * 0.055,
    );
    canvas.drawPath(
      ribbon(0.33, 0.12),
      glow
        ..color = const Color(0xFF8FD9A8).withValues(alpha: 0.25)
        ..strokeWidth = h * 0.035,
    );

    // Crescent moon.
    final moon = Offset(w * 0.14, h * 0.16);
    canvas.drawCircle(moon, h * 0.055, Paint()..color = const Color(0xFFEFEAD2));
    canvas.drawCircle(moon.translate(h * 0.024, -h * 0.012), h * 0.048,
        Paint()..color = const Color(0xFF161C3E));

    // Back ridge with snowcaps catching the aurora light.
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.74)
        ..lineTo(w * 0.20, h * 0.46)
        ..lineTo(w * 0.38, h * 0.68)
        ..lineTo(w * 0.58, h * 0.42)
        ..lineTo(w * 0.78, h * 0.70)
        ..lineTo(w * 0.92, h * 0.54)
        ..lineTo(w, h * 0.64)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF322A58),
    );
    final snow = Paint()..color = const Color(0xFFBFE8DC);
    for (final (fx, fy) in const [(0.20, 0.46), (0.58, 0.42), (0.92, 0.54)]) {
      canvas.drawPath(
        Path()
          ..moveTo(w * fx - w * 0.032, h * fy + h * 0.060)
          ..lineTo(w * fx, h * fy)
          ..lineTo(w * fx + w * 0.032, h * fy + h * 0.060)
          ..close(),
        snow,
      );
    }

    // Front ridge, darkest.
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.88)
        ..lineTo(w * 0.26, h * 0.64)
        ..lineTo(w * 0.48, h * 0.86)
        ..lineTo(w * 0.70, h * 0.60)
        ..lineTo(w * 0.88, h * 0.84)
        ..lineTo(w, h * 0.74)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF221E40),
    );
  }

  // ─── Tier scene motifs ───────────────────────────────────────

  // Soft sun disc + floating seed puffs.
  void _meadow(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.22),
      size.height * 0.14,
      Paint()..color = theme.accent.withValues(alpha: 0.55),
    );
    final rng = math.Random(3);
    final paint = Paint()..color = theme.accent.withValues(alpha: 0.5);
    for (var i = 0; i < 10; i++) {
      canvas.drawCircle(
        Offset(
          rng.nextDouble() * size.width,
          (0.1 + rng.nextDouble() * 0.55) * size.height,
        ),
        1.0 + rng.nextDouble() * 1.6,
        paint,
      );
    }
  }

  // Drifting leaf shapes across the sky.
  void _fields(Canvas canvas, Size size) {
    final rng = math.Random(9);
    for (var i = 0; i < 7; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        (0.08 + rng.nextDouble() * 0.5) * size.height,
      );
      final s = 4.0 + rng.nextDouble() * 5;
      final angle = rng.nextDouble() * math.pi;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      canvas.drawPath(
        Path()
          ..moveTo(0, -s)
          ..quadraticBezierTo(s * 0.9, 0, 0, s)
          ..quadraticBezierTo(-s * 0.9, 0, 0, -s)
          ..close(),
        Paint()
          ..color = theme.accent.withValues(alpha: 0.30 + rng.nextDouble() * 0.2),
      );
      canvas.restore();
    }
  }

  // Rounded pine silhouettes rising behind the hills.
  void _forest(Canvas canvas, Size size) {
    final paint = Paint()..color = theme.hillBack.withValues(alpha: 0.75);
    final rng = math.Random(5);
    for (var i = 0; i < 6; i++) {
      final x = (0.05 + i * 0.17 + rng.nextDouble() * 0.05) * size.width;
      final treeH = (0.28 + rng.nextDouble() * 0.18) * size.height;
      final base = size.height * 0.82;
      final treeW = treeH * 0.55;
      canvas.drawPath(
        Path()
          ..moveTo(x, base - treeH)
          ..quadraticBezierTo(x + treeW * 0.5, base - treeH * 0.45, x + treeW * 0.5, base)
          ..lineTo(x - treeW * 0.5, base)
          ..quadraticBezierTo(x - treeW * 0.5, base - treeH * 0.45, x, base - treeH)
          ..close(),
        paint,
      );
    }
  }

  // Diagonal lattice + a climbing vine with leaves.
  void _trellis(Canvas canvas, Size size) {
    final lattice = Paint()
      ..color = theme.accent.withValues(alpha: 0.12)
      ..strokeWidth = 1.4;
    const gap = 34.0;
    for (var x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), lattice);
      canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), lattice);
    }
    final vine = Paint()
      ..color = theme.accent.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..moveTo(size.width * 0.06, size.height);
    path.quadraticBezierTo(
      size.width * 0.16, size.height * 0.55,
      size.width * 0.07, size.height * 0.18,
    );
    canvas.drawPath(path, vine);
    final leaf = Paint()..color = theme.accent.withValues(alpha: 0.45);
    for (final (fx, fy) in [(0.115, 0.72), (0.10, 0.45), (0.075, 0.24)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * fx + 7, size.height * fy),
          width: 12,
          height: 6,
        ),
        leaf,
      );
    }
  }

  // Crescent moon and a starfield.
  void _moonlit(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.82, size.height * 0.24);
    final r = size.height * 0.13;
    canvas.drawCircle(c, r, Paint()..color = theme.accent.withValues(alpha: 0.9));
    canvas.drawCircle(
      c.translate(r * 0.45, -r * 0.28),
      r * 0.92,
      Paint()..color = theme.skyTop,
    );
    final rng = math.Random(11);
    for (var i = 0; i < 16; i++) {
      canvas.drawCircle(
        Offset(
          rng.nextDouble() * size.width,
          rng.nextDouble() * size.height * 0.6,
        ),
        0.8 + rng.nextDouble() * 1.2,
        Paint()
          ..color = theme.accent
              .withValues(alpha: 0.35 + rng.nextDouble() * 0.5),
      );
    }
  }

  // Big outlined botanical leaves in the corners.
  void _botanical(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = theme.accent.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    void leaf(Offset base, double len, double angle) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.42, -len * 0.5, 0, -len)
        ..quadraticBezierTo(-len * 0.42, -len * 0.5, 0, 0);
      canvas.drawPath(path, stroke);
      canvas.drawLine(Offset.zero, Offset(0, -len * 0.92), stroke);
      for (var i = 1; i <= 3; i++) {
        final y = -len * 0.22 * i;
        canvas.drawLine(Offset(0, y), Offset(len * 0.16, y - len * 0.10), stroke);
        canvas.drawLine(Offset(0, y), Offset(-len * 0.16, y - len * 0.10), stroke);
      }
      canvas.restore();
    }

    leaf(Offset(size.width * 0.10, size.height * 0.66), size.height * 0.5, -0.5);
    leaf(Offset(size.width * 0.93, size.height * 0.72), size.height * 0.62, 0.55);
  }

  // Forge rays from the top corner + an emblem ring.
  void _gilded(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.85, size.height * 0.15);
    final ray = Paint()..color = theme.accent.withValues(alpha: 0.10);
    for (var i = 0; i < 7; i++) {
      final a = math.pi * 0.35 + i * 0.28;
      final len = size.width;
      canvas.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..lineTo(origin.dx + math.cos(a - 0.05) * len,
              origin.dy + math.sin(a - 0.05) * len)
          ..lineTo(origin.dx + math.cos(a + 0.05) * len,
              origin.dy + math.sin(a + 0.05) * len)
          ..close(),
        ray,
      );
    }
    final ring = Paint()
      ..color = theme.accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(origin, size.height * 0.16, ring);
    canvas.drawCircle(
      origin,
      size.height * 0.11,
      ring..strokeWidth = 1.2,
    );
  }

  // Radiance: rays, double ring and sparkles — the endgame card.
  void _radiant(Canvas canvas, Size size) {
    _gilded(canvas, size);
    final rng = math.Random(21);
    final sparkle = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 7; i++) {
      final c = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height * 0.62,
      );
      _spark(canvas, c, 2.0 + rng.nextDouble() * 2.4, sparkle);
    }
  }

  @override
  bool shouldRepaint(ProfileCardScenePainter old) => old.theme != theme;
}

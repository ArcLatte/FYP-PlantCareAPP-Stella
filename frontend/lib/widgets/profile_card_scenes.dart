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
}

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
  });

  bool get isNamecard => namecardOf != null;

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
    skyTop: Color(0xFF89C793),
    skyBottom: Color(0xFF3E8757),
    hillBack: Color(0xFF2F7448),
    hillFront: Color(0xFF225C38),
    accent: Color(0xFFE7F7DC),
    motif: CardMotif.verdant,
  ),
  ProfileCardTheme(
    id: 'nc_rain',
    name: 'Tender Hands',
    namecardOf: 'Tender Hands',
    tierIndex: 0,
    skyTop: Color(0xFF6FA8C9),
    skyBottom: Color(0xFF3B6E8F),
    hillBack: Color(0xFF356179),
    hillFront: Color(0xFF294D60),
    accent: Color(0xFFD6EDFA),
    motif: CardMotif.rain,
  ),
  ProfileCardTheme(
    id: 'nc_hive',
    name: 'The Eternal Flame',
    namecardOf: 'The Eternal Flame',
    tierIndex: 0,
    skyTop: Color(0xFFE8A94E),
    skyBottom: Color(0xFFA85E1D),
    hillBack: Color(0xFF965317),
    hillFront: Color(0xFF784111),
    accent: Color(0xFFFFE9BC),
    motif: CardMotif.hive,
  ),
  ProfileCardTheme(
    id: 'nc_lens',
    name: 'The Keen Eye',
    namecardOf: 'The Keen Eye',
    tierIndex: 0,
    skyTop: Color(0xFF4E9E97),
    skyBottom: Color(0xFF23615C),
    hillBack: Color(0xFF1E534F),
    hillFront: Color(0xFF16413E),
    accent: Color(0xFFCBF2EC),
    motif: CardMotif.lens,
  ),
  ProfileCardTheme(
    id: 'nc_summit',
    name: 'Ascension',
    namecardOf: 'Ascension',
    tierIndex: 0,
    skyTop: Color(0xFF9B8CC9),
    skyBottom: Color(0xFF5A4A8A),
    hillBack: Color(0xFF4D3F77),
    hillFront: Color(0xFF3C3060),
    accent: Color(0xFFF3E9C8),
    motif: CardMotif.summit,
  ),
  ProfileCardTheme(
    id: 'nc_wonders',
    name: 'Wonders of the Garden',
    namecardOf: 'Wonders of the Garden',
    tierIndex: 0,
    skyTop: Color(0xFFD98BB6),
    skyBottom: Color(0xFF8A4A78),
    hillBack: Color(0xFF7A4069),
    hillFront: Color(0xFF603253),
    accent: Color(0xFFFFE4F2),
    motif: CardMotif.wonders,
  ),
];

/// Theme lookup by id (tier scenes + namecards), or null.
ProfileCardTheme? profileCardThemeById(String? id) {
  for (final t in kProfileCardThemes) {
    if (t.id == id) return t;
  }
  for (final t in kNamecardThemes) {
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
      case CardMotif.verdant:
        _verdant(canvas, size);
      case CardMotif.rain:
        _rain(canvas, size);
      case CardMotif.hive:
        _hive(canvas, size);
      case CardMotif.lens:
        _lens(canvas, size);
      case CardMotif.summit:
        _summit(canvas, size);
      case CardMotif.wonders:
        _wonders(canvas, size);
    }
  }

  // Great tree silhouette on the right + drifting leaves.
  void _verdant(Canvas canvas, Size size) {
    final trunkX = size.width * 0.84;
    final base = size.height * 0.84;
    final treeH = size.height * 0.62;
    final paint = Paint()..color = theme.hillBack.withValues(alpha: 0.8);
    canvas.drawPath(
      Path()
        ..moveTo(trunkX - 5, base)
        ..quadraticBezierTo(
            trunkX - 3, base - treeH * 0.5, trunkX - 1, base - treeH * 0.62)
        ..lineTo(trunkX + 3, base - treeH * 0.62)
        ..quadraticBezierTo(trunkX + 4, base - treeH * 0.4, trunkX + 7, base)
        ..close(),
      paint,
    );
    // Canopy: overlapping blobs.
    for (final (fx, fy, fr) in [
      (0.84, 0.30, 0.16),
      (0.74, 0.36, 0.11),
      (0.94, 0.37, 0.10),
      (0.84, 0.44, 0.12),
    ]) {
      canvas.drawCircle(
        Offset(size.width * fx, size.height * fy),
        size.height * fr,
        paint,
      );
    }
    _fields(canvas, size); // drifting leaves
  }

  // Diagonal rain streaks, a big droplet, and puddle ripple rings.
  void _rain(Canvas canvas, Size size) {
    final rng = math.Random(17);
    final streak = Paint()
      ..color = theme.accent.withValues(alpha: 0.35)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 16; i++) {
      final p = Offset(
        rng.nextDouble() * size.width,
        rng.nextDouble() * size.height * 0.68,
      );
      final len = 7.0 + rng.nextDouble() * 9;
      canvas.drawLine(p, p.translate(-len * 0.28, len), streak);
    }
    // Hero droplet.
    final c = Offset(size.width * 0.80, size.height * 0.26);
    final r = size.height * 0.10;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r * 1.4)
        ..quadraticBezierTo(c.dx + r, c.dy - r * 0.2, c.dx + r * 0.85, c.dy + r * 0.4)
        ..arcToPoint(Offset(c.dx - r * 0.85, c.dy + r * 0.4),
            radius: Radius.circular(r), clockwise: true)
        ..quadraticBezierTo(c.dx - r, c.dy - r * 0.2, c.dx, c.dy - r * 1.4)
        ..close(),
      Paint()..color = theme.accent.withValues(alpha: 0.5),
    );
    // Ripple rings on the back hill line.
    final ring = Paint()
      ..color = theme.accent.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final (fx, fw) in [(0.18, 0.10), (0.30, 0.06)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * fx, size.height * 0.70),
          width: size.width * fw,
          height: size.width * fw * 0.30,
        ),
        ring,
      );
    }
  }

  // Honeycomb cluster in the corner + embers rising.
  void _hive(Canvas canvas, Size size) {
    final hex = Paint()
      ..color = theme.accent.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    const r = 13.0;
    void cell(double cx, double cy) {
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        final p = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), hex);
    }

    final ox = size.width * 0.86;
    final oy = size.height * 0.22;
    const dx = r * 1.732; // hex column spacing
    cell(ox, oy);
    cell(ox - dx, oy);
    cell(ox + dx, oy);
    cell(ox - dx / 2, oy + r * 1.5);
    cell(ox + dx / 2, oy + r * 1.5);
    cell(ox - dx / 2, oy - r * 1.5);
    // Embers drifting up on the left.
    final rng = math.Random(7);
    for (var i = 0; i < 9; i++) {
      canvas.drawCircle(
        Offset(
          (0.05 + rng.nextDouble() * 0.45) * size.width,
          (0.12 + rng.nextDouble() * 0.55) * size.height,
        ),
        1.2 + rng.nextDouble() * 1.8,
        Paint()
          ..color = theme.accent
              .withValues(alpha: 0.35 + rng.nextDouble() * 0.4),
      );
    }
  }

  // Concentric lens rings with tick marks — a botanist's loupe.
  void _lens(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.80, size.height * 0.34);
    final ring = Paint()
      ..color = theme.accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (final f in [0.26, 0.19, 0.10]) {
      canvas.drawCircle(c, size.height * f, ring);
    }
    // Crosshair ticks on the outer ring.
    final tick = Paint()
      ..color = theme.accent.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    final rOut = size.height * 0.26;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + math.pi / 4;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * rOut * 0.86,
            c.dy + math.sin(a) * rOut * 0.86),
        Offset(c.dx + math.cos(a) * rOut * 1.12,
            c.dy + math.sin(a) * rOut * 1.12),
        tick,
      );
    }
    // A tiny leaf under inspection at the center.
    final leaf = Paint()..color = theme.accent.withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(
          center: c, width: size.height * 0.10, height: size.height * 0.05),
      leaf,
    );
  }

  // Mountain peaks behind the hills + rising sun with rays.
  void _summit(Canvas canvas, Size size) {
    final peak = Paint()..color = theme.hillBack.withValues(alpha: 0.65);
    final snow = Paint()..color = theme.accent.withValues(alpha: 0.7);
    void mountain(double fx, double fw, double fh) {
      final baseY = size.height * 0.82;
      final cx = size.width * fx;
      final w = size.width * fw;
      final top = baseY - size.height * fh;
      canvas.drawPath(
        Path()
          ..moveTo(cx - w / 2, baseY)
          ..lineTo(cx, top)
          ..lineTo(cx + w / 2, baseY)
          ..close(),
        peak,
      );
      // Snow cap.
      canvas.drawPath(
        Path()
          ..moveTo(cx - w * 0.10, top + size.height * fh * 0.22)
          ..lineTo(cx, top)
          ..lineTo(cx + w * 0.10, top + size.height * fh * 0.22)
          ..close(),
        snow,
      );
    }

    mountain(0.22, 0.34, 0.52);
    mountain(0.44, 0.28, 0.38);
    // Sun + rays.
    final sun = Offset(size.width * 0.80, size.height * 0.24);
    canvas.drawCircle(
      sun,
      size.height * 0.10,
      Paint()..color = theme.accent.withValues(alpha: 0.8),
    );
    final ray = Paint()
      ..color = theme.accent.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        sun.translate(
            math.cos(a) * size.height * 0.14, math.sin(a) * size.height * 0.14),
        sun.translate(
            math.cos(a) * size.height * 0.20, math.sin(a) * size.height * 0.20),
        ray,
      );
    }
  }

  // A spiral of sparkles — for feats beyond the beaten path.
  void _wonders(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.76, size.height * 0.34);
    for (var i = 0; i < 12; i++) {
      final t = i / 12;
      final a = t * math.pi * 3.2;
      final r = size.height * (0.06 + t * 0.30);
      final p = c.translate(math.cos(a) * r, math.sin(a) * r * 0.7);
      final s = 1.6 + (1 - t) * 2.6;
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - s * 2)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + s * 2, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s * 2)
          ..quadraticBezierTo(p.dx, p.dy, p.dx - s * 2, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s * 2)
          ..close(),
        Paint()
          ..color = theme.accent.withValues(alpha: 0.35 + (1 - t) * 0.5),
      );
    }
  }

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
      final s = 2.0 + rng.nextDouble() * 2.4;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - s * 2)
          ..quadraticBezierTo(c.dx, c.dy, c.dx + s * 2, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s * 2)
          ..quadraticBezierTo(c.dx, c.dy, c.dx - s * 2, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s * 2)
          ..close(),
        sparkle,
      );
    }
  }

  @override
  bool shouldRepaint(ProfileCardScenePainter old) => old.theme != theme;
}

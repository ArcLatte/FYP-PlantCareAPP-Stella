import 'package:flutter/material.dart';

/// A shop cosmetic + the user's ownership state, mirrored from
/// `GET /api/shop/`. Kinds: creature skins (a tint color + strength applied
/// to the streak companion), pot styles (colors/pattern for the companion's
/// pot), and namecards (shop-exclusive profile-card scenes).
class Cosmetic {
  final String code;
  final String name;
  final String description;
  final String kind;
  final String rarity; // common | rare | epic
  final int costSeeds;
  final Map<String, dynamic> payload;
  final bool owned;
  final bool equipped;

  const Cosmetic({
    required this.code,
    required this.name,
    required this.description,
    required this.kind,
    required this.rarity,
    required this.costSeeds,
    required this.payload,
    required this.owned,
    required this.equipped,
  });

  factory Cosmetic.fromJson(Map<String, dynamic> json) {
    return Cosmetic(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      kind: json['kind'] ?? '',
      rarity: json['rarity'] ?? 'common',
      costSeeds: (json['cost_seeds'] as num?)?.toInt() ?? 0,
      payload: (json['payload'] is Map<String, dynamic>)
          ? json['payload'] as Map<String, dynamic>
          : const {},
      owned: json['owned'] == true,
      equipped: json['equipped'] == true,
    );
  }

  static const String kindSkin = 'creature_skin';
  static const String kindPot = 'pot_style';
  static const String kindNamecard = 'namecard';

  bool get isSkin => kind == kindSkin;
  bool get isPot => kind == kindPot;
  bool get isNamecard => kind == kindNamecard;

  /// The profile-card theme this namecard unlocks, if this is a namecard.
  String? get themeId => payload['theme_id']?.toString();

  /// The skin's tint color, if this is a creature skin.
  Color? get tintColor => parseTint(payload);

  /// Tint strength 0–1 (how far toward the tint the creature shifts).
  double get tintAmount =>
      ((payload['amount'] as num?)?.toDouble() ?? 0.3).clamp(0.0, 1.0);

  /// Gacha-convention rarity color, matching the medal scheme.
  Color get rarityColor {
    switch (rarity) {
      case 'epic':
        return const Color(0xFFE5A722);
      case 'rare':
        return const Color(0xFF9C6ADE);
      case 'common':
      default:
        return const Color(0xFF5B8DEF);
    }
  }

  /// Parse a `{'tint': '#RRGGBB', ...}` payload into a [Color].
  static Color? parseTint(Map<String, dynamic>? payload) {
    final hex = payload?['tint']?.toString();
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}

/// The full shop response: balance + catalog.
class ShopState {
  final int seeds;
  final List<Cosmetic> items;

  const ShopState({required this.seeds, required this.items});

  factory ShopState.fromJson(Map<String, dynamic> json) {
    return ShopState(
      seeds: (json['seeds'] as num?)?.toInt() ?? 0,
      items: (json['items'] is List)
          ? (json['items'] as List)
                .map((e) => Cosmetic.fromJson(e as Map<String, dynamic>))
                .toList()
          : const [],
    );
  }
}

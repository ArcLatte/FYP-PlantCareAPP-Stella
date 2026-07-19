import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../models/cosmetic.dart';
import '../../models/plant_stage.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/coin.dart';
import '../../widgets/pot.dart';
import '../../widgets/profile_card_scenes.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/streak_plant.dart';

/// Shop: spend the coins earned from level-ups, medals and weekly
/// challenges. Two aisles: pot styles (the pot the companion sits in) and
/// namecards (profile-card scenes).
/// Cosmetics are purely visual — the shop is the "spend" side of the
/// reward economy.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  ShopState? _shop;
  bool _isLoading = true;
  bool _busy = false; // a buy/equip call is in flight
  String? _previewCode; // card the user tapped, drives the live preview
  SharedPreferences? _prefs;
  // The profile-card theme currently in use ('auto' or a theme id) — the
  // same local choice the profile picker writes, so namecards can show an
  // accurate "In use" state here.
  String _activeThemeId = 'auto';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _activeThemeId = _prefs!.getString(kCardThemePrefKey) ?? 'auto';
      final shop = await ApiService.getShop();
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.error(
        context,
        e,
        fallback: 'Could not load the shop. Please try again.',
      );
    }
  }

  List<Cosmetic> get _items =>
      (_shop?.items ?? const <Cosmetic>[]).where((c) => !c.isSkin).toList();

  Cosmetic? _byCode(String? code) {
    if (code == null) return null;
    for (final c in _items) {
      if (c.code == code) return c;
    }
    return null;
  }

  Cosmetic? _equippedOf(bool Function(Cosmetic) kind) {
    for (final c in _items) {
      if (c.equipped && kind(c)) return c;
    }
    return null;
  }

  /// The item the preview should spotlight.
  Cosmetic? get _previewItem => _byCode(_previewCode);

  Future<void> _buy(Cosmetic item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ApiService.buyCosmetic(item.code);
      await _load();
      if (mounted) {
        AppSnackBar.success(
          context,
          item.isNamecard
              ? '${item.name} is yours! Tap Use to show it off.'
              : '${item.name} is yours! Tap Equip to wear it.',
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _equip(Cosmetic item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ApiService.equipCosmetic(item.code);
      await _load();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Namecards "equip" locally: the profile-card choice lives in prefs
  /// (shared with the profile picker), not on the server. Tapping the
  /// active one reverts to 'auto', mirroring the equip toggle.
  Future<void> _useNamecard(Cosmetic item) async {
    final id = item.themeId;
    if (id == null || _prefs == null) return;
    final next = _activeThemeId == id ? 'auto' : id;
    await _prefs!.setString(kCardThemePrefKey, next);
    if (mounted) setState(() => _activeThemeId = next);
  }

  @override
  Widget build(BuildContext context) {
    final pots = _items.where((c) => c.isPot).toList();
    final cards = _items.where((c) => c.isNamecard).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          if (_shop != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              // Tapping the balance explains where coins come from.
              child: Center(child: CoinPill(coins: _shop!.seeds)),
            ),
        ],
      ),
      body: _isLoading
          ? const _ShopSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _buildPreview(),
                  const SizedBox(height: 6),
                  Text(
                    'Earn coins from level-ups, medals and weekly challenges '
                    '— tap your balance to see how.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (pots.isNotEmpty)
                    ..._section(
                      'Pots',
                      'A new home for your companion to grow in.',
                      pots,
                    ),
                  if (cards.isNotEmpty)
                    ..._section(
                      'Namecards',
                      'Exclusive backgrounds for your profile card.',
                      cards,
                    ),
                ],
              ),
            ),
    );
  }

  /// Live preview: a namecard scene when a namecard is selected, otherwise
  /// the Bloom-stage companion wearing the previewed/equipped pot.
  Widget _buildPreview() {
    final item = _previewItem;
    if (item != null && item.isNamecard) {
      return _NamecardPreview(item: item);
    }

    final potItem = (item?.isPot ?? false) ? item : _equippedOf((c) => c.isPot);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientSoftStart, AppColors.gradientSoftEnd],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          StreakPlant(
            key: ValueKey(potItem?.code),
            stage: PlantStage.all.last, // Bloom — show the look at its best
            size: 150,
            potStyle: PotStyle.fromPayload(potItem?.payload),
          ),
          const SizedBox(height: 6),
          Text(
            item?.name ?? potItem?.name ?? 'Natural look',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(String title, String blurb, List<Cosmetic> items) {
    return [
      const SizedBox(height: 20),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(blurb, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ItemCard(
            item: item,
            seeds: _shop?.seeds ?? 0,
            selected: item.code == _previewCode,
            busy: _busy,
            inUse: item.isNamecard &&
                item.themeId != null &&
                item.themeId == _activeThemeId,
            onTap: () => setState(() => _previewCode = item.code),
            onBuy: () => _buy(item),
            onEquip: () => item.isNamecard ? _useNamecard(item) : _equip(item),
          ),
        ),
    ];
  }
}

/// Full-width preview of a namecard's painted scene, shown when a namecard
/// is the selected item.
class _NamecardPreview extends StatelessWidget {
  final Cosmetic item;
  const _NamecardPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = profileCardThemeById(item.themeId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (theme != null)
              CustomPaint(painter: ProfileCardScenePainter(theme))
            else
              const ColoredBox(color: AppColors.background),
            Positioned(
              left: 16,
              bottom: 12,
              child: Text(
                item.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Color(0x66000000), blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Cosmetic item;
  final int seeds;
  final bool selected;
  final bool busy;
  final bool inUse; // namecards: matches the active profile-card theme
  final VoidCallback onTap;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _ItemCard({
    required this.item,
    required this.seeds,
    required this.selected,
    required this.busy,
    required this.inUse,
    required this.onTap,
    required this.onBuy,
    required this.onEquip,
  });

  /// Kind-appropriate swatch inside the rarity ring: mini pot for pots,
  /// scene thumbnail for namecards.
  Widget _swatch() {
    Widget inner;
    if (item.isPot) {
      inner = PotIcon(style: PotStyle.fromPayload(item.payload), size: 36);
    } else if (item.isNamecard) {
      final theme = profileCardThemeById(item.themeId);
      inner = ClipOval(
        child: theme != null
            ? CustomPaint(
                painter: ProfileCardScenePainter(theme),
                child: const SizedBox.expand(),
              )
            : const ColoredBox(color: AppColors.background),
      );
    } else {
      inner = const Icon(Icons.spa_rounded, color: AppColors.primary);
    }
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: item.rarityColor, width: 2),
      ),
      child: inner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final affordable = seeds >= item.costSeeds;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.cardBorder,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _swatch(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.rarity.toUpperCase(),
                        style: TextStyle(
                          color: item.rarityColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ActionButton(
              item: item,
              affordable: affordable,
              busy: busy,
              inUse: inUse,
              onBuy: onBuy,
              onEquip: onEquip,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Cosmetic item;
  final bool affordable;
  final bool busy;
  final bool inUse;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _ActionButton({
    required this.item,
    required this.affordable,
    required this.busy,
    required this.inUse,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    if (!item.owned) {
      // Blue "buy" pill with a gold coin: the coin marks the price, the blue
      // keeps the action from blending into the gold currency.
      return _pill(
        label: '${item.costSeeds}',
        leading: const CoinIcon(size: 15),
        color: affordable ? AppColors.shop : AppColors.textMuted,
        filled: affordable,
        onTap: (affordable && !busy) ? onBuy : null,
      );
    }
    if (item.isNamecard) {
      return _pill(
        label: inUse ? 'In use' : 'Use',
        icon: inUse ? Icons.check_rounded : null,
        color: inUse ? AppColors.amber : AppColors.primary,
        filled: inUse,
        onTap: busy ? null : onEquip,
      );
    }
    return _pill(
      label: item.equipped ? 'Equipped' : 'Equip',
      icon: item.equipped ? Icons.check_rounded : null,
      color: item.equipped ? AppColors.amber : AppColors.primary,
      filled: item.equipped,
      onTap: busy ? null : onEquip,
    );
  }

  Widget _pill({
    required String label,
    IconData? icon,
    Widget? leading,
    required Color color,
    required bool filled,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 4),
            ] else if (icon != null) ...[
              Icon(icon, color: filled ? Colors.white : color, size: 15),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopSkeleton extends StatelessWidget {
  const _ShopSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: const [
        SkeletonBox(height: 210, radius: 24),
        SizedBox(height: 20),
        SkeletonBox(width: 150, height: 22, radius: 8),
        SizedBox(height: 16),
        SkeletonBox(height: 76, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 76, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 76, radius: 16),
      ],
    );
  }
}

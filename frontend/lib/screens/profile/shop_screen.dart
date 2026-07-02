import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/cosmetic.dart';
import '../../models/plant_stage.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/streak_plant.dart';

/// Seed Shop: spend the seeds earned from level-ups, medals and weekly
/// challenges on creature skins for the streak companion. Cosmetics are
/// purely visual — the shop is the "spend" side of the reward economy.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shop = await ApiService.getShop();
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.error(context, 'Failed to load shop: $e');
    }
  }

  Cosmetic? get _previewItem {
    final items = _shop?.items ?? const <Cosmetic>[];
    if (_previewCode != null) {
      for (final c in items) {
        if (c.code == _previewCode) return c;
      }
    }
    for (final c in items) {
      if (c.equipped) return c;
    }
    return null;
  }

  Future<void> _buy(Cosmetic item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ApiService.buyCosmetic(item.code);
      await _load();
      if (mounted) {
        AppSnackBar.success(context, '${item.name} is yours! Tap Equip to wear it.');
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '$e');
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
      if (mounted) AppSnackBar.error(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seed Shop'),
        actions: [
          if (_shop != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: _SeedBalance(seeds: _shop!.seeds)),
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
                  _PreviewCard(item: _previewItem),
                  const SizedBox(height: 20),
                  Text(
                    'Creature skins',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Earn seeds from level-ups, medals and weekly challenges.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final item in _shop?.items ?? const <Cosmetic>[])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SkinCard(
                        item: item,
                        seeds: _shop?.seeds ?? 0,
                        selected: item.code == _previewItem?.code,
                        busy: _busy,
                        onTap: () =>
                            setState(() => _previewCode = item.code),
                        onBuy: () => _buy(item),
                        onEquip: () => _equip(item),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Seeds balance pill (used in the app bar).
class _SeedBalance extends StatelessWidget {
  final int seeds;
  const _SeedBalance({required this.seeds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.spa_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 5),
          Text(
            '$seeds',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live preview: the Bloom-stage companion wearing the tapped (or equipped)
/// skin, on the same soft-green shelf styling as the rest of the app.
class _PreviewCard extends StatelessWidget {
  final Cosmetic? item;
  const _PreviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final tint = item?.tintColor;
    final amount = item?.tintAmount ?? 0;
    final filter = (tint == null)
        ? null
        : ColorFilter.mode(
            Color.lerp(Colors.white, tint, amount)!,
            BlendMode.modulate,
          );
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
            key: ValueKey(item?.code ?? 'default'),
            stage: PlantStage.all.last, // Bloom — show the skin at its best
            size: 150,
            colorFilter: filter,
          ),
          const SizedBox(height: 6),
          Text(
            item == null ? 'Natural look' : item!.name,
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
}

class _SkinCard extends StatelessWidget {
  final Cosmetic item;
  final int seeds;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _SkinCard({
    required this.item,
    required this.seeds,
    required this.selected,
    required this.busy,
    required this.onTap,
    required this.onBuy,
    required this.onEquip,
  });

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
            // Tint swatch with a rarity ring.
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: item.rarityColor, width: 2),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.tintColor ?? AppColors.background,
                ),
              ),
            ),
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
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _ActionButton({
    required this.item,
    required this.affordable,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    if (!item.owned) {
      return _pill(
        label: '${item.costSeeds}',
        icon: Icons.spa_rounded,
        color: affordable ? AppColors.primary : AppColors.textMuted,
        filled: affordable,
        onTap: (affordable && !busy) ? onBuy : null,
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
            if (icon != null) ...[
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

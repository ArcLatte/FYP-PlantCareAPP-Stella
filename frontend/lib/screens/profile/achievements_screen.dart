import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/achievement.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';

const _kMedalsPerPage = 6; // 2 columns × 3 shelf rows per album page

/// Medal display book: a page-flip album of gacha-style medals. Each page
/// holds six medal slots on shelf rows; locked achievements show as faint
/// silhouettes with hidden names. Swipe between pages, tap a medal for the
/// detail sheet (with pin/unpin for unlocked ones).
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _all = [];
  bool _isLoading = true;
  int _page = 0;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.getAchievements();
      if (!mounted) return;
      // Unlocked medals first, then by rarity (legendary → rare) so the
      // book opens on the user's shiniest spread.
      list.sort((a, b) {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        return b.rarityStars.compareTo(a.rarityStars);
      });
      setState(() {
        _all = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.error(context, 'Failed to load: $e');
    }
  }

  int get _unlockedCount => _all.where((a) => a.unlocked).length;
  int get _pageCount => (_all.length / _kMedalsPerPage).ceil().clamp(1, 99);

  List<Achievement> _pageItems(int page) {
    final start = page * _kMedalsPerPage;
    if (start >= _all.length) return const [];
    return _all.sublist(
        start, (start + _kMedalsPerPage).clamp(0, _all.length));
  }

  Future<void> _openSheet(Achievement a) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MedalSheet(
        achievement: a,
        onToggle: !a.unlocked
            ? null
            : () async {
                try {
                  final updated = a.isPinned
                      ? await ApiService.unpinAchievement(a.code)
                      : await ApiService.pinAchievement(a.code);
                  if (!mounted) return;
                  setState(() {
                    final idx = _all.indexWhere((x) => x.code == a.code);
                    if (idx != -1) _all[idx] = updated;
                  });
                  Navigator.pop(context);
                } catch (e) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  AppSnackBar.error(
                      context, e.toString().replaceFirst('Exception: ', ''));
                }
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medal Book'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const _BookSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _CollectionHeader(
                    unlocked: _unlockedCount,
                    total: _all.length,
                  ),
                  const SizedBox(height: 16),
                  // The album. Fixed height fitting 3 shelf rows.
                  SizedBox(
                    height: 470,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pageCount,
                      onPageChanged: (p) => setState(() => _page = p),
                      itemBuilder: (context, page) => _AlbumPage(
                        items: _pageItems(page),
                        pageNumber: page + 1,
                        pageCount: _pageCount,
                        onTapMedal: _openSheet,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Page dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < _pageCount; i++) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _page ? 22 : 8,
                          height: 8,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppColors.primary
                                : AppColors.divider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

/// Collection progress banner above the book.
class _CollectionHeader extends StatelessWidget {
  final int unlocked;
  final int total;
  const _CollectionHeader({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : unlocked / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unlocked of $total medals collected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 7,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One open page of the medal album: a parchment-toned card with three
/// shelf rows, two medal slots per shelf.
class _AlbumPage extends StatelessWidget {
  final List<Achievement> items;
  final int pageNumber;
  final int pageCount;
  final ValueChanged<Achievement> onTapMedal;
  const _AlbumPage({
    required this.items,
    required this.pageNumber,
    required this.pageCount,
    required this.onTapMedal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        // Parchment tone, slightly warmer than the scaffold.
        color: const Color(0xFFFBF8F1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E0CE), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int row = 0; row < 3; row++) ...[
            Expanded(
              child: Row(
                children: [
                  for (int col = 0; col < 2; col++) ...[
                    Expanded(
                      child: _slot(row * 2 + col),
                    ),
                    if (col == 0) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
            // Shelf line under each row of medals.
            Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0D5BC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            '$pageNumber / $pageCount',
            style: const TextStyle(
              color: Color(0xFFB8AB8C),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slot(int index) {
    if (index >= items.length) return const SizedBox.shrink();
    final a = items[index];
    return _MedalSlot(achievement: a, onTap: () => onTapMedal(a));
  }
}

/// A single medal in the book. Unlocked: rarity-ringed medallion with glow,
/// stars, and name. Locked: dark silhouette and hidden name.
class _MedalSlot extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;
  const _MedalSlot({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final unlocked = a.unlocked;
    final color = a.rarityColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Medallion
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unlocked
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.85),
                            color,
                          ],
                        )
                      : null,
                  color: unlocked ? null : const Color(0xFFE3DCCB),
                  border: Border.all(
                    color: unlocked
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFFCFC5AC),
                    width: 2.5,
                  ),
                  boxShadow: unlocked
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  a.iconData,
                  color: unlocked
                      ? Colors.white
                      : const Color(0xFFBFB394),
                  size: 30,
                ),
              ),
              if (a.isPinned && unlocked)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.push_pin_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Rarity stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < a.rarityStars; i++)
                Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: unlocked ? color : const Color(0xFFCFC5AC),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            unlocked ? a.name : '???',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: unlocked
                  ? AppColors.textPrimary
                  : const Color(0xFFB8AB8C),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Progress toward unlocking, e.g. a slim bar for "12/50 waters".
          if (!unlocked && a.progressFraction != null) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: a.progressFraction,
                  minHeight: 4,
                  backgroundColor: const Color(0xFFE3DCCB),
                  valueColor: AlwaysStoppedAnimation(
                      color.withValues(alpha: 0.7)),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${a.progressCurrent}/${a.progressTarget}',
              style: const TextStyle(
                color: Color(0xFFB8AB8C),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Detail sheet: gacha banner header with rarity gradient, stars, and the
/// pin action for unlocked medals. Locked medals show the unlock hint.
class _MedalSheet extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback? onToggle;
  const _MedalSheet({required this.achievement, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final color = a.rarityColor;
    final unlocked = a.unlocked;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: unlocked
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color.withValues(alpha: 0.85), color],
                      )
                    : null,
                color: unlocked ? null : AppColors.background,
                border: Border.all(
                  color: unlocked
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.cardBorder,
                  width: 3,
                ),
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                a.iconData,
                color: unlocked ? Colors.white : AppColors.textMuted,
                size: 46,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < a.rarityStars; i++)
                  Icon(Icons.star_rounded, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              unlocked ? a.name : 'Locked medal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${a.rarityLabel} · +${a.xpReward} XP',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              a.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (!unlocked && a.progressFraction != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: a.progressFraction,
                  minHeight: 8,
                  backgroundColor: AppColors.background,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${a.progressCurrent} / ${a.progressTarget}',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (unlocked && a.unlockedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Earned ${a.unlockedAt!.day}/${a.unlockedAt!.month}/${a.unlockedAt!.year}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (onToggle != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    a.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                  ),
                  label: Text(a.isPinned ? 'Unpin' : 'Pin to profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        a.isPinned ? AppColors.textMuted : AppColors.primary,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Keep playing to unlock this medal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BookSkeleton extends StatelessWidget {
  const _BookSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: const [
        SkeletonBox(height: 74, radius: 16),
        SizedBox(height: 16),
        SkeletonBox(height: 470, radius: 20),
      ],
    );
  }
}

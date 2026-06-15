import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/achievement.dart';
import '../../models/medal_series.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/medal.dart';
import '../../widgets/skeleton.dart';

const _kMedalsPerPage = 6; // 2 columns × 3 shelf rows per album page
const _kPinCap = 3; // mirrors PIN_CAP in backend views.py

/// Medal display book: leveled medal series on page-flip album shelves.
/// Each medal groups a family of achievements (Waterer = first_water →
/// hydration_hero → water_centurion); stars and metal upgrade per level.
/// Tap a medal for its level ladder + pin action.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _all = [];
  List<MedalSeries> _series = [];
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
      setState(() {
        _all = list;
        _series = _sorted(MedalSeries.fromAchievements(list));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.error(context, 'Failed to load: $e');
    }
  }

  /// Shiniest spread first: by earned level desc, then name.
  List<MedalSeries> _sorted(List<MedalSeries> list) {
    list.sort((a, b) {
      if (a.level != b.level) return b.level.compareTo(a.level);
      return a.name.compareTo(b.name);
    });
    return list;
  }

  int get _levelsEarned =>
      _series.fold(0, (sum, s) => sum + s.level);
  int get _levelsTotal =>
      _series.fold(0, (sum, s) => sum + s.maxLevel);
  int get _pinnedCount => _all.where((a) => a.isPinned).length;
  int get _pageCount =>
      (_series.length / _kMedalsPerPage).ceil().clamp(1, 99);

  List<MedalSeries> _pageItems(int page) {
    final start = page * _kMedalsPerPage;
    if (start >= _series.length) return const [];
    return _series.sublist(
        start, (start + _kMedalsPerPage).clamp(0, _series.length));
  }

  Future<void> _togglePin(MedalSeries s) async {
    final target = s.current;
    if (target == null) return;
    try {
      final updated = target.isPinned
          ? await ApiService.unpinAchievement(target.code)
          : await ApiService.pinAchievement(target.code);
      if (!mounted) return;
      setState(() {
        final idx = _all.indexWhere((x) => x.code == updated.code);
        if (idx != -1) _all[idx] = updated;
        _series = _sorted(MedalSeries.fromAchievements(_all));
      });
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.error(
          context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openSheet(MedalSeries s) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MedalSheet(
        series: s,
        pinnedCount: _pinnedCount,
        onToggle: s.anyUnlocked ? () => _togglePin(s) : null,
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
                    earned: _levelsEarned,
                    total: _levelsTotal,
                  ),
                  const SizedBox(height: 16),
                  // The album. Height derives from width so slots always
                  // fit; FittedBox inside each slot absorbs font scaling.
                  AspectRatio(
                    aspectRatio: 0.74,
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
  final int earned;
  final int total;
  const _CollectionHeader({required this.earned, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : earned / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientSoftStart, AppColors.gradientSoftEnd],
        ),
        borderRadius: BorderRadius.circular(20),
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
                  '$earned of $total levels earned',
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
  final List<MedalSeries> items;
  final int pageNumber;
  final int pageCount;
  final ValueChanged<MedalSeries> onTapMedal;
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
                    Expanded(child: _slot(row * 2 + col)),
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
    final s = items[index];
    return _MedalSlot(series: s, onTap: () => onTapMedal(s));
  }
}

/// A single medal on a shelf. FittedBox scales the whole slot down if the
/// shelf is shorter than the natural content (small phones / large fonts),
/// which is what fixes the old RenderFlex overflow.
class _MedalSlot extends StatelessWidget {
  final MedalSeries series;
  final VoidCallback onTap;
  const _MedalSlot({required this.series, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locked = !series.anyUnlocked;
    final pinned =
        series.levels.any((a) => a.unlocked && a.isPinned);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Medal.series(series, size: 64),
                  if (pinned)
                    Positioned(
                      right: -2,
                      top: 12,
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
              const SizedBox(height: 3),
              Text(
                locked ? '???' : series.name,
                maxLines: 1,
                style: TextStyle(
                  color: locked
                      ? const Color(0xFFB8AB8C)
                      : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                locked
                    ? 'Locked'
                    : 'Lv ${series.level}/${series.maxLevel}',
                style: TextStyle(
                  color: locked
                      ? const Color(0xFFB8AB8C)
                      : series.metal.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail sheet: big medal, metal/level line, the full level ladder, and
/// the pin action with cap-aware UX (the backend rejects pin #4 with a
/// 400, so the button disables itself before that can happen).
class _MedalSheet extends StatelessWidget {
  final MedalSeries series;
  final int pinnedCount;
  final VoidCallback? onToggle;
  const _MedalSheet({
    required this.series,
    required this.pinnedCount,
    required this.onToggle,
  });

  /// Metal a given ladder position would award.
  MedalMetal _metalForIndex(int i) {
    if (series.maxLevel == 1) return series.metal;
    const ladder = [
      MedalMetal.bronze,
      MedalMetal.silver,
      MedalMetal.gold,
      MedalMetal.amethyst,
      MedalMetal.diamond,
    ];
    return ladder[i.clamp(0, ladder.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final s = series;
    final isPinned =
        s.current != null && s.current!.isPinned;
    final pinBlocked = !isPinned && pinnedCount >= _kPinCap;

    return SafeArea(
      child: SingleChildScrollView(
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
            const SizedBox(height: 18),
            Medal.series(s, size: 104, glow: s.anyUnlocked),
            const SizedBox(height: 10),
            Text(
              s.anyUnlocked ? s.name : 'Locked medal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              s.anyUnlocked
                  ? '${s.metal.label} · Level ${s.level} of ${s.maxLevel}'
                  : 'Earn the first level to reveal this medal',
              style: TextStyle(
                color: s.anyUnlocked
                    ? s.metal.color
                    : AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            // Level ladder
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < s.levels.length; i++) ...[
                    _LadderRow(
                      achievement: s.levels[i],
                      metal: _metalForIndex(i),
                      // The first locked level shows live progress; later
                      // locked levels just show a lock.
                      isNext: i == s.level,
                    ),
                    if (i < s.levels.length - 1)
                      const Divider(
                        color: AppColors.divider,
                        height: 1,
                        indent: 52,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (onToggle != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.push_pin_outlined,
                      color: AppColors.textMuted, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    'Pinned $pinnedCount/$_kPinCap',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: pinBlocked ? null : onToggle,
                  icon: Icon(
                    isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                  ),
                  label: Text(isPinned ? 'Unpin' : 'Pin to profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPinned
                        ? AppColors.textMuted
                        : AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.textMuted.withValues(alpha: 0.4),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ),
              if (pinBlocked) ...[
                const SizedBox(height: 8),
                const Text(
                  'Pin cap reached — unpin another medal first.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Keep playing to earn this medal',
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

/// One rung of the level ladder inside the sheet.
class _LadderRow extends StatelessWidget {
  final Achievement achievement;
  final MedalMetal metal;
  final bool isNext;
  const _LadderRow({
    required this.achievement,
    required this.metal,
    required this.isNext,
  });

  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final unlocked = a.unlocked;
    final (light, dark) = metal.gradient;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tier dot
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: unlocked
                  ? LinearGradient(colors: [light, dark])
                  : null,
              color: unlocked ? null : AppColors.divider,
            ),
            child: Icon(
              unlocked
                  ? Icons.check_rounded
                  : (isNext ? Icons.flag_rounded : Icons.lock_rounded),
              size: 14,
              color: unlocked ? Colors.white : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.name,
                        style: TextStyle(
                          color: unlocked || isNext
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '+${a.xpReward} XP',
                      style: TextStyle(
                        color: unlocked
                            ? metal.color
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  a.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                if (unlocked && a.unlockedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Earned ${_date(a.unlockedAt!)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ] else if (isNext && a.progressFraction != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: a.progressFraction,
                            minHeight: 5,
                            backgroundColor: AppColors.divider,
                            valueColor:
                                AlwaysStoppedAnimation(metal.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${a.progressCurrent}/${a.progressTarget}',
                        style: TextStyle(
                          color: metal.color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
        SkeletonBox(height: 460, radius: 20),
      ],
    );
  }
}

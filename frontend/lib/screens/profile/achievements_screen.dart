import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/medal_series.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/medal.dart';
import '../../widgets/profile_card_scenes.dart';
import '../../widgets/skeleton.dart';

const Color _kGold = Color(0xFFE5A722);
const Color _kGoldDark = Color(0xFFB8860B);

/// Achievement book, gacha-style: one banner per themed series (like
/// Genshin's achievement categories). Each banner shows completion
/// progress and the namecard earned at 100%; tapping opens the series
/// page — namecard on top, then one row per badge.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<MedalCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.getAchievements();
      if (!mounted) return;
      setState(() {
        _categories =
            MedalCategory.fromSeries(MedalSeries.fromAchievements(list));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.error(context, 'Failed to load: $e');
    }
  }

  int get _earned => _categories.fold(0, (sum, c) => sum + c.earned);
  int get _total => _categories.fold(0, (sum, c) => sum + c.total);

  Future<void> _openCategory(MedalCategory category) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CategoryDetailScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
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
                  _TotalHeader(earned: _earned, total: _total),
                  const SizedBox(height: 16),
                  for (final c in _categories) ...[
                    _CategoryBanner(
                      category: c,
                      onTap: () => _openCategory(c),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }
}

/// "Achievements completed: X / Y" header on the soft brand gradient.
class _TotalHeader extends StatelessWidget {
  final int earned;
  final int total;
  const _TotalHeader({required this.earned, required this.total});

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
          const Icon(Icons.emoji_events_rounded,
              color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Achievements completed: $earned / $total',
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

/// One series banner: gold hex emblem, name + tagline, progress %, and
/// the namecard reward preview (locked until 100%).
class _CategoryBanner extends StatelessWidget {
  final MedalCategory category;
  final VoidCallback onTap;
  const _CategoryBanner({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = category;
    final pct = (c.fraction * 100).round();
    final namecard = profileCardThemeById(c.spec.namecardId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: c.completed
                ? _kGold.withValues(alpha: 0.65)
                : AppColors.cardBorder,
            width: c.completed ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Hex emblem with the series icon.
            SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                painter: _HexEmblemPainter(completed: c.completed),
                child: Icon(
                  c.spec.icon,
                  color: c.completed ? Colors.white : _kGoldDark,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.spec.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.spec.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: c.fraction,
                            minHeight: 6,
                            backgroundColor: AppColors.divider,
                            valueColor:
                                const AlwaysStoppedAnimation(_kGold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          color: _kGoldDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Namecard reward preview.
            if (namecard != null)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 64,
                    height: 38,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: ProfileCardScenePainter(namecard),
                          ),
                          if (!c.completed)
                            Container(
                              color: Colors.black.withValues(alpha: 0.40),
                              child: const Icon(
                                Icons.lock_rounded,
                                color: Colors.white70,
                                size: 15,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    c.completed ? 'Namecard ✓' : 'Namecard',
                    style: TextStyle(
                      color: c.completed ? _kGoldDark : AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Gold hexagonal emblem plate behind the series icon; fills solid gold
/// once the series is complete.
class _HexEmblemPainter extends CustomPainter {
  final bool completed;
  const _HexEmblemPainter({required this.completed});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 2;
    Path hex(double radius) {
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        final dx = cx + radius * math.cos(a);
        final dy = cy + radius * math.sin(a);
        i == 0 ? path.moveTo(dx, dy) : path.lineTo(dx, dy);
      }
      return path..close();
    }

    if (completed) {
      canvas.drawPath(
        hex(r),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7D774), Color(0xFFC9971C)],
          ).createShader(Offset.zero & size),
      );
    } else {
      canvas.drawPath(
        hex(r),
        Paint()..color = _kGold.withValues(alpha: 0.10),
      );
    }
    canvas.drawPath(
      hex(r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _kGold.withValues(alpha: completed ? 0.9 : 0.55),
    );
    canvas.drawPath(
      hex(r * 0.82),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _kGold.withValues(alpha: completed ? 0.5 : 0.30),
    );
  }

  @override
  bool shouldRepaint(_HexEmblemPainter old) => old.completed != completed;
}

// ─── Series detail ─────────────────────────────────────────────

/// One series page: the namecard reward up top, completion % under it,
/// then a single row per badge (evolving medals collapse to one row that
/// shows only what's needed for the next tier).
class _CategoryDetailScreen extends StatelessWidget {
  final MedalCategory category;
  const _CategoryDetailScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    final c = category;
    final pct = (c.fraction * 100).round();
    final namecard = profileCardThemeById(c.spec.namecardId);

    return Scaffold(
      appBar: AppBar(title: Text(c.spec.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // Namecard hero.
          if (namecard != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 2.4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: ProfileCardScenePainter(namecard)),
                    if (!c.completed)
                      Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_rounded,
                                color: Colors.white, size: 26),
                            const SizedBox(height: 6),
                            Text(
                              'Complete all achievements to unlock the '
                              '"${namecard.name}" namecard',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kGold,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Namecard unlocked ✓',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Progress percent.
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: c.fraction,
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    valueColor: const AlwaysStoppedAnimation(_kGold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$pct% · ${c.earned}/${c.total}',
                style: const TextStyle(
                  color: _kGoldDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // One row per badge.
          for (final s in c.series) ...[
            _AchievementRow(series: s),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// One badge row, Genshin-style: medal at its current metal, the name and
/// requirement of the NEXT tier to earn (or the final one with a gold
/// check when maxed), tier stars for evolving medals, live progress, and
/// the XP bounty on the right.
class _AchievementRow extends StatelessWidget {
  final MedalSeries series;
  const _AchievementRow({required this.series});

  @override
  Widget build(BuildContext context) {
    final s = series;
    final next = s.next; // null when the series is fully earned
    final shown = next ?? s.levels.last;
    final done = next == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done ? _kGold.withValues(alpha: 0.55) : AppColors.cardBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Medal.series(s, size: 52, showStars: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        shown.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (s.maxLevel > 1) ...[
                      const SizedBox(width: 6),
                      for (int i = 0; i < s.maxLevel; i++)
                        Icon(
                          i < s.level
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 11,
                          color: i < s.level
                              ? _kGold
                              : AppColors.textMuted.withValues(alpha: 0.6),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  shown.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
                if (!done && shown.progressFraction != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: shown.progressFraction,
                            minHeight: 5,
                            backgroundColor: AppColors.divider,
                            valueColor: AlwaysStoppedAnimation(
                                s.anyUnlocked ? s.metal.color : _kGold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${shown.progressCurrent}/${shown.progressTarget}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
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
          const SizedBox(width: 10),
          if (done)
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF7D774), Color(0xFFC9971C)],
                ),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 18),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+${shown.xpReward} XP',
                style: const TextStyle(
                  color: _kGoldDark,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
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
        SkeletonBox(height: 74, radius: 20),
        SizedBox(height: 16),
        SkeletonBox(height: 96, radius: 18),
        SizedBox(height: 12),
        SkeletonBox(height: 96, radius: 18),
        SizedBox(height: 12),
        SkeletonBox(height: 96, radius: 18),
        SizedBox(height: 12),
        SkeletonBox(height: 96, radius: 18),
        SizedBox(height: 12),
        SkeletonBox(height: 96, radius: 18),
      ],
    );
  }
}

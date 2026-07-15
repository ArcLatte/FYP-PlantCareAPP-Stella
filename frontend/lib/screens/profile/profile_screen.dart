import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../models/achievement.dart';
import '../../models/medal_series.dart';
import '../../models/plant_stage.dart';
import '../../models/streak.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/medal.dart';
import '../../widgets/pot.dart';
import '../../widgets/profile_card_scenes.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/streak_plant.dart';
import '../../widgets/tier_frame.dart';

const String _kMedalSlotsKey = 'medal_case_slots';
const double _kShellNavClearance = 112;

/// Honeycomb display case rows (top → bottom): a hex-gem silhouette with
/// the widest band through the middle. Total = backend PIN_CAP.
const List<int> _kHiveRows = [4, 5, 4];
const int _kSlotCount = 13;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  Streak? _streak;
  List<MedalSeries> _series = [];
  Set<String> _namecards = {}; // unlocked namecard theme ids
  List<String?> _slots = List.filled(_kSlotCount, null);
  bool _isLoading = true;
  SharedPreferences? _prefs;
  String _cardThemeId = 'auto';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _prefs ??= await SharedPreferences.getInstance();
    _cardThemeId = _prefs!.getString(kCardThemePrefKey) ?? 'auto';

    // Load endpoints independently so one failure can't hide the others.
    UserProfile? profile;
    List<Achievement> pinned = const [];
    String? error;
    try {
      profile = await ApiService.getProfile();
    } catch (e) {
      error = 'profile: $e';
    }
    List<MedalSeries> series = const [];
    Set<String> namecards = const {};
    try {
      final all = await ApiService.getAchievements();
      pinned = all.where((a) => a.isPinned).toList();
      series = MedalSeries.fromAchievements(all);
      namecards = {
        for (final c in MedalCategory.fromSeries(series))
          if (c.completed) c.spec.namecardId,
      };
    } catch (e) {
      error = error == null ? 'achievements: $e' : '$error; achievements: $e';
    }
    // Namecards bought in the Seed Shop unlock in the card picker alongside
    // the achievement ones. Decorative — a failure here is silent.
    try {
      final shop = await ApiService.getShop();
      namecards = {
        ...namecards,
        for (final c in shop.items)
          if (c.owned && c.isNamecard && c.themeId != null) c.themeId!,
      };
    } catch (_) {}
    // Streak feeds the hero-card companion (stage + equipped pot) —
    // purely decorative, so a failure here is silent.
    Streak? streak;
    try {
      streak = await ApiService.getStreak();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _streak = streak;
      _series = series;
      _namecards = namecards;
      _slots = _reconcileSlots(pinned);
      _isLoading = false;
    });
    if (error != null) {
      AppSnackBar.error(context, 'Profile load failed — $error');
    }
  }

  /// Merge the locally-saved slot arrangement with the backend's pinned
  /// set: stale/duplicate codes are cleared, and pins with no saved slot
  /// flow into the first empty cells.
  List<String?> _reconcileSlots(List<Achievement> pinned) {
    final slots = List<String?>.filled(_kSlotCount, null);
    final raw = _prefs?.getString(_kMedalSlotsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        for (var i = 0; i < _kSlotCount && i < decoded.length; i++) {
          slots[i] = decoded[i] as String?;
        }
      } catch (_) {}
    }
    final pinnedCodes = {for (final a in pinned) a.code};
    final seen = <String>{};
    for (var i = 0; i < _kSlotCount; i++) {
      final code = slots[i];
      if (code == null) continue;
      if (!pinnedCodes.contains(code) || !seen.add(code)) slots[i] = null;
    }
    for (final code in pinnedCodes) {
      if (seen.contains(code)) continue;
      final empty = slots.indexOf(null);
      if (empty == -1) break;
      slots[empty] = code;
    }
    return slots;
  }

  Future<void> _saveSlots() async {
    await _prefs?.setString(_kMedalSlotsKey, jsonEncode(_slots));
  }

  MedalSeries? _seriesForCode(String code) {
    for (final s in _series) {
      if (s.levels.any((l) => l.code == code)) return s;
    }
    return null;
  }

  /// Tap on a display-case cell: pick a medal for the slot (pinning it),
  /// or clear the slot (unpinning).
  Future<void> _onSlotTap(int index) async {
    final currentCode = _slots[index];
    // Compare by series (not achievement code): a slot may hold an older
    // level's code after the series evolved, but it still displays that
    // series — don't offer it for a second cell.
    final displayedSeries = {
      for (final code in _slots.whereType<String>()) _seriesForCode(code)?.id,
    };
    final available = _series
        .where(
          (s) =>
              s.anyUnlocked &&
              s.current != null &&
              !displayedSeries.contains(s.id),
        )
        .toList()
      ..sort((a, b) => b.metal.index.compareTo(a.metal.index));

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SlotPickerSheet(
        current: currentCode == null ? null : _seriesForCode(currentCode),
        available: available,
      ),
    );
    if (result == null || !mounted) return;

    try {
      if (result == _SlotPickerSheet.kRemove) {
        if (currentCode == null) return;
        await ApiService.unpinAchievement(currentCode);
        setState(() => _slots[index] = null);
      } else {
        final picked = _series.firstWhere((s) => s.id == result);
        final code = picked.current!.code;
        if (currentCode != null) {
          await ApiService.unpinAchievement(currentCode);
        }
        if (!picked.current!.isPinned) {
          await ApiService.pinAchievement(code);
        }
        setState(() => _slots[index] = code);
      }
      await _saveSlots();
      _load(); // re-sync pinned state
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        e,
        fallback: 'Could not update your profile. Please try again.',
      );
    }
  }

  Future<void> _openAchievements() async {
    await context.push('/profile/achievements');
    _load();
  }

  /// Bottom-sheet gallery of card backgrounds: tier scenes plus the
  /// namecards earned by completing achievement categories. Locked themes
  /// preview greyed with their unlock condition; the choice persists
  /// locally.
  Future<void> _pickCardTheme() async {
    final profile = _profile;
    if (profile == null) return;
    final tierIdx = TierFrame.tierIndex(profile.tier);

    Widget grid(List<Widget> tiles) => GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        );

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Card background',
                  style: Theme.of(sheetCtx).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Rank up tiers for scenes · earn namecards from '
                  'achievement series or the Seed Shop.',
                  style: Theme.of(sheetCtx).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        grid([
                          _ThemeTile(
                            id: 'auto',
                            theme: kProfileCardThemes[tierIdx],
                            label: 'Auto · match tier',
                            locked: false,
                            selected: _cardThemeId == 'auto',
                          ),
                          for (final t in kProfileCardThemes)
                            _ThemeTile(
                              id: t.id,
                              theme: t,
                              label: t.name,
                              locked: t.tierIndex > tierIdx,
                              lockLabel: 'Reach ${t.tierName}',
                              selected: _cardThemeId == t.id,
                            ),
                        ]),
                        const SizedBox(height: 16),
                        Text(
                          'ACHIEVEMENT NAMECARDS',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        grid([
                          for (final t in kNamecardThemes)
                            _ThemeTile(
                              id: t.id,
                              theme: t,
                              label: t.name,
                              locked: !_namecards.contains(t.id),
                              lockLabel: 'Complete ${t.namecardOf}',
                              selected: _cardThemeId == t.id,
                            ),
                        ]),
                        const SizedBox(height: 16),
                        Text(
                          'SEED SHOP NAMECARDS',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        grid([
                          for (final t in kShopNamecardThemes)
                            _ThemeTile(
                              id: t.id,
                              theme: t,
                              label: t.name,
                              locked: !_namecards.contains(t.id),
                              lockLabel: 'Find it in the Seed Shop',
                              selected: _cardThemeId == t.id,
                            ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null) return;
    await _prefs?.setString(kCardThemePrefKey, picked);
    if (mounted) setState(() => _cardThemeId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + _kShellNavClearance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () async {
              await context.push('/profile/settings');
              _load(); // avatar / username may have changed
            },
          ),
        ],
      ),
      body: _isLoading
          ? const _ProfileSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
                children: [
                  if (_profile != null) ...[
                    _CompanionCard(
                      profile: _profile!,
                      streak: _streak,
                      theme: resolveProfileCardTheme(
                        _cardThemeId == 'auto' ? null : _cardThemeId,
                        _profile!.tier,
                        unlockedNamecards: _namecards,
                      ),
                      onEditTheme: _pickCardTheme,
                    ),
                    const SizedBox(height: 16),
                    _StatsGrid(profile: _profile!),
                    const SizedBox(height: 12),
                    _ShopRow(
                      seeds: _profile!.seeds,
                      onTap: () async {
                        await context.push('/profile/shop');
                        _load(); // seeds may have been spent
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  _SectionHeader(
                    title: 'Medal display case',
                    actionLabel: 'Achievements',
                    onAction: _openAchievements,
                  ),
                  const SizedBox(height: 12),
                  _MedalCase(
                    slots: _slots,
                    seriesForCode: _seriesForCode,
                    onSlotTap: _onSlotTap,
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Companion hero card ───────────────────────────────────────

/// Gacha-style identity card: an illustrated tier scene behind a framed
/// avatar + level badge, the streak companion (wearing its equipped pot)
/// standing on the painted hill, an animated XP bar with a shine sweep, and
/// a "next tier" goal line. The palette button opens the background picker.
class _CompanionCard extends StatefulWidget {
  final UserProfile profile;
  final Streak? streak;
  final ProfileCardTheme theme;
  final VoidCallback onEditTheme;

  const _CompanionCard({
    required this.profile,
    required this.streak,
    required this.theme,
    required this.onEditTheme,
  });

  @override
  State<_CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<_CompanionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  /// Next tier on the ladder, or null at the top. Thresholds mirror
  /// [TierFrame.tierForLevel].
  static (int, String)? _nextTier(int level) {
    const steps = [
      (5, 'Sprout'),
      (10, 'Sapling'),
      (20, 'Gardener'),
      (35, 'Cultivator'),
      (50, 'Botanist'),
      (75, 'Plantsmith'),
      (100, 'Garden Sage'),
    ];
    for (final (lv, name) in steps) {
      if (level < lv) return (lv, name);
    }
    return null;
  }

  static Widget _avatarInitial(UserProfile profile) => Text(
        profile.username.isEmpty ? '?' : profile.username[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final tierColor = TierFrame.tierColor(profile.tier);
    final next = _nextTier(profile.level);
    final stage = PlantStage.forStreak(profile.currentStreak);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 204,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ProfileCardScenePainter(widget.theme),
              ),
            ),
            // The companion stands on the painted front hill. It reuses the
            // self-animating streak plant, so it blinks, sways, and pops
            // hearts when petted — the profile doubles as a character screen.
            Positioned(
              right: 6,
              bottom: 26,
              child: StreakPlant(
                stage: stage,
                size: 104,
                potStyle: PotStyle.fromPayload(widget.streak?.equippedPot),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: widget.onEditTheme,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.palette_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          TierFrame(
                            tier: profile.tier,
                            size: 78,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: profile.avatarUrl != null
                                  ? Image.network(
                                      profile.avatarUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (_, _, _) =>
                                          _avatarInitial(profile),
                                    )
                                  : _avatarInitial(profile),
                            ),
                          ),
                          Positioned(
                            right: -4,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: tierColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Lv ${profile.level}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(
                                    color: Color(0x55000000),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: tierColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      profile.tier,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              next == null
                                  ? 'Highest tier reached ✦'
                                  : 'Next tier: ${next.$2} · Lv ${next.$1}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x55000000),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // XP bar stops short of the companion's hill spot.
                  Padding(
                    padding: const EdgeInsets.only(right: 112),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedBuilder(
                          animation: _shine,
                          builder: (context, _) => _XpBar(
                            fraction: profile.progressFraction,
                            accent: widget.theme.accent,
                            shine: _shine.value,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _CountUpText(
                          value: profile.xpIntoLevel,
                          suffix:
                              ' / ${profile.xpForNextLevel} XP to Lv. ${profile.level + 1}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(color: Color(0x55000000), blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated XP bar: the fill eases out to its value on load and a soft
/// shine sweeps across the filled part once per pulse cycle.
class _XpBar extends StatelessWidget {
  final double fraction;
  final Color accent;
  final double shine;

  const _XpBar({
    required this.fraction,
    required this.accent,
    required this.shine,
  });

  static const double _h = 12;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_h),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, f, child) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: f.clamp(0.0, 1.0),
                child: child,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white, accent]),
                  borderRadius: BorderRadius.circular(_h),
                ),
                child: fraction > 0.05 && shine < 0.4
                    ? Align(
                        alignment: Alignment(-1.3 + 2.6 * (shine / 0.4), 0),
                        child: Container(
                          width: 14,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Integer count-up: rolls from 0 to [value] once on first build.
class _CountUpText extends StatelessWidget {
  final int value;
  final String suffix;
  final TextStyle style;

  const _CountUpText({
    required this.value,
    this.suffix = '',
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// One selectable background in the picker sheet: a live-painted preview
/// with lock / selected states.
class _ThemeTile extends StatelessWidget {
  final String id;
  final ProfileCardTheme theme;
  final String label;
  final bool locked;
  final String? lockLabel;
  final bool selected;

  const _ThemeTile({
    required this.id,
    required this.theme,
    required this.label,
    required this.locked,
    this.lockLabel,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked ? null : () => Navigator.pop(context, id),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: ProfileCardScenePainter(theme)),
              Positioned(
                left: 8,
                bottom: 6,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)],
                  ),
                ),
              ),
              if (selected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              if (locked)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          lockLabel ?? 'Reach ${theme.tierName}',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stats grid ────────────────────────────────────────────────

/// 2×2 grid of soft stat tiles — same tinted-icon language as the plant
/// detail status card and the Tasks screen.
class _StatsGrid extends StatelessWidget {
  final UserProfile profile;
  const _StatsGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.amber,
                label: 'CURRENT STREAK',
                value: '${profile.currentStreak} days',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.bolt_rounded,
                color: const Color(0xFF4F9FD9),
                label: 'LONGEST STREAK',
                value: '${profile.longestStreak} days',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFE5A722),
                label: 'MEDALS',
                value:
                    '${profile.achievementsUnlocked} / ${profile.achievementsTotal}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.primary,
                label: 'TOTAL XP',
                value: '${profile.xp}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

/// Full-width Seed Shop entry: balance on the left, chevron to the shop.
class _ShopRow extends StatelessWidget {
  final int seeds;
  final VoidCallback onTap;
  const _ShopRow({required this.seeds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.spa_rounded,
                color: AppColors.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seed Shop',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Spend seeds on pots and namecards',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$seeds',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        GestureDetector(
          onTap: onAction,
          child: Row(
            children: [
              Text(
                actionLabel,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Medal display case ────────────────────────────────────────

/// Honeycomb display case: twelve hexagonal cells in 3/4/5 hive rows.
/// Each cell holds one medal of the user's choosing — tap a cell to fill,
/// swap, or clear it. The arrangement persists locally; the pinned set
/// syncs with the backend.
class _MedalCase extends StatelessWidget {
  final List<String?> slots;
  final MedalSeries? Function(String code) seriesForCode;
  final void Function(int index) onSlotTap;

  const _MedalCase({
    required this.slots,
    required this.seriesForCode,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = slots.whereType<String>().length;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // The widest row spans the full width; everything else
            // derives from the hex circumradius.
            final widest = _kHiveRows.reduce(math.max);
            final hexR = w / (widest * math.sqrt(3));
            final hexW = hexR * math.sqrt(3);
            final height = hexR * (2 + 1.5 * (_kHiveRows.length - 1));

            final cells = <Widget>[];
            var slot = 0;
            for (var row = 0; row < _kHiveRows.length; row++) {
              final n = _kHiveRows[row];
              final cy = hexR + row * 1.5 * hexR;
              for (var j = 0; j < n; j++) {
                final cx = w / 2 + (j - (n - 1) / 2) * hexW;
                final index = slot++;
                final code = slots[index];
                cells.add(
                  Positioned(
                    left: cx - hexW / 2,
                    top: cy - hexR,
                    width: hexW,
                    height: hexR * 2,
                    child: _HexSlot(
                      series: code == null ? null : seriesForCode(code),
                      radius: hexR,
                      onTap: () => onSlotTap(index),
                    ),
                  ),
                );
              }
            }
            return SizedBox(
              height: height,
              child: Stack(clipBehavior: Clip.none, children: cells),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          '$filled / ${slots.length} on display · tap a cell to arrange',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// One honeycomb cell: an outlined hexagon holding a medal, or a faint
/// "+" invite when empty.
class _HexSlot extends StatelessWidget {
  final MedalSeries? series;
  final double radius;
  final VoidCallback onTap;

  const _HexSlot({
    required this.series,
    required this.radius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = series;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _HexCellPainter(tint: s?.metal.color),
        child: Center(
          child: s == null
              ? Icon(
                  Icons.add_rounded,
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  size: radius * 0.5,
                )
              : Medal.series(
                  s,
                  size: radius * 1.35,
                  showStars: false,
                  glow: s.metal.index >= MedalMetal.gold.index,
                ),
        ),
      ),
    );
  }
}

/// Paints the hexagonal cell for the light theme: a white honeycomb face
/// with a honey-gold outline, warmed by a soft metal-tinted glow when the
/// cell holds a medal.
class _HexCellPainter extends CustomPainter {
  final Color? tint; // metal color when the cell is filled

  const _HexCellPainter({this.tint});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width / math.sqrt(3), size.height / 2) - 1.5;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final p = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();

    if (tint != null) {
      canvas.drawPath(path, Paint()..color = AppColors.surface);
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [
              tint!.withValues(alpha: 0.20),
              tint!.withValues(alpha: 0.04),
            ],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
    } else {
      canvas.drawPath(
        path,
        Paint()..color = AppColors.surface.withValues(alpha: 0.65),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(
          0xFFD9B44A,
        ).withValues(alpha: tint != null ? 0.75 : 0.40),
    );
  }

  @override
  bool shouldRepaint(_HexCellPainter old) => old.tint != tint;
}

/// Bottom sheet for one display-case cell: the current occupant (with a
/// remove action) and a grid of unlocked medals to place instead.
class _SlotPickerSheet extends StatelessWidget {
  static const String kRemove = '__remove__';

  final MedalSeries? current;
  final List<MedalSeries> available;

  const _SlotPickerSheet({required this.current, required this.available});

  @override
  Widget build(BuildContext context) {
    final cur = current;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.70,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Display case',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                cur == null
                    ? 'Choose a medal for this cell.'
                    : 'Swap or remove the medal in this cell.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (cur != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Medal.series(cur, size: 44, showStars: false),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cur.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${cur.metal.label} · Lv ${cur.level}/${cur.maxLevel}',
                              style: TextStyle(
                                color: cur.metal.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context, kRemove),
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('Remove'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (available.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'No more unlocked medals to display —\nearn new ones in the achievement book!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Flexible(
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.86,
                    children: [
                      for (final s in available)
                        GestureDetector(
                          onTap: () => Navigator.pop(context, s.id),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Medal.series(s, size: 48, showStars: false),
                                const SizedBox(height: 6),
                                Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${s.metal.label} · Lv ${s.level}',
                                  style: TextStyle(
                                    color: s.metal.color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + _kShellNavClearance;

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      children: const [
        SkeletonBox(height: 204, radius: 24),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
          ],
        ),
        SizedBox(height: 12),
        SkeletonBox(height: 68, radius: 16),
        SizedBox(height: 24),
        SkeletonBox(width: 180, height: 22, radius: 8),
        SizedBox(height: 12),
        SkeletonBox(height: 240, radius: 20),
      ],
    );
  }
}

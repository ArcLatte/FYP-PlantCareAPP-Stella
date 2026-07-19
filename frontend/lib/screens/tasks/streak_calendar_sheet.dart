import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/streak.dart';
import '../../services/api_service.dart';

/// Duolingo-style streak calendar popup, opened from the day strip on the
/// Tasks page: streak stat cards on top, then a single month with ‹ › arrows
/// to browse back through the care history. Cared-for days are water-blue
/// dots joined by connectors flowing across consecutive days — the same
/// visual language as the day strip.
Future<void> showStreakCalendarSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _StreakCalendarSheet(),
  );
}

// Same palette as the Tasks day strip: water-blue cared days, ice for
// save-shielded days.
const Color _kWater = Color(0xFF4F9FD9);
const Color _kIce = Color(0xFF9CCFEE);

class _StreakCalendarSheet extends StatefulWidget {
  const _StreakCalendarSheet();

  @override
  State<_StreakCalendarSheet> createState() => _StreakCalendarSheetState();
}

class _StreakCalendarSheetState extends State<_StreakCalendarSheet> {
  StreakCalendar? _calendar;
  bool _isLoading = true;
  String? _error;
  late DateTime _visibleMonth; // first day of the month on display

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final cal = await ApiService.getStreakCalendar();
      if (!mounted) return;
      setState(() {
        _calendar = cal;
        // Open on the server's current month (care days are recorded on the
        // server clock), so a device a day/month off doesn't land the user
        // on the wrong page.
        final t = cal.today;
        if (t != null) _visibleMonth = DateTime(t.year, t.month);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your streak calendar.';
        _isLoading = false;
      });
    }
  }

  /// Oldest month worth browsing to: the month of the first-ever care day
  /// (falls back to the current month when there's no history yet).
  DateTime get _earliestMonth {
    final cal = _calendar;
    var first = _currentMonth;
    if (cal == null) return first;
    for (final d in cal.careDates) {
      final m = DateTime(d.year, d.month);
      if (m.isBefore(first)) first = m;
    }
    return first;
  }

  DateTime get _currentMonth {
    final t = _calendar?.today;
    if (t != null) return DateTime(t.year, t.month);
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  bool get _canGoBack => _visibleMonth.isAfter(_earliestMonth);
  bool get _canGoForward => _visibleMonth.isBefore(_currentMonth);

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  /// Days of the currently shielded gap (after the last care day, before
  /// today) — shown as ice dots, matching the day strip.
  Set<DateTime> _frozenDays(StreakCalendar cal, DateTime today) {
    return cal.frozenDates.where((day) => !day.isAfter(today)).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      // Full width always: without this the sheet shrinks to its content, so
      // the loading state (just a spinner) renders as a thin sliver.
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle (centered despite the stretched column).
            const Align(alignment: Alignment.center, child: _DragHandle()),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 90),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _load)
            else
              ..._buildContent(_calendar!),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(StreakCalendar cal) {
    // Prefer the server's date (care days are recorded on the server clock);
    // fall back to the device date when it isn't sent.
    final t = cal.today;
    final today = t != null
        ? DateTime(t.year, t.month, t.day)
        : () {
            final now = DateTime.now();
            return DateTime(now.year, now.month, now.day);
          }();
    final frozen = _frozenDays(cal, today);
    return [
      Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.water_drop_rounded,
              color: _kWater,
              value: cal.currentStreak,
              label: 'Current streak',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.emoji_events_rounded,
              color: AppColors.amber,
              value: cal.longestStreak,
              label: 'Longest streak',
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _MonthNav(
        month: _visibleMonth,
        canGoBack: _canGoBack,
        canGoForward: _canGoForward,
        onShift: _shiftMonth,
      ),
      const SizedBox(height: 12),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _MonthGrid(
          key: ValueKey(_visibleMonth),
          month: _visibleMonth,
          care: cal.careDates,
          frozen: frozen,
          today: today,
        ),
      ),
      if (cal.careDates.isEmpty) ...[
        const SizedBox(height: 8),
        const Text(
          'Water a plant to start your streak — every cared-for day '
          'will show up here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ];
  }
}

/// "‹  JULY 2026  ›" month switcher; arrows grey out at the ends of the
/// browsable range (first care month ↔ current month).
class _MonthNav extends StatelessWidget {
  final DateTime month;
  final bool canGoBack;
  final bool canGoForward;
  final ValueChanged<int> onShift;
  const _MonthNav({
    required this.month,
    required this.canGoBack,
    required this.canGoForward,
    required this.onShift,
  });

  static const _monthNames = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY',
    'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

  Widget _arrow(IconData icon, bool enabled, VoidCallback onTap) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(
        icon,
        size: 22,
        color: enabled
            ? AppColors.textSecondary
            : AppColors.textMuted.withValues(alpha: 0.4),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _arrow(Icons.chevron_left_rounded, canGoBack, () => onShift(-1)),
        Expanded(
          child: Center(
            child: Text(
              '${_monthNames[month.month - 1]} ${month.year}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        _arrow(Icons.chevron_right_rounded, canGoForward, () => onShift(1)),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value ${value == 1 ? 'day' : 'days'}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One month: Monday-first weekday initials, then week rows where cared days
/// are filled water dots joined by connector bars (ice dots for
/// save-shielded days), mirroring the day strip on the Tasks page.
class _MonthGrid extends StatelessWidget {
  final DateTime month; // first day of the month
  final Set<DateTime> care;
  final Set<DateTime> frozen;
  final DateTime today;
  const _MonthGrid({
    super.key,
    required this.month,
    required this.care,
    required this.frozen,
    required this.today,
  });

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month, 1).weekday - 1; // Mon=0
    final rows = ((leading + daysInMonth) / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (final d in _initials)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (int r = 0; r < rows; r++) _buildWeekRow(r, leading, daysInMonth),
      ],
    );
  }

  Widget _buildWeekRow(int row, int leading, int daysInMonth) {
    return Row(
      children: List.generate(7, (col) {
        final dayNum = row * 7 + col - leading + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const Expanded(child: SizedBox(height: _kCellH));
        }
        final date = DateTime(month.year, month.month, dayNum);
        bool inChain(int n) {
          if (n < 1 || n > daysInMonth) return false;
          final d = DateTime(month.year, month.month, n);
          return care.contains(d) || frozen.contains(d);
        }

        final chainHere = inChain(dayNum);
        return Expanded(
          child: _CalendarDayCell(
            day: dayNum,
            lit: care.contains(date),
            frozen: frozen.contains(date),
            isToday: date == today,
            isFuture: date.isAfter(today),
            litLeft: col > 0 && chainHere && inChain(dayNum - 1),
            litRight: col < 6 && chainHere && inChain(dayNum + 1),
          ),
        );
      }),
    );
  }
}

const double _kCellH = 42;

/// One calendar day, drawn like the day strip's dots: connector bars behind
/// a circle — filled water-blue when cared for, ice when save-shielded, a
/// water ring for an uncared today, muted plain text otherwise.
class _CalendarDayCell extends StatelessWidget {
  final int day;
  final bool lit;
  final bool frozen;
  final bool isToday;
  final bool isFuture;
  final bool litLeft;
  final bool litRight;
  const _CalendarDayCell({
    required this.day,
    required this.lit,
    required this.frozen,
    required this.isToday,
    required this.isFuture,
    required this.litLeft,
    required this.litRight,
  });

  static const double _d = 30; // circle diameter
  static const double _barH = 6; // connector thickness

  Widget _bar(bool on) => Expanded(
    child: on
        ? Container(height: _barH, color: _kWater.withValues(alpha: 0.45))
        : const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color textColor;
    Border? border;
    if (lit) {
      fill = _kWater;
      textColor = Colors.white;
    } else if (frozen) {
      fill = _kIce;
      textColor = Colors.white;
    } else {
      fill = Colors.transparent;
      textColor = isFuture
          ? AppColors.textMuted.withValues(alpha: 0.55)
          : AppColors.textSecondary;
      if (isToday) border = Border.all(color: _kWater, width: 2);
    }

    return SizedBox(
      height: _kCellH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(children: [_bar(litLeft), _bar(litRight)]),
          Container(
            width: _d,
            height: _d,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: border,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: textColor,
                fontSize: 12.5,
                fontWeight:
                    lit || frozen || isToday ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Shared widgets + helpers used by both the History landing
/// (`history_screen.dart`) and the per-day detail (`history_detail_screen.dart`).
/// Single source of truth for the rail/dot styling and date formatting.

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Bucket a [DateTime] into a human-friendly date label
/// ("Today" / "Yesterday" / "10 Jun" / "10 Jun 2025").
String dateBucket(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final y = d.year != now.year ? ' ${d.year}' : '';
  return '${d.day} ${_months[d.month - 1]}$y';
}

/// 12-hour clock label, e.g. "3:42 PM".
String timeLabel(DateTime d) {
  final l = d.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  return '$h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
}

/// Lowercase plant-disease label tidy-up.
String formatScanLabel(String label) =>
    label.replaceAll('_', ' ').replaceAll('Tomato ', '').trim();

/// ISO date param, e.g. "2026-06-08", used in `/history/<activity>/<date>` URLs.
String isoDate(DateTime d) {
  final l = DateTime(d.year, d.month, d.day);
  final m = l.month.toString().padLeft(2, '0');
  final day = l.day.toString().padLeft(2, '0');
  return '${l.year}-$m-$day';
}

/// Section header above each day in a timeline.
class DateHeader extends StatelessWidget {
  final String label;
  const DateHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// One row of the timeline: a left rail (connecting line + dot) and an
/// event card. The line is drawn full-height; the top half is hidden for
/// the first item in a group and the bottom half for the last, so days
/// form continuous runs.
class TimelineTile extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingCount;
  final bool showChevron;
  final VoidCallback onTap;

  const TimelineTile({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingCount,
    required this.showChevron,
    required this.onTap,
  });

  static const double _railWidth = 36;
  static const double _dotSize = 28;
  static const double _topSegment = 6;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _railWidth,
            child: Column(
              children: [
                SizedBox(
                  height: _topSegment,
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isFirst ? Colors.transparent : AppColors.divider,
                    ),
                  ),
                ),
                Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 15),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : AppColors.divider,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (trailingCount != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            trailingCount!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (showChevron)
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/weekly_challenge.dart';

/// Compact Weekly Challenge card for the Tasks screen: one rotating
/// consistency goal per ISO week. Completing it banks a streak save on top
/// of the XP — the card previews both rewards and tracks live progress.
class WeeklyChallengeCard extends StatelessWidget {
  final WeeklyChallenge challenge;
  const WeeklyChallengeCard({super.key, required this.challenge});

  static const Color _ice = Color(0xFF4F9FD9);

  /// The pool's icon-name strings → IconData (same scheme as medals).
  IconData get _icon {
    switch (challenge.icon) {
      case 'event_available':
        return Icons.event_available_rounded;
      case 'volunteer_activism':
        return Icons.volunteer_activism_rounded;
      case 'edit_note':
        return Icons.edit_note_rounded;
      case 'qr_code_scanner':
        return Icons.qr_code_scanner_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  String get _timeLeft {
    final d = challenge.daysLeft;
    if (d <= 0) return 'Last day';
    if (d == 1) return '1 day left';
    return '$d days left';
  }

  @override
  Widget build(BuildContext context) {
    final done = challenge.completed;
    final accent = done ? AppColors.primary : _ice;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.cardBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  done ? Icons.check_circle_rounded : _icon,
                  color: accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'WEEKLY CHALLENGE',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          done ? 'Completed!' : _timeLeft,
                          style: TextStyle(
                            color: done ? AppColors.primary : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  // Fill sweeps in from zero on first build (and animates
                  // between values when progress changes).
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: done ? 1.0 : challenge.fraction),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: accent.withValues(alpha: 0.14),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                done
                    ? '${challenge.target} / ${challenge.target}'
                    : '${challenge.progress} / ${challenge.target}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RewardChip(
                icon: Icons.star_rounded,
                label: '+${challenge.xpReward} XP',
                color: AppColors.amber,
              ),
              const SizedBox(width: 8),
              if (challenge.seedsReward > 0) ...[
                _RewardChip(
                  icon: Icons.spa_rounded,
                  label: '+${challenge.seedsReward}',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
              ],
              if (challenge.saveReward > 0)
                _RewardChip(
                  icon: Icons.ac_unit_rounded,
                  label: '+${challenge.saveReward} save',
                  color: _ice,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _RewardChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

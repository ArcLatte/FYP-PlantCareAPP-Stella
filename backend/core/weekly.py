"""Weekly Challenge service — the consistency loop that mints streak saves.

One challenge is active per ISO week, picked deterministically from a static
pool (rotation by week number, same for every user, so it's testable and needs
no per-user RNG). Progress is computed server-side from `CareLog`/`ScanResult`
rows inside the current week — counting real logged actions, not client
claims, which keeps it farm-resistant.

`check_weekly_challenge(user)` runs after every XP-granting action (alongside
`check_achievements`). On the completion threshold it records a
`WeeklyChallengeProgress` row, grants the XP reward and banks a streak save,
and returns the completion info so the view can include it in the response.
"""

from datetime import timedelta

from django.utils import timezone

from .models import CareLog, ScanResult, WeeklyChallengeProgress

CARE_ACTIVITIES = ('water', 'fertilize', 'mist')

# Seeds paid out on top of XP + streak save when a challenge completes.
SEEDS_REWARD = 40

# The rotating pool. `metric` keys into _metric_value below. Distinct-day /
# note / scan metrics are preferred over raw action counts because they can't
# be tap-farmed on a single plant.
CHALLENGES = [
    dict(
        code='consistent_care',
        name='Consistent Care',
        description='Care for your plants on 5 different days this week.',
        icon='event_available',
        metric='care_days',
        target=5,
        xp_reward=100,
        save_reward=1,
    ),
    dict(
        code='green_thumb_week',
        name='Green Thumb',
        description='Log 15 care actions this week.',
        icon='volunteer_activism',
        metric='care_actions',
        target=15,
        xp_reward=75,
        save_reward=1,
    ),
    dict(
        code='journalist_week',
        name='Journalist',
        description='Add 3 journal notes this week.',
        icon='edit_note',
        metric='notes',
        target=3,
        xp_reward=75,
        save_reward=1,
    ),
    dict(
        code='health_check_week',
        name='Health Check',
        description='Scan 2 leaves for diseases this week.',
        icon='qr_code_scanner',
        metric='scans',
        target=2,
        xp_reward=75,
        save_reward=1,
    ),
]


def week_start(today=None):
    """Monday of the current ISO week."""
    today = today or timezone.localdate()
    return today - timedelta(days=today.weekday())


def current_challenge(today=None):
    """The pool entry active this week — same for all users."""
    today = today or timezone.localdate()
    iso_week = today.isocalendar()[1]
    return CHALLENGES[iso_week % len(CHALLENGES)]


def _week_range(today=None):
    start = week_start(today)
    return start, start + timedelta(days=7)


def _metric_value(user, metric: str) -> int:
    """Progress for one metric inside the current week, counted from logged
    rows (server truth, not client claims)."""
    start, end = _week_range()
    if metric == 'care_days':
        return (
            CareLog.objects
            .filter(user=user, activity__in=CARE_ACTIVITIES,
                    created_at__date__gte=start, created_at__date__lt=end)
            .values('created_at__date').distinct().count()
        )
    if metric == 'care_actions':
        return CareLog.objects.filter(
            user=user, activity__in=CARE_ACTIVITIES,
            created_at__date__gte=start, created_at__date__lt=end,
        ).count()
    if metric == 'notes':
        return CareLog.objects.filter(
            user=user, activity='note',
            created_at__date__gte=start, created_at__date__lt=end,
        ).count()
    if metric == 'scans':
        return ScanResult.objects.filter(
            plant__user=user,
            created_at__date__gte=start, created_at__date__lt=end,
        ).count()
    return 0


def challenge_state(user) -> dict:
    """Snapshot for `GET /api/weekly-challenge/`: the active challenge, the
    user's progress, and whether it's already completed this week."""
    challenge = current_challenge()
    start, end = _week_range()
    completed = WeeklyChallengeProgress.objects.filter(
        user=user, week_start=start,
    ).exists()
    progress = _metric_value(user, challenge['metric'])
    return {
        'code': challenge['code'],
        'name': challenge['name'],
        'description': challenge['description'],
        'icon': challenge['icon'],
        'target': challenge['target'],
        'progress': min(progress, challenge['target']),
        'completed': completed,
        'xp_reward': challenge['xp_reward'],
        'save_reward': challenge['save_reward'],
        'seeds_reward': SEEDS_REWARD,
        'week_start': start,
        'week_end': end - timedelta(days=1),  # inclusive Sunday for display
        'days_left': max(0, (end - timezone.localdate()).days),
    }


def check_weekly_challenge(user) -> dict | None:
    """Complete the week's challenge if the user now qualifies. Grants the
    XP reward and banks the streak save(s). Returns the completion payload
    for the response side-channel, or None if nothing new happened."""
    challenge = current_challenge()
    start = week_start()
    if WeeklyChallengeProgress.objects.filter(user=user, week_start=start).exists():
        return None
    if _metric_value(user, challenge['metric']) < challenge['target']:
        return None

    WeeklyChallengeProgress.objects.create(
        user=user, week_start=start, challenge_code=challenge['code'],
    )
    saves_banked = user.grant_streak_save(challenge['save_reward'])
    user.seeds += SEEDS_REWARD
    user.award_xp(challenge['xp_reward'])  # persists freezes + seeds too
    return {
        'code': challenge['code'],
        'name': challenge['name'],
        'icon': challenge['icon'],
        'xp_reward': challenge['xp_reward'],
        'saves_banked': saves_banked,
        'seeds_reward': SEEDS_REWARD,
    }

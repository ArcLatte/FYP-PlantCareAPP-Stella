"""Achievement check-and-unlock service.

`check_achievements(user)` runs after every XP-granting action. It walks the
predicate registry, looks at the user's current data, and unlocks any
achievements the user now qualifies for — granting their XP rewards and
returning the list so the view can include them in the response.

To add a new achievement: seed it via `seed_achievements`, then register a
predicate here keyed by the same `code`.
"""

from typing import Callable
from .models import (
    Achievement, UserAchievement, Plant, CareLog, ScanResult,
)


# ─── Predicate helpers ──────────────────────────────────────────

def _plants(user):
    return Plant.objects.filter(user=user)


def _care_count(user, activity: str) -> int:
    return CareLog.objects.filter(user=user, activity=activity).count()


def _scans(user):
    return ScanResult.objects.filter(plant__user=user)


def _any_diseased_scan(user) -> bool:
    """True if any of the user's scans is currently marked as a diseased
    condition (confirmed disease that isn't 'healthy', or top prediction
    indicating disease).
    """
    for s in _scans(user).select_related('disease'):
        if s.disease_id:
            label = s.disease.label
        elif s.top3_predictions:
            top = s.top3_predictions[0]
            label = top.get('label') if isinstance(top, dict) else None
        else:
            label = None
        if label and 'healthy' not in label.lower():
            return True
    return False


# ─── Registry ───────────────────────────────────────────────────
# Each predicate takes the user and returns True if they now qualify.
PREDICATES: dict[str, Callable] = {
    'first_plant':     lambda u: _plants(u).count() >= 1,
    'garden_of_five':  lambda u: _plants(u).count() >= 5,
    'green_collector': lambda u: _plants(u).count() >= 10,
    'first_water':     lambda u: _care_count(u, 'water') >= 1,
    'hydration_hero':  lambda u: _care_count(u, 'water') >= 50,
    'first_fertilize': lambda u: _care_count(u, 'fertilize') >= 1,
    'streak_3':        lambda u: u.longest_streak >= 3,
    'streak_7':        lambda u: u.longest_streak >= 7,
    'streak_30':       lambda u: u.longest_streak >= 30,
    'first_scan':      lambda u: _scans(u).count() >= 1,
    'disease_spotter': lambda u: _any_diseased_scan(u),
    'species_explorer':
        lambda u: _plants(u).values('species_id').distinct().count() >= 3,
}


def check_achievements(user) -> list[Achievement]:
    """Unlock any newly-qualifying achievements for `user`. Returns the
    Achievement instances unlocked on this call (may be empty).
    """
    already = set(
        UserAchievement.objects
        .filter(user=user)
        .values_list('achievement__code', flat=True)
    )

    newly: list[Achievement] = []
    for code, predicate in PREDICATES.items():
        if code in already:
            continue
        try:
            qualifies = predicate(user)
        except Exception:
            qualifies = False  # don't let a single predicate explode the flow
        if not qualifies:
            continue
        try:
            ach = Achievement.objects.get(code=code)
        except Achievement.DoesNotExist:
            # Code is registered here but seed hasn't been run — skip silently.
            continue
        UserAchievement.objects.create(user=user, achievement=ach)
        user.award_xp(ach.xp_reward)
        newly.append(ach)
    return newly

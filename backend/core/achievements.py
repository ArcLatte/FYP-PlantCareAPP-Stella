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


def _scan_label(scan) -> str | None:
    """Best-known condition label for a scan: confirmed disease first,
    falling back to the model's top prediction."""
    if scan.disease_id:
        return scan.disease.label
    if scan.top3_predictions:
        top = scan.top3_predictions[0]
        return top.get('label') if isinstance(top, dict) else None
    return None


def _any_diseased_scan(user) -> bool:
    """True if any of the user's scans is currently marked as a diseased
    condition (confirmed disease that isn't 'healthy', or top prediction
    indicating disease).
    """
    for s in _scans(user).select_related('disease'):
        label = _scan_label(s)
        if label and 'healthy' not in label.lower():
            return True
    return False


def _healthy_scan_count(user) -> int:
    return sum(
        1
        for s in _scans(user).select_related('disease')
        if (label := _scan_label(s)) and 'healthy' in label.lower()
    )


def _distinct_species(user) -> int:
    return _plants(user).values('species_id').distinct().count()


# ─── Progress ───────────────────────────────────────────────────

def progress_snapshot(user) -> dict:
    """Counters backing the locked-achievement progress display. Computed
    once per achievements-list request so each metric costs one query no
    matter how many achievements reference it."""
    return {
        'plants': _plants(user).count(),
        'water': _care_count(user, 'water'),
        'fertilize': _care_count(user, 'fertilize'),
        'mist': _care_count(user, 'mist'),
        'streak': user.longest_streak,
        'scans': _scans(user).count(),
        'diseased': 1 if _any_diseased_scan(user) else 0,
        'healthy': _healthy_scan_count(user),
        'species': _distinct_species(user),
        'level': user.level,
    }


# code → (snapshot key, target). Drives the "12/50" progress shown under
# locked medals. Keep targets in sync with PREDICATES below.
PROGRESS: dict[str, tuple[str, int]] = {
    'first_plant':        ('plants', 1),
    'garden_of_five':     ('plants', 5),
    'green_collector':    ('plants', 10),
    'grand_garden':       ('plants', 20),
    'first_water':        ('water', 1),
    'hydration_hero':     ('water', 50),
    'water_centurion':    ('water', 100),
    'first_fertilize':    ('fertilize', 1),
    'fertilizer_fanatic': ('fertilize', 20),
    'first_mist':         ('mist', 1),
    'mist_maestro':       ('mist', 25),
    'streak_3':           ('streak', 3),
    'streak_7':           ('streak', 7),
    'streak_14':          ('streak', 14),
    'streak_30':          ('streak', 30),
    'streak_100':         ('streak', 100),
    'first_scan':         ('scans', 1),
    'scan_addict':        ('scans', 10),
    'disease_spotter':    ('diseased', 1),
    'clean_bill':         ('healthy', 5),
    'species_explorer':   ('species', 3),
    'species_master':     ('species', 6),
    'level_5':            ('level', 5),
    'level_10':           ('level', 10),
}


# ─── Registry ───────────────────────────────────────────────────
# Each predicate takes the user and returns True if they now qualify.
PREDICATES: dict[str, Callable] = {
    # Growth
    'first_plant':     lambda u: _plants(u).count() >= 1,
    'garden_of_five':  lambda u: _plants(u).count() >= 5,
    'green_collector': lambda u: _plants(u).count() >= 10,
    'grand_garden':    lambda u: _plants(u).count() >= 20,
    # Care
    'first_water':     lambda u: _care_count(u, 'water') >= 1,
    'hydration_hero':  lambda u: _care_count(u, 'water') >= 50,
    'water_centurion': lambda u: _care_count(u, 'water') >= 100,
    'first_fertilize': lambda u: _care_count(u, 'fertilize') >= 1,
    'fertilizer_fanatic': lambda u: _care_count(u, 'fertilize') >= 20,
    'first_mist':      lambda u: _care_count(u, 'mist') >= 1,
    'mist_maestro':    lambda u: _care_count(u, 'mist') >= 25,
    # Streak
    'streak_3':        lambda u: u.longest_streak >= 3,
    'streak_7':        lambda u: u.longest_streak >= 7,
    'streak_14':       lambda u: u.longest_streak >= 14,
    'streak_30':       lambda u: u.longest_streak >= 30,
    'streak_100':      lambda u: u.longest_streak >= 100,
    # Scans
    'first_scan':      lambda u: _scans(u).count() >= 1,
    'scan_addict':     lambda u: _scans(u).count() >= 10,
    'disease_spotter': lambda u: _any_diseased_scan(u),
    'clean_bill':      lambda u: _healthy_scan_count(u) >= 5,
    # Variety
    'species_explorer': lambda u: _distinct_species(u) >= 3,
    'species_master':   lambda u: _distinct_species(u) >= 6,
    # Levels
    'level_5':         lambda u: u.level >= 5,
    'level_10':        lambda u: u.level >= 10,
}


# Seeds paid out per unlock, by badge tier (spendable currency — see
# `CustomUser.seeds`). XP rewards stay on the Achievement row.
SEED_REWARDS = {'bronze': 10, 'silver': 25, 'gold': 50}


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
        # Seeds ride along before award_xp so its save() persists both.
        user.seeds += SEED_REWARDS.get(ach.tier, 10)
        user.award_xp(ach.xp_reward)
        newly.append(ach)
    return newly

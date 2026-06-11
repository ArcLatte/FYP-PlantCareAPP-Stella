"""Seed the starter set of Achievements. Idempotent: re-running updates
existing rows by `code` rather than duplicating.

Run: `python manage.py seed_achievements`
"""

from django.core.management.base import BaseCommand
from core.models import Achievement


ACHIEVEMENTS = [
    # ─── Growth (plant count) ───────────────────────────────
    dict(
        code='first_plant',
        name='First Steps',
        description='Add your first plant to Stella.',
        icon='eco',
        tier=Achievement.Tier.BRONZE,
        xp_reward=25,
    ),
    dict(
        code='garden_of_five',
        name='Garden of Five',
        description='Care for 5 plants at once.',
        icon='local_florist',
        tier=Achievement.Tier.BRONZE,
        xp_reward=25,
    ),
    dict(
        code='green_collector',
        name='Green Collector',
        description='Build up a collection of 10 plants.',
        icon='park',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),

    # ─── Care ───────────────────────────────────────────────
    dict(
        code='first_water',
        name='First Drop',
        description='Water a plant for the first time.',
        icon='water_drop',
        tier=Achievement.Tier.BRONZE,
        xp_reward=25,
    ),
    dict(
        code='hydration_hero',
        name='Hydration Hero',
        description='Water plants 50 times.',
        icon='shower',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),
    dict(
        code='first_fertilize',
        name='Plant Food',
        description='Fertilize a plant for the first time.',
        icon='compost',
        tier=Achievement.Tier.BRONZE,
        xp_reward=25,
    ),

    # ─── Streak ─────────────────────────────────────────────
    dict(
        code='streak_3',
        name='On a Roll',
        description='Care for plants 3 days in a row.',
        icon='local_fire_department',
        tier=Achievement.Tier.BRONZE,
        xp_reward=25,
    ),
    dict(
        code='streak_7',
        name='Week Warrior',
        description='Keep a 7-day care streak going.',
        icon='whatshot',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),
    dict(
        code='streak_30',
        name='Month Master',
        description='Hit a 30-day care streak. Legendary.',
        icon='emoji_events',
        tier=Achievement.Tier.GOLD,
        xp_reward=100,
    ),

    # ─── Scans ──────────────────────────────────────────────
    dict(
        code='first_scan',
        name='Plant Doctor',
        description='Run your first plant disease scan.',
        icon='document_scanner',
        tier=Achievement.Tier.BRONZE,
        xp_reward=25,
    ),
    dict(
        code='disease_spotter',
        name='Disease Spotter',
        description='Detect a disease on one of your plants.',
        icon='biotech',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),

    # ─── Variety ────────────────────────────────────────────
    dict(
        code='species_explorer',
        name='Species Explorer',
        description='Own plants of 3 different species.',
        icon='diversity_3',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),
    dict(
        code='species_master',
        name='Species Master',
        description='Own plants of 6 different species.',
        icon='hub',
        tier=Achievement.Tier.GOLD,
        xp_reward=100,
    ),

    # ─── Growth, continued ──────────────────────────────────
    dict(
        code='grand_garden',
        name='Grand Garden',
        description='Grow your collection to 20 plants.',
        icon='forest',
        tier=Achievement.Tier.GOLD,
        xp_reward=100,
    ),

    # ─── Care, continued ────────────────────────────────────
    dict(
        code='water_centurion',
        name='Water Centurion',
        description='Water plants 100 times.',
        icon='waves',
        tier=Achievement.Tier.GOLD,
        xp_reward=100,
    ),
    dict(
        code='first_mist',
        name='Morning Dew',
        description='Mist a plant for the first time.',
        icon='cloud',
        tier=Achievement.Tier.BRONZE,
        xp_reward=25,
    ),
    dict(
        code='mist_maestro',
        name='Mist Maestro',
        description='Mist plants 25 times.',
        icon='air',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),
    dict(
        code='fertilizer_fanatic',
        name='Fertilizer Fanatic',
        description='Fertilize plants 20 times.',
        icon='grass',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),

    # ─── Streak, continued ──────────────────────────────────
    dict(
        code='streak_14',
        name='Fortnight Force',
        description='Keep a 14-day care streak going.',
        icon='bolt',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),
    dict(
        code='streak_100',
        name='Centurion Streak',
        description='Hit a 100-day care streak. Immortal.',
        icon='military_tech',
        tier=Achievement.Tier.GOLD,
        xp_reward=150,
    ),

    # ─── Scans, continued ───────────────────────────────────
    dict(
        code='scan_addict',
        name='Lab Technician',
        description='Run 10 plant disease scans.',
        icon='radar',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),
    dict(
        code='clean_bill',
        name='Clean Bill of Health',
        description='Get 5 healthy scan results.',
        icon='health_and_safety',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),

    # ─── Levels ─────────────────────────────────────────────
    dict(
        code='level_5',
        name='Sprouting Up',
        description='Reach level 5.',
        icon='trending_up',
        tier=Achievement.Tier.BRONZE,
        xp_reward=25,
    ),
    dict(
        code='level_10',
        name='Rising Gardener',
        description='Reach level 10.',
        icon='rocket_launch',
        tier=Achievement.Tier.SILVER,
        xp_reward=50,
    ),
]


class Command(BaseCommand):
    help = 'Seed Achievement rows (idempotent).'

    def handle(self, *args, **options):
        created = 0
        updated = 0
        for spec in ACHIEVEMENTS:
            code = spec.pop('code')
            obj, was_created = Achievement.objects.update_or_create(
                code=code,
                defaults=spec,
            )
            if was_created:
                created += 1
            else:
                updated += 1
            self.stdout.write(f"  {'+' if was_created else '~'} {obj.code}")
        self.stdout.write(self.style.SUCCESS(
            f'Done. {created} created, {updated} updated.'
        ))

"""Seed the cosmetic-shop catalog. Idempotent: re-running updates existing
rows by `code` rather than duplicating (same convention as the other seeds).

Run: `python manage.py seed_cosmetics`

v1 catalog is creature skins only — pure color tints applied to the streak
companion through the ColorFilter channel it already has, so no art assets
are needed. Keep `payload.amount` subtle (≤ 0.5) or the creature's own
colors wash out.
"""

from django.core.management.base import BaseCommand
from core.models import Cosmetic


COSMETICS = [
    # ─── Creature skins (tints) ─────────────────────────────
    dict(
        code='skin_sunset_glow',
        name='Sunset Glow',
        description='A warm evening blush for your companion.',
        kind=Cosmetic.Kind.CREATURE_SKIN,
        rarity=Cosmetic.Rarity.COMMON,
        cost_seeds=80,
        payload={'tint': '#FFB27A', 'amount': 0.30},
        sort=10,
    ),
    dict(
        code='skin_ocean_mist',
        name='Ocean Mist',
        description='Cool coastal blues, fresh as morning dew.',
        kind=Cosmetic.Kind.CREATURE_SKIN,
        rarity=Cosmetic.Rarity.COMMON,
        cost_seeds=80,
        payload={'tint': '#9CCFEE', 'amount': 0.30},
        sort=20,
    ),
    dict(
        code='skin_rose_quartz',
        name='Rose Quartz',
        description='A soft pink shimmer for gentle souls.',
        kind=Cosmetic.Kind.CREATURE_SKIN,
        rarity=Cosmetic.Rarity.COMMON,
        cost_seeds=100,
        payload={'tint': '#F6A8C0', 'amount': 0.30},
        sort=30,
    ),
    dict(
        code='skin_lavender_dream',
        name='Lavender Dream',
        description='Dusk-purple calm, straight from the meadow.',
        kind=Cosmetic.Kind.CREATURE_SKIN,
        rarity=Cosmetic.Rarity.RARE,
        cost_seeds=150,
        payload={'tint': '#C9A8F0', 'amount': 0.35},
        sort=40,
    ),
    dict(
        code='skin_midnight',
        name='Midnight',
        description='Moonlit shadows for night owls.',
        kind=Cosmetic.Kind.CREATURE_SKIN,
        rarity=Cosmetic.Rarity.RARE,
        cost_seeds=150,
        payload={'tint': '#8FA8D8', 'amount': 0.40},
        sort=50,
    ),
    dict(
        code='skin_golden_hour',
        name='Golden Hour',
        description='Radiant gold — the garden’s crown jewel.',
        kind=Cosmetic.Kind.CREATURE_SKIN,
        rarity=Cosmetic.Rarity.EPIC,
        cost_seeds=250,
        payload={'tint': '#FFD867', 'amount': 0.40},
        sort=60,
    ),
]


class Command(BaseCommand):
    help = 'Seed (or update) the cosmetic shop catalog.'

    def handle(self, *args, **options):
        created = updated = 0
        for entry in COSMETICS:
            _, was_created = Cosmetic.objects.update_or_create(
                code=entry['code'],
                defaults={k: v for k, v in entry.items() if k != 'code'},
            )
            if was_created:
                created += 1
            else:
                updated += 1
        self.stdout.write(self.style.SUCCESS(
            f'Cosmetics seeded: {created} created, {updated} updated.'
        ))

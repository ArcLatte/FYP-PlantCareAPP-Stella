"""Seed the cosmetic-shop catalog. Idempotent: re-running updates existing
rows by `code` rather than duplicating (same convention as the other seeds).

Run: `python manage.py seed_cosmetics`

Catalog kinds (all code-drawn client-side, no art assets):
- Creature skins: pure color tints applied to the streak companion through
  the ColorFilter channel it already has. Keep `payload.amount` subtle
  (≤ 0.5) or the creature's own colors wash out.
- Pot styles: colors + pattern for the pot the companion sits in, drawn by
  the client's pot painter. The default terracotta pot is built into the
  client, not sold here.
- Namecards: shop-exclusive profile-card scenes. `theme_id` must match a
  theme id in the client's `kShopNamecardThemes` list.
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

    # ─── Pot styles ─────────────────────────────────────────
    dict(
        code='pot_seafoam',
        name='Seafoam Glaze',
        description='A cool mint glaze, smooth as sea glass.',
        kind=Cosmetic.Kind.POT_STYLE,
        rarity=Cosmetic.Rarity.COMMON,
        cost_seeds=90,
        payload={
            'body': '#A9D8C6', 'rim': '#7FB8A4',
            'accent': '#EFFAF4', 'pattern': 'none',
        },
        sort=110,
    ),
    dict(
        code='pot_sunny_stripes',
        name='Sunny Stripes',
        description='Cream ceramic with hand-painted marigold stripes.',
        kind=Cosmetic.Kind.POT_STYLE,
        rarity=Cosmetic.Rarity.COMMON,
        cost_seeds=90,
        payload={
            'body': '#F4E6C6', 'rim': '#E2A24A',
            'accent': '#E2A24A', 'pattern': 'stripes',
        },
        sort=120,
    ),
    dict(
        code='pot_berry_dots',
        name='Berry Dots',
        description='Blueberry blue, speckled with cream polka dots.',
        kind=Cosmetic.Kind.POT_STYLE,
        rarity=Cosmetic.Rarity.COMMON,
        cost_seeds=100,
        payload={
            'body': '#7FA6D8', 'rim': '#5E86B8',
            'accent': '#F4F0E4', 'pattern': 'dots',
        },
        sort=130,
    ),
    dict(
        code='pot_lavender_wave',
        name='Lavender Wave',
        description='Dusky lilac with a rolling wave of cream.',
        kind=Cosmetic.Kind.POT_STYLE,
        rarity=Cosmetic.Rarity.RARE,
        cost_seeds=160,
        payload={
            'body': '#C3AEE6', 'rim': '#A48CD4',
            'accent': '#F6F2FC', 'pattern': 'wave',
        },
        sort=140,
    ),
    dict(
        code='pot_mossy_stone',
        name='Mossy Stone',
        description='Weathered grey stone, mossy at the rim.',
        kind=Cosmetic.Kind.POT_STYLE,
        rarity=Cosmetic.Rarity.RARE,
        cost_seeds=180,
        payload={
            'body': '#A2A49A', 'rim': '#74927C',
            'accent': '#8FAE84', 'pattern': 'dots',
        },
        sort=150,
    ),
    dict(
        code='pot_gilded_emerald',
        name='Gilded Emerald',
        description='Deep emerald porcelain, banded in gold.',
        kind=Cosmetic.Kind.POT_STYLE,
        rarity=Cosmetic.Rarity.EPIC,
        cost_seeds=280,
        payload={
            'body': '#2E6E4C', 'rim': '#E5C15A',
            'accent': '#E5C15A', 'pattern': 'stripes',
        },
        sort=160,
    ),

    # ─── Namecards (shop-exclusive profile-card scenes) ─────
    dict(
        code='nc_sakura',
        name='Sakura Drift',
        description='Blossom petals adrift on a warm spring evening.',
        kind=Cosmetic.Kind.NAMECARD,
        rarity=Cosmetic.Rarity.RARE,
        cost_seeds=200,
        payload={'theme_id': 'nc_sakura'},
        sort=210,
    ),
    dict(
        code='nc_koi_pond',
        name='Koi Pond',
        description='Still water, lily pads, and a curious koi.',
        kind=Cosmetic.Kind.NAMECARD,
        rarity=Cosmetic.Rarity.RARE,
        cost_seeds=200,
        payload={'theme_id': 'nc_koi'},
        sort=220,
    ),
    dict(
        code='nc_aurora_peaks',
        name='Aurora Peaks',
        description='Ribbons of light over midnight mountains.',
        kind=Cosmetic.Kind.NAMECARD,
        rarity=Cosmetic.Rarity.EPIC,
        cost_seeds=320,
        payload={'theme_id': 'nc_aurora'},
        sort=230,
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

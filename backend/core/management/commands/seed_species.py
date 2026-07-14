"""Seed PlantSpecies with the starter set of 5 commonly-grown crops.

Idempotent: re-running updates existing rows rather than duplicating.

Data sources (consulted at authoring time, not at runtime):
  - Perenual API (CC BY-SA 2.0) — watering cadence, sunlight, indoor flag,
    scientific name. https://perenual.com/docs/api
  - RHS — https://www.rhs.org.uk/
  - Penn State / UMN Extension — fertilizer cadence, temperature range,
    days-to-harvest, growing tips.

Run: python manage.py seed_species
"""

from django.core.management.base import BaseCommand
from core.models import PlantSpecies


SPECIES = [
    dict(
        name='Tomato',
        scientific_name='Solanum lycopersicum',
        # image: https://commons.wikimedia.org/wiki/File:Tomato_je.jpg
        image_path='library/species/tomato.jpg',
        # Sources:
        #   https://perenual.com/  (watering, sunlight)
        #   https://www.rhs.org.uk/vegetables/tomatoes/grow-your-own
        #   https://extension.umn.edu/vegetables/growing-tomatoes
        description=(
            'Warm-season fruiting vegetable. Heavy feeder; needs steady '
            'water and full sun to produce well.'
        ),
        sunlight=PlantSpecies.Sunlight.FULL_SUN,
        recommended_location=PlantSpecies.Location.OUTDOOR,
        temperature_min_c=18,
        temperature_max_c=29,
        default_watering_freq_days=2,
        default_fertilizer_freq_days=14,
        default_misting_freq_days=None,
        days_to_harvest=75,
        growing_tips=(
            'Stake or cage indeterminate varieties. Pinch suckers weekly '
            'and mulch to retain soil moisture. Water at the base, not '
            'overhead, to reduce leaf disease.'
        ),
    ),
    dict(
        name='Potato',
        scientific_name='Solanum tuberosum',
        # image: https://commons.wikimedia.org/wiki/File:Potato_plant_(Solanum_tuberosum).jpg
        image_path='library/species/potato.jpg',
        # Sources:
        #   https://perenual.com/
        #   https://extension.psu.edu/potato-production
        description=(
            'Cool-season tuber crop. Mound soil over emerging stems '
            '("hilling") to encourage tuber formation and prevent greening.'
        ),
        sunlight=PlantSpecies.Sunlight.FULL_SUN,
        recommended_location=PlantSpecies.Location.OUTDOOR,
        temperature_min_c=16,
        temperature_max_c=24,
        default_watering_freq_days=3,
        default_fertilizer_freq_days=21,
        default_misting_freq_days=None,
        days_to_harvest=90,
        growing_tips=(
            'Plant seed potatoes 10–15 cm deep in loose, well-drained soil. '
            'Hill soil around stems every 2–3 weeks. Stop watering once '
            'foliage yellows so skins can set before harvest.'
        ),
    ),
    dict(
        name='Bell Pepper',
        scientific_name='Capsicum annuum',
        # image: https://commons.wikimedia.org/wiki/File:Green-Bell-Peppers.jpg
        image_path='library/species/bell_pepper.jpg',
        # Sources:
        #   https://perenual.com/
        #   https://extension.umn.edu/vegetables/growing-peppers
        description=(
            'Warm-season fruiting vegetable. Slow to start in cool weather; '
            'rewards a long, hot growing season with sweet thick-walled fruit.'
        ),
        sunlight=PlantSpecies.Sunlight.FULL_SUN,
        recommended_location=PlantSpecies.Location.OUTDOOR,
        temperature_min_c=21,
        temperature_max_c=29,
        default_watering_freq_days=3,
        default_fertilizer_freq_days=14,
        default_misting_freq_days=None,
        days_to_harvest=80,
        growing_tips=(
            'Transplant only after night temps stay above 13 °C. Stake '
            'taller plants — heavy fruit can split branches. Pick first '
            'few fruits early to boost overall yield.'
        ),
    ),
    dict(
        name='Corn (Maize)',
        scientific_name='Zea mays',
        # image: https://commons.wikimedia.org/wiki/File:Zea_mays_-_K%C3%B6hler%E2%80%93s_Medizinal-Pflanzen-283.jpg (replaced at download time with a field photo)
        image_path='library/species/corn_maize.jpg',
        # Sources:
        #   https://perenual.com/
        #   https://extension.psu.edu/sweet-corn
        description=(
            'Tall warm-season grass grown for sweet kernels. Wind-pollinated, '
            'so plant in blocks of at least 4×4 rows rather than long single lines.'
        ),
        sunlight=PlantSpecies.Sunlight.FULL_SUN,
        recommended_location=PlantSpecies.Location.OUTDOOR,
        temperature_min_c=16,
        temperature_max_c=32,
        default_watering_freq_days=3,
        default_fertilizer_freq_days=21,
        default_misting_freq_days=None,
        days_to_harvest=80,
        growing_tips=(
            'Plant in blocks for proper pollination. Side-dress with '
            'nitrogen when plants are knee-high. Harvest when silks brown '
            'and a kernel exudes milky liquid when punctured.'
        ),
    ),
    dict(
        name='Strawberry',
        scientific_name='Fragaria × ananassa',
        # image: https://commons.wikimedia.org/wiki/File:Garden_strawberry_(Fragaria_%C3%97_ananassa)_single2.jpg
        image_path='library/species/strawberry.jpg',
        # Sources:
        #   https://perenual.com/
        #   https://www.rhs.org.uk/fruit/strawberries/grow-your-own
        description=(
            'Low-growing perennial fruit. Tolerates containers and indoor '
            'grow lights; appreciates some humidity, hence the misting cadence.'
        ),
        sunlight=PlantSpecies.Sunlight.PARTIAL_SUN,
        recommended_location=PlantSpecies.Location.BOTH,
        temperature_min_c=15,
        temperature_max_c=26,
        default_watering_freq_days=2,
        default_fertilizer_freq_days=14,
        default_misting_freq_days=3,
        days_to_harvest=60,
        growing_tips=(
            'Mulch with straw to keep berries clean and discourage slugs. '
            'Remove runners on first-year plants to direct energy into '
            'fruit. Indoor plants benefit from a light misting between '
            'waterings to mimic humidity.'
        ),
    ),
]


class Command(BaseCommand):
    help = 'Seed PlantSpecies with the starter set of 5 crops (idempotent).'

    def handle(self, *args, **options):
        created = 0
        updated = 0
        for spec in SPECIES:
            # Don't pop() — that would mutate the module-level dict and break
            # a second handle() call in the same process (e.g. from tests).
            defaults = {k: v for k, v in spec.items() if k != 'name'}
            obj, was_created = PlantSpecies.objects.update_or_create(
                name=spec['name'],
                defaults=defaults,
            )
            if was_created:
                created += 1
            else:
                updated += 1
            self.stdout.write(
                f"  {'+' if was_created else '~'} {obj.name}"
            )
        self.stdout.write(self.style.SUCCESS(
            f'Done. {created} created, {updated} updated.'
        ))

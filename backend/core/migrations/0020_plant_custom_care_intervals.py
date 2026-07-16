from django.db import migrations, models


def copy_species_care_intervals(apps, schema_editor):
    Plant = apps.get_model('core', 'Plant')
    for plant in Plant.objects.select_related('species').iterator():
        plant.fertilizer_freq_days = plant.species.default_fertilizer_freq_days
        plant.misting_freq_days = plant.species.default_misting_freq_days
        plant.save(update_fields=['fertilizer_freq_days', 'misting_freq_days'])


def expand_species_descriptions(apps, schema_editor):
    PlantSpecies = apps.get_model('core', 'PlantSpecies')
    descriptions = {
        'Tomato': (
            'Tomatoes are warm-season fruiting plants that thrive in bright, '
            'direct sun and rich, well-drained soil. Their fast growth and '
            'heavy fruit load make consistent watering and feeding especially '
            'important. Most varieties also benefit from support and airflow '
            'to keep stems upright and foliage healthy.'
        ),
        'Potato': (
            'Potatoes are cool-season crops grown for the underground tubers '
            'that form along buried stems. They prefer loose, slightly acidic '
            'soil where tubers can expand without becoming misshapen. Regular '
            'hilling protects developing potatoes from sunlight and prevents greening.'
        ),
        'Bell Pepper': (
            'Bell peppers are compact warm-season plants that produce crisp, '
            'hollow fruit which sweetens and changes colour as it ripens. They '
            'start slowly in cool conditions and perform best with steady warmth, '
            'full sun, and evenly moist soil. Healthy plants can keep fruiting '
            'for many weeks when ripe peppers are picked regularly.'
        ),
        'Corn (Maize)': (
            'Corn is a tall warm-season grass grown for ears of sweet kernels. '
            'Each silk must receive pollen for its kernel to develop, so spacing '
            'and group size directly affect how full the cobs become. It needs '
            'open sun, fertile soil, and reliable moisture during ear formation.'
        ),
        'Strawberry': (
            'Strawberries are low-growing perennial fruit plants that spread '
            'through runners and suit beds, hanging baskets, and containers. '
            'Their shallow roots need dependable moisture without soggy soil. '
            'Flowers require good light and pollination, while clean, dry fruit '
            'benefits from mulch and gentle airflow around the crown.'
        ),
    }
    for name, description in descriptions.items():
        PlantSpecies.objects.filter(name=name).update(description=description)


class Migration(migrations.Migration):
    dependencies = [('core', '0019_plantspecies_image_path')]

    operations = [
        migrations.AddField(
            model_name='plant',
            name='fertilizer_freq_days',
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='plant',
            name='misting_freq_days',
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.RunPython(copy_species_care_intervals, migrations.RunPython.noop),
        migrations.RunPython(expand_species_descriptions, migrations.RunPython.noop),
    ]

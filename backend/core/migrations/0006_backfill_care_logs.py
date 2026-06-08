# Backfill CareLog from existing Plant.last_* timestamps so the History
# timeline has content from day one.

from django.db import migrations


def backfill(apps, schema_editor):
    Plant = apps.get_model('core', 'Plant')
    CareLog = apps.get_model('core', 'CareLog')

    fields = [
        ('last_watered', 'water'),
        ('last_fertilized', 'fertilize'),
        ('last_misted', 'mist'),
    ]
    rows = []
    for plant in Plant.objects.all():
        for field, activity in fields:
            ts = getattr(plant, field)
            if ts is not None:
                rows.append(CareLog(
                    user_id=plant.user_id,
                    plant_id=plant.id,
                    activity=activity,
                    created_at=ts,
                ))
    if rows:
        CareLog.objects.bulk_create(rows)


def noop(apps, schema_editor):
    # Reversing just drops the backfilled rows along with the table; nothing
    # specific to undo here.
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0005_carelog'),
    ]

    operations = [
        migrations.RunPython(backfill, noop),
    ]

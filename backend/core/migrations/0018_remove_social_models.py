from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0017_alter_cosmetic_kind'),
    ]

    operations = [
        migrations.DeleteModel(name='Comment'),
        migrations.DeleteModel(name='PostLike'),
        migrations.DeleteModel(name='Follow'),
        migrations.DeleteModel(name='CommunityMembership'),
        migrations.DeleteModel(name='Post'),
        migrations.DeleteModel(name='Community'),
    ]

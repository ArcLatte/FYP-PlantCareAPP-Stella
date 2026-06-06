from datetime import timedelta
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


class CustomUser(AbstractUser):
    email = models.EmailField(unique=True)
    current_streak = models.PositiveIntegerField(default=0)
    longest_streak = models.PositiveIntegerField(default=0)
    last_care_date = models.DateField(null=True, blank=True)

    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['email']

    def __str__(self):
        return self.email

    def register_care_activity(self):
        """Call after any water/fertilize/mist action. Advances the streak
        at most once per calendar day."""
        today = timezone.localdate()
        if self.last_care_date == today:
            return  # already counted today
        if self.last_care_date == today - timedelta(days=1):
            self.current_streak += 1
        else:
            self.current_streak = 1  # first ever, or a gap broke it
        self.last_care_date = today
        self.longest_streak = max(self.longest_streak, self.current_streak)
        self.save(update_fields=[
            'current_streak', 'longest_streak', 'last_care_date',
        ])

    @property
    def effective_streak(self):
        """Displayed streak: a stale streak reads as broken (0) without
        mutating storage until the next action resets it."""
        if self.last_care_date is None:
            return 0
        today = timezone.localdate()
        if self.last_care_date in (today, today - timedelta(days=1)):
            return self.current_streak
        return 0


class PlantSpecies(models.Model):
    class Sunlight(models.TextChoices):
        FULL_SUN = 'full_sun', 'Full sun'
        PARTIAL_SUN = 'partial_sun', 'Partial sun'
        PARTIAL_SHADE = 'partial_shade', 'Partial shade'
        SHADE = 'shade', 'Shade'

    class Location(models.TextChoices):
        INDOOR = 'indoor', 'Indoor'
        OUTDOOR = 'outdoor', 'Outdoor'
        BOTH = 'both', 'Indoor or outdoor'

    # Existing fields
    name = models.CharField(max_length=100, unique=True)  # e.g. "Tomato"
    growing_tips = models.TextField(blank=True)

    # Identity / blurb
    scientific_name = models.CharField(max_length=120, blank=True)
    description = models.TextField(blank=True)  # 1–2 sentence teaser

    # Environment
    sunlight = models.CharField(max_length=20, choices=Sunlight.choices, blank=True)
    recommended_location = models.CharField(max_length=10, choices=Location.choices, blank=True)
    temperature_min_c = models.IntegerField(null=True, blank=True)
    temperature_max_c = models.IntegerField(null=True, blank=True)

    # Care cadence baselines. NULL means "doesn't apply to this species"
    # and the UI should hide that activity row.
    default_watering_freq_days = models.PositiveIntegerField(default=7)
    default_fertilizer_freq_days = models.PositiveIntegerField(null=True, blank=True)
    default_misting_freq_days = models.PositiveIntegerField(null=True, blank=True)

    # Growth (vegetables / annuals)
    days_to_harvest = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        verbose_name_plural = 'Plant Species'

    def __str__(self):
        return self.name


class Disease(models.Model):
    species = models.ForeignKey(
        PlantSpecies,
        on_delete=models.CASCADE,
        related_name='diseases'
    )
    name = models.CharField(max_length=100)     
    label = models.CharField(max_length=100, unique=True)
    treatment = models.TextField()
    care_tips = models.TextField()

    def __str__(self):
        return self.label


class Location(models.Model):
    """Per-user list of custom location names that show up in the picker.

    Plant.location is stored as a plain string for simplicity; this table
    is purely a suggestion list so custom names persist across plant
    additions.
    """
    user = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='locations'
    )
    name = models.CharField(max_length=50)

    class Meta:
        unique_together = ('user', 'name')
        ordering = ['name']

    def __str__(self):
        return self.name


class Plant(models.Model):
    user = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='plants'
    )
    species = models.ForeignKey(
        PlantSpecies,
        on_delete=models.PROTECT,
        related_name='plants'
    )
    name = models.CharField(max_length=100)       # user-given nickname, e.g. "My Tomato #1"
    date_planted = models.DateField(null=True, blank=True)
    photo = models.ImageField(upload_to='plants/', null=True, blank=True)
    notes = models.TextField(blank=True)
    location = models.CharField(max_length=50, blank=True, default='')
    last_watered = models.DateTimeField(null=True, blank=True)
    last_fertilized = models.DateTimeField(null=True, blank=True)
    last_misted = models.DateTimeField(null=True, blank=True)
    watering_freq_days = models.PositiveIntegerField(default=7)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.species.name})"


class ScanResult(models.Model):
    plant = models.ForeignKey(
        Plant,
        on_delete=models.CASCADE,
        related_name='scans'
    )
    disease = models.ForeignKey(
        Disease,
        on_delete=models.PROTECT,
        related_name='scan_results',
        null=True,
        blank=True
    )
    image = models.ImageField(upload_to='scans/')
    confidence_score = models.FloatField()
    top3_predictions = models.JSONField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Scan #{self.id} — {self.plant.name}"
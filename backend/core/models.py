from datetime import timedelta
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


class CustomUser(AbstractUser):
    email = models.EmailField(unique=True)
    current_streak = models.PositiveIntegerField(default=0)
    longest_streak = models.PositiveIntegerField(default=0)
    last_care_date = models.DateField(null=True, blank=True)

    # Levelling
    xp = models.PositiveIntegerField(default=0)
    level = models.PositiveIntegerField(default=1)

    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['email']

    def __str__(self):
        return self.email

    # ─── Levelling ───────────────────────────────────────────

    @staticmethod
    def xp_threshold(level: int) -> int:
        """Cumulative XP required to *reach* the given level.

        Triangular curve: `100 * N * (N-1) / 2`. Level 2 = 100, Level 5 =
        1000, Level 10 = 4500. One care tap = 5 XP, so this paces nicely.
        """
        return 100 * level * (level - 1) // 2

    @property
    def xp_into_level(self) -> int:
        return self.xp - self.xp_threshold(self.level)

    @property
    def xp_for_next_level(self) -> int:
        return self.xp_threshold(self.level + 1) - self.xp_threshold(self.level)

    @property
    def tier(self) -> str:
        """Plant-themed tier label derived from the current level."""
        L = self.level
        if L < 5:   return 'Seedling'
        if L < 10:  return 'Sprout'
        if L < 20:  return 'Sapling'
        if L < 35:  return 'Gardener'
        if L < 50:  return 'Cultivator'
        if L < 75:  return 'Botanist'
        if L < 100: return 'Plantsmith'
        return 'Garden Sage'

    def award_xp(self, amount: int) -> dict:
        """Grant XP, bumping level past every crossed threshold. Returns the
        delta so views can include `xp_gained` / `leveled_up_to` in their
        response payload.
        """
        if amount <= 0:
            return {'xp_gained': 0, 'leveled_up': False, 'new_level': self.level}
        self.xp += amount
        leveled = False
        while self.xp >= self.xp_threshold(self.level + 1):
            self.level += 1
            leveled = True
        self.save(update_fields=['xp', 'level'])
        return {'xp_gained': amount, 'leveled_up': leveled, 'new_level': self.level}

    # ─── Streak ───────────────────────────────────────────────

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
    class Severity(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'

    species = models.ForeignKey(
        PlantSpecies,
        on_delete=models.CASCADE,
        related_name='diseases'
    )
    name = models.CharField(max_length=100)
    label = models.CharField(max_length=100, unique=True)
    treatment = models.TextField()
    care_tips = models.TextField()

    # Knowledge-base content for the in-app disease detail page. Seeded once
    # via `seed_diseases` (curated from horticulture sources), not fetched at
    # runtime.
    description = models.TextField(blank=True)   # what the disease is
    symptoms = models.TextField(blank=True)      # what to look for
    cause = models.TextField(blank=True)         # pathogen / conditions
    prevention = models.TextField(blank=True)    # how to avoid it
    severity = models.CharField(
        max_length=8, choices=Severity.choices, blank=True
    )
    source_name = models.CharField(max_length=120, blank=True)
    source_url = models.URLField(blank=True)
    image_url = models.URLField(blank=True)      # illustrative reference photo
    # Multiple reference photos for the detail-page carousel + scan-card
    # thumbnails. List of absolute image URLs.
    image_urls = models.JSONField(default=list, blank=True)

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


class CareLog(models.Model):
    """One row per care action performed on a plant. Powers the History
    timeline. Unlike Plant.last_* (which keep only the latest timestamp),
    this preserves every event."""

    class Activity(models.TextChoices):
        WATER = 'water', 'Watered'
        FERTILIZE = 'fertilize', 'Fertilized'
        MIST = 'mist', 'Misted'

    user = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='care_logs',
    )
    plant = models.ForeignKey(
        Plant,
        on_delete=models.CASCADE,
        related_name='care_logs',
    )
    activity = models.CharField(max_length=12, choices=Activity.choices)
    # Plain default (not auto_now_add) so the backfill migration can stamp
    # historical timestamps from existing Plant.last_* fields.
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.activity} — {self.plant.name} @ {self.created_at:%Y-%m-%d}"


class Achievement(models.Model):
    """A badge definition. Seeded via `python manage.py seed_achievements`.

    Codes are stable slugs (`first_plant`, `streak_7`, …) used as the unique
    key in predicates and on the frontend.
    """

    class Tier(models.TextChoices):
        BRONZE = 'bronze', 'Bronze'
        SILVER = 'silver', 'Silver'
        GOLD = 'gold', 'Gold'

    code = models.CharField(max_length=40, unique=True)
    name = models.CharField(max_length=80)
    description = models.CharField(max_length=200)
    icon = models.CharField(max_length=40)  # Material icon name string
    tier = models.CharField(max_length=8, choices=Tier.choices, default=Tier.BRONZE)
    xp_reward = models.PositiveIntegerField(default=25)

    class Meta:
        ordering = ['tier', 'code']

    def __str__(self):
        return f"{self.name} ({self.tier})"


class UserAchievement(models.Model):
    """Join row: a user has unlocked an achievement. Pin flag controls
    whether the badge appears in the Profile screen's pinned slots."""

    user = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='user_achievements',
    )
    achievement = models.ForeignKey(
        Achievement,
        on_delete=models.CASCADE,
        related_name='unlocked_by',
    )
    unlocked_at = models.DateTimeField(default=timezone.now)
    is_pinned = models.BooleanField(default=False)

    class Meta:
        unique_together = ('user', 'achievement')
        ordering = ['-unlocked_at']

    def __str__(self):
        return f"{self.user.username} ✓ {self.achievement.code}"
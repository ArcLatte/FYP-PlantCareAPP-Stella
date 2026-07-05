from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


class CustomUser(AbstractUser):
    # ─── Streak-save tunables ────────────────────────────────
    STARTER_SAVES = 2       # every account begins with this many saves
    MAX_SAVES = 3           # bank cap — earning past this is discarded
    MAX_BRIDGED_DAYS = 2    # saves can cover at most this many missed days

    # ─── Seed-earning tunables ───────────────────────────────
    # Seeds are the spendable currency (cosmetics); XP stays the status
    # track (levels/tiers). Earned on level-ups, achievement unlocks and
    # weekly-challenge completions — never bought with XP.
    SEEDS_PER_LEVEL_UP = 25
    STARTER_SEEDS = 30

    email = models.EmailField(unique=True)
    # Optional profile picture, uploaded from the Settings screen. Old files
    # are deleted from storage on replace/remove (see the profile view).
    avatar = models.ImageField(upload_to='avatars/', null=True, blank=True)
    current_streak = models.PositiveIntegerField(default=0)
    longest_streak = models.PositiveIntegerField(default=0)
    last_care_date = models.DateField(null=True, blank=True)
    # Banked streak saves ("freezes"): auto-consumed to bridge short gaps in
    # daily care so one missed day doesn't wipe the streak. Earned via weekly
    # challenges and level-ups, capped at MAX_SAVES.
    streak_freezes = models.PositiveIntegerField(default=STARTER_SAVES)
    # Spendable currency for the cosmetic shop. Small starter grant so the
    # shop isn't a dead screen for new users.
    seeds = models.PositiveIntegerField(default=STARTER_SEEDS)

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
            return {
                'xp_gained': 0, 'leveled_up': False, 'new_level': self.level,
                'seeds_gained': 0,
            }
        self.xp += amount
        leveled = False
        seeds_gained = 0
        while self.xp >= self.xp_threshold(self.level + 1):
            self.level += 1
            leveled = True
            # Level-up perks: bank a streak save and pay out seeds.
            self.grant_streak_save()
            seeds_gained += self.SEEDS_PER_LEVEL_UP
        self.seeds += seeds_gained
        self.save(update_fields=['xp', 'level', 'streak_freezes', 'seeds'])
        return {
            'xp_gained': amount, 'leveled_up': leveled, 'new_level': self.level,
            'seeds_gained': seeds_gained,
        }

    def grant_streak_save(self, count: int = 1) -> int:
        """Add streak saves in memory, respecting the MAX_SAVES cap. Returns
        how many were actually banked. Caller is responsible for saving."""
        before = self.streak_freezes
        self.streak_freezes = min(self.streak_freezes + count, self.MAX_SAVES)
        return self.streak_freezes - before

    # ─── Streak ───────────────────────────────────────────────

    def register_care_activity(self) -> dict:
        """Call after any water/fertilize/mist action. Advances the streak at
        most once per calendar day. A short gap (missed days) is bridged by
        auto-consuming banked streak saves — one per missed day — so the
        streak continues instead of resetting. Saves are never partially
        spent: a gap too big for the bank resets the streak and keeps them.

        Returns a small result dict (`saved`, `missed`, `freezes_left`) so
        views can tell the client a save was consumed."""
        today = timezone.localdate()
        result = {'saved': False, 'missed': 0, 'freezes_left': self.streak_freezes}
        if self.last_care_date == today:
            return result  # already counted today

        if self.last_care_date is None:
            self.current_streak = 1  # first ever care action
        else:
            missed = (today - self.last_care_date).days - 1  # full uncared days
            if missed == 0:
                self.current_streak += 1  # cared yesterday — normal advance
            elif missed <= self.streak_freezes and missed <= self.MAX_BRIDGED_DAYS:
                # Bridge the gap: spend one save per missed day. Bridged days
                # preserve the streak but don't inflate it.
                self.streak_freezes -= missed
                self.current_streak += 1
                result.update(saved=True, missed=missed)
            else:
                self.current_streak = 1  # gap too big — reset, keep the saves

        self.last_care_date = today
        self.longest_streak = max(self.longest_streak, self.current_streak)
        self.save(update_fields=[
            'current_streak', 'longest_streak', 'last_care_date',
            'streak_freezes',
        ])
        result['freezes_left'] = self.streak_freezes
        return result

    @property
    def effective_streak(self):
        """Displayed streak. Read-only — never mutates storage. A streak
        counts as alive while banked saves could still bridge the current
        gap (so the companion plant doesn't falsely collapse to Seed on a
        day the user is about to save); it reads 0 only once truly dead."""
        if self.last_care_date is None:
            return 0
        today = timezone.localdate()
        gap = (today - self.last_care_date).days
        if gap <= 1:
            return self.current_streak  # cared today or yesterday
        missed = gap - 1
        if missed <= self.streak_freezes and missed <= self.MAX_BRIDGED_DAYS:
            return self.current_streak  # shielded: a save will cover this
        return 0

    @property
    def freeze_active(self) -> bool:
        """True while the streak is being held alive by banked saves (a gap
        exists but is coverable). Drives the shield indicator in the UI."""
        if self.last_care_date is None:
            return False
        gap = (timezone.localdate() - self.last_care_date).days
        if gap <= 1:
            return False
        missed = gap - 1
        return missed <= self.streak_freezes and missed <= self.MAX_BRIDGED_DAYS


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
        NOTE = 'note', 'Note'

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
    # Optional short title/subject for `note` entries, shown as the heading on
    # the journal preview card. Empty for the water/fertilize/mist actions.
    title = models.CharField(max_length=120, blank=True)
    # Free-text body for `note` entries (a user journal note). Empty for the
    # water/fertilize/mist actions, which carry no text.
    note = models.TextField(blank=True)
    # Optional progress photo attached to a `note` entry, so the journal can
    # build a visual timeline of the plant over time. Empty for everything else.
    photo = models.ImageField(upload_to='notes/', null=True, blank=True)
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


class WeeklyChallengeProgress(models.Model):
    """Completion record for a user's weekly challenge. One row per user per
    ISO week, created the moment the challenge's target is reached (rewards
    are granted at the same time — see `weekly.check_weekly_challenge`).
    The challenge definitions themselves live in code (`weekly.CHALLENGES`),
    mirroring how achievement predicates live in `achievements.py`."""

    user = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='weekly_completions',
    )
    week_start = models.DateField()  # Monday of the ISO week
    challenge_code = models.CharField(max_length=40)
    completed_at = models.DateTimeField(default=timezone.now)

    class Meta:
        unique_together = ('user', 'week_start')
        ordering = ['-week_start']

    def __str__(self):
        return f"{self.user.username} ✓ {self.challenge_code} ({self.week_start})"


class Cosmetic(models.Model):
    """A purchasable cosmetic. Seeded via `seed_cosmetics` (catalog lives
    there), purchased with seeds, purely visual — never affects gameplay.

    Payload shape per kind (all code-drawn client-side, no art assets):
    - creature_skin: `{"tint": "#hex", "amount": 0.0-1.0}` — tint applied to
      the streak companion via the same ColorFilter channel the time-of-day
      lighting uses.
    - pot_style: `{"body": "#hex", "rim": "#hex", "accent": "#hex",
      "pattern": "none|stripes|dots|wave"}` — colors for the pot the
      companion sits in (drawn by the client's pot painter).
    - namecard: `{"theme_id": "nc_..."}` — unlocks a profile-card scene in
      the card picker. Buying is the only server-side action; which card is
      shown stays a client-side choice alongside tier/achievement themes."""

    class Kind(models.TextChoices):
        CREATURE_SKIN = 'creature_skin', 'Creature skin'
        POT_STYLE = 'pot_style', 'Pot style'
        NAMECARD = 'namecard', 'Namecard'

    class Rarity(models.TextChoices):
        COMMON = 'common', 'Common'
        RARE = 'rare', 'Rare'
        EPIC = 'epic', 'Epic'

    code = models.CharField(max_length=40, unique=True)
    name = models.CharField(max_length=80)
    description = models.CharField(max_length=200, blank=True)
    kind = models.CharField(
        max_length=20, choices=Kind.choices, default=Kind.CREATURE_SKIN,
    )
    rarity = models.CharField(
        max_length=8, choices=Rarity.choices, default=Rarity.COMMON,
    )
    cost_seeds = models.PositiveIntegerField()
    payload = models.JSONField(default=dict, blank=True)
    sort = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['sort', 'cost_seeds', 'code']

    def __str__(self):
        return f"{self.name} ({self.cost_seeds} seeds)"


class UserCosmetic(models.Model):
    """Join row: a user owns a cosmetic. At most one cosmetic per kind is
    equipped at a time (enforced in the equip view)."""

    user = models.ForeignKey(
        CustomUser,
        on_delete=models.CASCADE,
        related_name='cosmetics',
    )
    cosmetic = models.ForeignKey(
        Cosmetic,
        on_delete=models.CASCADE,
        related_name='owned_by',
    )
    equipped = models.BooleanField(default=False)
    acquired_at = models.DateTimeField(default=timezone.now)

    class Meta:
        unique_together = ('user', 'cosmetic')
        ordering = ['-acquired_at']

    def __str__(self):
        return f"{self.user.username} owns {self.cosmetic.code}"


# ─── Social layer ────────────────────────────────────────────────
# Defined in social_models.py (FKs reference the models above by name) and
# imported here so Django registers them under the `core` app. Keep at the
# bottom: the social models' string FK refs resolve against the models defined
# above.
from .social_models import (  # noqa: E402,F401
    Community,
    CommunityMembership,
    Post,
    Follow,
    PostLike,
    Comment,
)
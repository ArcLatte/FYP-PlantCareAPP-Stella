from django.contrib.auth.models import AbstractUser
from django.db import models


class CustomUser(AbstractUser):
    email = models.EmailField(unique=True)

    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['email']

    def __str__(self):
        return self.email


class PlantSpecies(models.Model):
    name = models.CharField(max_length=100, unique=True)  # e.g. "Tomato"
    growing_tips = models.TextField()

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
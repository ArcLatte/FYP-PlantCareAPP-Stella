from django.conf import settings
from django.templatetags.static import static
from django.utils import timezone
from rest_framework import serializers
from .models import (
    Plant, PlantSpecies, Location, Disease,
)


def image_ref_to_url(ref):
    """Resolve a stored library-image reference to a servable URL. Absolute
    http(s) URLs pass through (legacy hotlinks); anything else is a static
    path ('library/diseases/x.jpg') resolved through the staticfiles storage
    into a site-relative /static/ URL (hashed name in production). The app
    prepends its API host to relative URLs."""
    if not ref:
        return ref
    if ref.startswith('http://') or ref.startswith('https://'):
        return ref
    try:
        return static(ref)
    except ValueError:
        # Manifest storage raises for uncollected files — emit the plain URL
        # (a broken image beats a 500 on the whole payload).
        return settings.STATIC_URL + ref


class PlantSpeciesSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = PlantSpecies
        fields = [
            'id', 'name', 'scientific_name', 'description', 'growing_tips',
            'sunlight', 'recommended_location',
            'temperature_min_c', 'temperature_max_c',
            'default_watering_freq_days',
            'default_fertilizer_freq_days',
            'default_misting_freq_days',
            'days_to_harvest',
            'image_url',
        ]

    def get_image_url(self, obj):
        return image_ref_to_url(obj.image_path) or ''


class DiseaseSerializer(serializers.ModelSerializer):
    species_name = serializers.CharField(source='species.name', read_only=True)
    image_url = serializers.SerializerMethodField()
    image_urls = serializers.SerializerMethodField()

    class Meta:
        model = Disease
        fields = [
            'id', 'label', 'name', 'species_name',
            'description', 'symptoms', 'cause',
            'treatment', 'care_tips', 'prevention',
            'severity', 'source_name', 'source_url', 'image_url', 'image_urls',
        ]

    def get_image_url(self, obj):
        return image_ref_to_url(obj.image_url) or ''

    def get_image_urls(self, obj):
        return [image_ref_to_url(u) for u in (obj.image_urls or []) if u]


class LocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Location
        fields = ['id', 'name']


class PlantSerializer(serializers.ModelSerializer):
    species_name = serializers.CharField(source='species.name', read_only=True)
    species_detail = PlantSpeciesSerializer(source='species', read_only=True)
    needs_water = serializers.SerializerMethodField()
    needs_fertilizer = serializers.SerializerMethodField()
    needs_misting = serializers.SerializerMethodField()
    days_until_water = serializers.SerializerMethodField()
    days_until_fertilizer = serializers.SerializerMethodField()
    days_until_misting = serializers.SerializerMethodField()
    latest_health = serializers.SerializerMethodField()
    latest_disease = serializers.SerializerMethodField()

    class Meta:
        model = Plant
        fields = [
            'id', 'name', 'species', 'species_name', 'species_detail',
            'date_planted', 'photo', 'notes', 'location',
            'last_watered', 'last_fertilized', 'last_misted',
            'watering_freq_days', 'fertilizer_freq_days', 'misting_freq_days',
            'needs_water', 'needs_fertilizer', 'needs_misting',
            'days_until_water', 'days_until_fertilizer', 'days_until_misting',
            'latest_health', 'latest_disease', 'created_at',
        ]
        read_only_fields = [
            'created_at', 'species_name', 'species_detail',
            'needs_water', 'needs_fertilizer', 'needs_misting',
            'days_until_water', 'days_until_fertilizer', 'days_until_misting',
            'latest_health', 'latest_disease',
        ]

    # ─── Create ──────────────────────────────────────────────
    def create(self, validated_data):
        # If the caller didn't pin a per-plant watering cadence, inherit
        # the species default. Existing Flutter call sites that send an
        # explicit watering_freq_days keep their behavior.
        species = validated_data.get('species')
        if species is not None:
            if 'watering_freq_days' not in validated_data:
                validated_data['watering_freq_days'] = (
                    species.default_watering_freq_days
                )
            if 'fertilizer_freq_days' not in validated_data:
                validated_data['fertilizer_freq_days'] = (
                    species.default_fertilizer_freq_days
                )
            if 'misting_freq_days' not in validated_data:
                validated_data['misting_freq_days'] = (
                    species.default_misting_freq_days
                )
        return super().create(validated_data)

    # ─── Watering countdown ──────────────────────────────────
    def get_needs_water(self, obj):
        if obj.last_watered is None:
            return True
        delta = timezone.now() - obj.last_watered
        return delta.days >= obj.watering_freq_days

    def get_days_until_water(self, obj):
        if obj.last_watered is None:
            return 0
        elapsed = (timezone.now() - obj.last_watered).days
        return obj.watering_freq_days - elapsed

    # ─── Fertilizer countdown ────────────────────────────────
    def _fertilizer_freq(self, obj):
        return obj.fertilizer_freq_days

    def get_needs_fertilizer(self, obj):
        freq = self._fertilizer_freq(obj)
        if freq is None:
            return None  # not applicable to this species
        if obj.last_fertilized is None:
            return True
        return (timezone.now() - obj.last_fertilized).days >= freq

    def get_days_until_fertilizer(self, obj):
        freq = self._fertilizer_freq(obj)
        if freq is None:
            return None
        if obj.last_fertilized is None:
            return 0
        elapsed = (timezone.now() - obj.last_fertilized).days
        return freq - elapsed

    # ─── Misting countdown ───────────────────────────────────
    def _misting_freq(self, obj):
        return obj.misting_freq_days

    def get_needs_misting(self, obj):
        freq = self._misting_freq(obj)
        if freq is None:
            return None
        if obj.last_misted is None:
            return True
        return (timezone.now() - obj.last_misted).days >= freq

    def get_days_until_misting(self, obj):
        freq = self._misting_freq(obj)
        if freq is None:
            return None
        if obj.last_misted is None:
            return 0
        elapsed = (timezone.now() - obj.last_misted).days
        return freq - elapsed

    # ─── Health ──────────────────────────────────────────────
    def get_latest_health(self, obj):
        """Return 'healthy' / 'diseased' / None based on the most recent scan."""
        latest = obj.scans.order_by('-created_at').first()
        if latest is None:
            return None
        # Prefer the user-confirmed disease; fall back to top model prediction
        label = None
        if latest.disease_id:
            label = latest.disease.label
        elif latest.top3_predictions:
            top = latest.top3_predictions[0]
            if isinstance(top, dict):
                label = top.get('label')
        if not label:
            return None
        return 'healthy' if 'healthy' in label.lower() else 'diseased'

    def get_latest_disease(self, obj):
        """Lightweight summary of the most recent *confirmed* diagnosis, so the
        plant profile can show care actions + a 'read more' link without an
        extra request. Returns None until a scan has been confirmed."""
        latest = obj.scans.order_by('-created_at').first()
        if latest is None or not latest.disease_id:
            return None
        d = latest.disease
        return {
            'scan_id': latest.id,
            'label': d.label,
            'name': d.name,
            'severity': d.severity,
            'treatment': d.treatment,
            'care_tips': d.care_tips,
        }

from django.utils import timezone
from rest_framework import serializers
from .models import Plant, PlantSpecies, Location, Disease


class PlantSpeciesSerializer(serializers.ModelSerializer):
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
        ]


class DiseaseSerializer(serializers.ModelSerializer):
    species_name = serializers.CharField(source='species.name', read_only=True)

    class Meta:
        model = Disease
        fields = [
            'id', 'label', 'name', 'species_name',
            'description', 'symptoms', 'cause',
            'treatment', 'care_tips', 'prevention',
            'severity', 'source_name', 'source_url', 'image_url', 'image_urls',
        ]


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
            'watering_freq_days',
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
        if 'watering_freq_days' not in validated_data:
            species = validated_data.get('species')
            if species is not None:
                validated_data['watering_freq_days'] = (
                    species.default_watering_freq_days
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
        return obj.species.default_fertilizer_freq_days

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
        return obj.species.default_misting_freq_days

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

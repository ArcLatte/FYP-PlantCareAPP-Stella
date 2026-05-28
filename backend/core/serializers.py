from django.utils import timezone
from rest_framework import serializers
from .models import Plant, PlantSpecies, Location


class PlantSpeciesSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlantSpecies
        fields = ['id', 'name', 'growing_tips']


class LocationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Location
        fields = ['id', 'name']


class PlantSerializer(serializers.ModelSerializer):
    species_name = serializers.CharField(source='species.name', read_only=True)
    needs_water = serializers.SerializerMethodField()
    latest_health = serializers.SerializerMethodField()

    class Meta:
        model = Plant
        fields = [
            'id', 'name', 'species', 'species_name', 'date_planted',
            'photo', 'notes', 'location', 'last_watered',
            'watering_freq_days', 'needs_water', 'latest_health',
            'created_at',
        ]
        read_only_fields = ['created_at', 'needs_water', 'latest_health']

    def get_needs_water(self, obj):
        if obj.last_watered is None:
            return True
        delta = timezone.now() - obj.last_watered
        return delta.days >= obj.watering_freq_days

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

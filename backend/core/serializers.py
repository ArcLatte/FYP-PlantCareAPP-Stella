from rest_framework import serializers
from .models import Plant, PlantSpecies


class PlantSpeciesSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlantSpecies
        fields = ['id', 'name', 'growing_tips']


class PlantSerializer(serializers.ModelSerializer):
    species_name = serializers.CharField(source='species.name', read_only=True)

    class Meta:
        model = Plant
        fields = ['id', 'name', 'species', 'species_name', 'date_planted', 'photo', 'notes', 'created_at']
        read_only_fields = ['created_at']
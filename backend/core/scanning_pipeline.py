import os
from dataclasses import dataclass
from enum import Enum

from django.conf import settings

from .disease_classifier import DiseaseClassifier
from .image_quality import ImageQualityAssessor
from .leaf_gate import LeafGateClassifier


class ScanStatus(str, Enum):
    ACCEPTED = 'accepted'
    QUALITY_REJECTED = 'quality_rejected'
    NO_LEAF = 'no_leaf'
    UNSUPPORTED_SPECIES = 'unsupported_species'


@dataclass(frozen=True)
class ScanAnalysis:
    status: ScanStatus
    predictions: list | None = None
    quality: dict | None = None
    leaf_gate: dict | None = None

    @property
    def accepted(self):
        return self.status is ScanStatus.ACCEPTED


class ScanningPipeline:
    """Coordinates quality, leaf, and species disease classifiers.

    Dependencies are injected so each stage can be tested or replaced without
    changing the API view or the other classifiers.
    """

    def __init__(self, quality_assessor, leaf_classifier, disease_classifier):
        self.quality_assessor = quality_assessor
        self.leaf_classifier = leaf_classifier
        self.disease_classifier = disease_classifier

    def analyze(self, image, species_name):
        quality = self.quality_assessor.assess(image)
        if not quality['passed']:
            return ScanAnalysis(
                status=ScanStatus.QUALITY_REJECTED,
                quality=quality,
            )

        leaf_gate = self.leaf_classifier.classify(image)
        if not leaf_gate['passed']:
            return ScanAnalysis(
                status=ScanStatus.NO_LEAF,
                quality=quality,
                leaf_gate=leaf_gate,
            )

        predictions = self.disease_classifier.classify(species_name, image)
        if predictions is None:
            return ScanAnalysis(
                status=ScanStatus.UNSUPPORTED_SPECIES,
                quality=quality,
                leaf_gate=leaf_gate,
            )

        return ScanAnalysis(
            status=ScanStatus.ACCEPTED,
            predictions=predictions,
            quality=quality,
            leaf_gate=leaf_gate,
        )


def build_default_pipeline():
    models_dir = os.getenv('MODELS_DIR', os.path.join(settings.BASE_DIR, 'ml'))
    return ScanningPipeline(
        quality_assessor=ImageQualityAssessor(),
        leaf_classifier=LeafGateClassifier(),
        disease_classifier=DiseaseClassifier(models_dir=models_dir),
    )


default_scanning_pipeline = build_default_pipeline()

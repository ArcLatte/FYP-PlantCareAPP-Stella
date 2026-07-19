import gc
from functools import lru_cache
from pathlib import Path

import torch
from django.conf import settings
from torchvision import models, transforms

from .model_runtime import inference_lock


class LeafGateClassifier:
    """Cached binary ConvNeXt classifier for leaf/not-leaf decisions."""

    def __init__(self, checkpoint_path=None, threshold=None):
        self._checkpoint_path_override = checkpoint_path
        self._threshold_override = threshold
        self.transform = transforms.Compose([
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize(
                [0.485, 0.456, 0.406],
                [0.229, 0.224, 0.225],
            ),
        ])

    @property
    def threshold(self):
        if self._threshold_override is not None:
            return float(self._threshold_override)
        return float(getattr(settings, 'SCAN_LEAF_GATE_THRESHOLD', 0.99))

    @property
    def checkpoint_path(self) -> Path:
        if self._checkpoint_path_override is not None:
            return Path(self._checkpoint_path_override)
        configured = getattr(settings, 'SCAN_LEAF_GATE_MODEL_PATH', '')
        if configured:
            return Path(configured)
        return Path(settings.BASE_DIR) / 'ml' / 'convnext_tiny_binary_leaf_gate.pth'

    @staticmethod
    @lru_cache(maxsize=1)
    def _load_model(checkpoint_path: str):
        model = models.convnext_tiny(weights=None)
        model.classifier[2] = torch.nn.Linear(
            model.classifier[2].in_features,
            2,
        )
        checkpoint = torch.load(
            checkpoint_path,
            map_location='cpu',
            weights_only=True,
        )
        model.load_state_dict(checkpoint.get('model', checkpoint))
        model.eval()
        return model

    @classmethod
    def release_cached_model(cls):
        """Drop the leaf model before the larger disease stage is loaded."""
        cls._load_model.cache_clear()
        gc.collect()

    def classify(self, image):
        """Classify an image using training labels 0=not-leaf and 1=leaf."""
        threshold = self.threshold
        tensor = self.transform(image).unsqueeze(0)
        with inference_lock:
            model = self._load_model(str(self.checkpoint_path.resolve()))
            with torch.inference_mode():
                confidence = torch.softmax(model(tensor)[0], dim=0)[1].item()

        return {
            'passed': confidence >= threshold,
            'leaf_confidence': round(confidence, 4),
            'threshold': threshold,
        }

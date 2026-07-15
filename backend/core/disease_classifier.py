import os
from dataclasses import dataclass

import torch
from torchvision import models, transforms

from .model_runtime import inference_lock


@dataclass(frozen=True)
class DiseaseModelConfig:
    filename: str
    classes: tuple[str, ...]


DEFAULT_MODEL_REGISTRY = {
    'Tomato': DiseaseModelConfig(
        filename='tomato_convnext_tiny_v1.pth',
        classes=(
            'Tomato_Bacterial_spot',
            'Tomato_Early_blight',
            'Tomato_Late_blight',
            'Tomato_Leaf_Mold',
            'Tomato_Septoria_leaf_spot',
            'Tomato_Spider_mites_Two_spotted_spider_mite',
            'Tomato__Target_Spot',
            'Tomato__Tomato_YellowLeaf__Curl_Virus',
            'Tomato__Tomato_mosaic_virus',
            'Tomato_healthy',
        ),
    ),
    'Potato': DiseaseModelConfig(
        filename='potato_convnext_plantdoc.pth',
        classes=(
            'Potato___Early_blight',
            'Potato___Late_blight',
            'Potato___healthy',
        ),
    ),
    'Bell Pepper': DiseaseModelConfig(
        filename='pepper_convnext_plantdoc.pth',
        classes=(
            'Pepper__bell___Bacterial_spot',
            'Pepper__bell___healthy',
        ),
    ),
}


class DiseaseClassifier:
    """Selects, loads, and runs a species-specific ConvNeXt classifier."""

    def __init__(self, models_dir, registry=None):
        self.models_dir = os.fspath(models_dir)
        self.registry = DEFAULT_MODEL_REGISTRY if registry is None else registry
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(
                [0.485, 0.456, 0.406],
                [0.229, 0.224, 0.225],
            ),
        ])

    def supports(self, species_name):
        return species_name in self.registry

    @staticmethod
    def _create_model(class_count):
        model = models.convnext_tiny(weights=None)
        model.classifier[2] = torch.nn.Linear(
            model.classifier[2].in_features,
            class_count,
        )
        return model

    def classify(self, species_name, image):
        config = self.registry.get(species_name)
        if config is None:
            return None

        tensor = self.transform(image).unsqueeze(0)
        with inference_lock:
            model = self._create_model(len(config.classes))
            model.load_state_dict(torch.load(
                os.path.join(self.models_dir, config.filename),
                map_location='cpu',
                weights_only=True,
            ))
            model.eval()
            try:
                with torch.inference_mode():
                    probabilities = torch.softmax(model(tensor)[0], dim=0)
            finally:
                del model

        count = min(3, len(config.classes))
        top = torch.topk(probabilities, count)
        return [
            {
                'label': config.classes[top.indices[index].item()],
                'confidence': round(top.values[index].item(), 4),
            }
            for index in range(count)
        ]

"""
Transformaciones de inferencia — deben coincidir con eval_transform del entrenamiento.

- Resize 224×224
- ToTensor + normalización ImageNet
"""

from __future__ import annotations

from torchvision import transforms

IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)
IMG_SIZE = 224


def eval_transform():
    """Pipeline solo para predicción (sin augmentation)."""
    return transforms.Compose(
        [
            transforms.Resize((IMG_SIZE, IMG_SIZE)),
            transforms.ToTensor(),
            transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
        ]
    )

"""ResNet-50 con timm — 38 clases PlantVillage."""

from __future__ import annotations

import torch
import timm


NUM_CLASSES = 38
MODEL_NAME = "resnet50"


def build_model(num_classes: int = NUM_CLASSES, pretrained: bool = False) -> torch.nn.Module:
    """Crea la arquitectura (para cargar pesos entrenados usar pretrained=False)."""
    return timm.create_model(MODEL_NAME, pretrained=pretrained, num_classes=num_classes)


def load_checkpoint(
    checkpoint_path: str,
    num_classes: int = NUM_CLASSES,
    device: str | torch.device = "cpu",
) -> torch.nn.Module:
    """
    Carga resnet50.pt guardado en Lightning.

    Soporta:
      - torch.save(model.state_dict(), ...)
      - torch.save({"state_dict": ...}, ...)
      - torch.save(model, ...)  (modelo completo)
    """
    ckpt = torch.load(checkpoint_path, map_location=device, weights_only=False)

    if isinstance(ckpt, torch.nn.Module):
        model = ckpt
        model.eval()
        return model.to(device)

    model = build_model(num_classes=num_classes, pretrained=False)

    state = ckpt
    if isinstance(ckpt, dict):
        if "state_dict" in ckpt:
            state = ckpt["state_dict"]
        elif "model" in ckpt and isinstance(ckpt["model"], dict):
            state = ckpt["model"]
        elif "model_state_dict" in ckpt:
            state = ckpt["model_state_dict"]

    # Quitar prefijo 'module.' si entrenaron con DataParallel
    if isinstance(state, dict) and state and next(iter(state)).startswith("module."):
        state = {k.replace("module.", "", 1): v for k, v in state.items()}

    model.load_state_dict(state, strict=True)
    model.eval()
    return model.to(device)

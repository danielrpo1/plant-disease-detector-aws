"""Inferencia sobre una imagen — misma lógica que usará FastAPI en EC2."""

from __future__ import annotations

from pathlib import Path

import torch
import torch.nn.functional as F
from PIL import Image

from src.class_mapping import load_classes_json
from src.model_resnet50 import load_checkpoint
from src.transforms import eval_transform


@torch.no_grad()
def predict_image(
    model: torch.nn.Module,
    image_path: str | Path,
    class_names: list[str],
    display_names: dict[str, str],
    device: str | torch.device = "cpu",
    top_k: int = 3,
) -> dict:
    img = Image.open(image_path).convert("RGB")
    tensor = eval_transform()(img).unsqueeze(0).to(device)

    logits = model(tensor)
    probs = F.softmax(logits, dim=1)[0]
    values, indices = torch.topk(probs, k=min(top_k, len(class_names)))

    predictions = []
    for conf, idx in zip(values.tolist(), indices.tolist()):
        cls = class_names[idx]
        predictions.append(
            {
                "class": cls,
                "confidence": round(conf, 4),
                "display_name": display_names.get(cls, cls),
            }
        )

    top = predictions[0]
    return {
        "predictions": predictions,
        "top_prediction": top["class"],
        "confidence": top["confidence"],
        "display_name": top["display_name"],
    }


def load_inference_bundle(
    checkpoint_path: str,
    classes_path: str,
    display_path: str,
    device: str | None = None,
) -> tuple[torch.nn.Module, list[str], dict[str, str], torch.device]:
    import json

    dev = torch.device(device or ("cuda" if torch.cuda.is_available() else "cpu"))
    class_names = load_classes_json(classes_path)
    display_names = json.loads(Path(display_path).read_text(encoding="utf-8"))
    model = load_checkpoint(checkpoint_path, num_classes=len(class_names), device=dev)
    return model, class_names, display_names, dev

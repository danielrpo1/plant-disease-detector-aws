#!/usr/bin/env python3
"""Genera artifacts/ mínimos para desplegar la API (reemplazar con checkpoint entrenado)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT.parent / "plant-disease-detector" / "webapp" / "models"
OUT = ROOT / "artifacts"


def main() -> None:
    meta_path = MAIN / "model.meta.json"
    labels_path = MAIN / "labels_display.json"
    if not meta_path.is_file():
        raise SystemExit(f"No encontré {meta_path}")

    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    labels = json.loads(labels_path.read_text(encoding="utf-8"))
    class_names = sorted(meta["class_to_idx"], key=lambda k: meta["class_to_idx"][k])

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "clases.json").write_text(
        json.dumps(class_names, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (OUT / "nombres_display.json").write_text(
        json.dumps(labels, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    pt = OUT / "resnet50.pt"
    if pt.is_file():
        print(f"✓ Ya existe {pt} — no se sobrescribe.")
    else:
        try:
            import torch
            import timm
        except ImportError:
            print("Instala torch y timm para generar resnet50.pt:", file=sys.stderr)
            print("  pip install torch timm", file=sys.stderr)
            raise SystemExit(1)

        print("Generando resnet50.pt (ImageNet + cabeza 38 clases — sustituir tras entrenar)…")
        model = timm.create_model("resnet50", pretrained=True, num_classes=len(class_names))
        torch.save(model.state_dict(), pt)

    print("✓ Artifacts listos en", OUT)


if __name__ == "__main__":
    main()

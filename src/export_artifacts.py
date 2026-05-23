"""
Etapa 1 — Exporta los 3 archivos para AWS.

  python -m src.export_artifacts \\
    --checkpoint checkpoints/resnet50.pt \\
    --train-dir data/plantas_train \\
    --out artifacts
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from src.class_mapping import classes_from_train_dir, save_class_artifacts


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Exportar ResNet-50 para AWS")
    p.add_argument("--checkpoint", required=True, help="Ruta a resnet50.pt")
    p.add_argument(
        "--train-dir",
        required=True,
        help="Carpeta train ImageFolder (define orden de clases)",
    )
    p.add_argument("--out", default="artifacts", help="Carpeta de salida")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    ckpt = Path(args.checkpoint)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    if not ckpt.is_file():
        raise FileNotFoundError(f"Checkpoint no encontrado: {ckpt}")

    class_names = classes_from_train_dir(args.train_dir)
    clases_json, nombres_json = save_class_artifacts(class_names, out)

    dest_pt = out / "resnet50.pt"
    shutil.copy2(ckpt, dest_pt)

    meta = {
        "model": "resnet50",
        "num_classes": len(class_names),
        "img_size": 224,
        "checkpoint_source": str(ckpt.resolve()),
    }
    (out / "export_meta.json").write_text(
        json.dumps(meta, indent=2), encoding="utf-8"
    )

    print("✓ Exportación lista:")
    print(f"  {dest_pt}")
    print(f"  {clases_json}")
    print(f"  {nombres_json}")
    print(f"  Clases: {len(class_names)}")


if __name__ == "__main__":
    main()

"""Orden de clases desde carpetas ImageFolder (train)."""

from __future__ import annotations

import json
from pathlib import Path


def classes_from_train_dir(train_dir: str | Path) -> list[str]:
    """
    Mismo orden que torchvision.datasets.ImageFolder:
    carpetas ordenadas alfabéticamente.
    """
    root = Path(train_dir)
    if not root.is_dir():
        raise FileNotFoundError(f"No existe carpeta de train: {root}")
    names = [p.name for p in root.iterdir() if p.is_dir()]
    if len(names) != 38:
        print(f"⚠ Se encontraron {len(names)} clases (se esperaban 38).")
    return sorted(names)


def save_class_artifacts(
    class_names: list[str],
    out_dir: str | Path,
) -> tuple[Path, Path]:
    from src.labels import display_name

    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    clases_path = out / "clases.json"
    nombres_path = out / "nombres_display.json"

    clases_path.write_text(
        json.dumps(class_names, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    display = {name: display_name(name) for name in class_names}
    nombres_path.write_text(
        json.dumps(display, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return clases_path, nombres_path


def load_classes_json(path: str | Path) -> list[str]:
    return json.loads(Path(path).read_text(encoding="utf-8"))

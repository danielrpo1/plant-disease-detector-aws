"""Descarga PlantVillage (38 clases) desde Hugging Face."""

from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path

from tqdm import tqdm


def export_split(split_ds, out_root: Path, max_per_class: int | None, split_name: str) -> int:
    counts: dict[str, int] = defaultdict(int)
    n = 0
    for row in tqdm(split_ds, desc=f"Export {split_name}"):
        label = row["class_label"]
        if max_per_class and counts[label] >= max_per_class:
            continue
        dest_dir = out_root / split_name / label
        dest_dir.mkdir(parents=True, exist_ok=True)
        img = row["image"]
        if img.mode != "RGB":
            img = img.convert("RGB")
        path = dest_dir / f"{split_name}_{n:06d}.jpg"
        img.save(path, quality=90)
        counts[label] += 1
        n += 1
    return n


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="data/plantvillage")
    parser.add_argument("--max-per-class", type=int, default=None)
    parser.add_argument("--eda-only", action="store_true")
    args = parser.parse_args()

    from datasets import load_dataset

    print("Cargando geraldmc/plantvillage-full...")
    ds = load_dataset("geraldmc/plantvillage-full", revision="v0.1.0")
    print(ds)

    if args.eda_only:
        return

    out = Path(args.out)
    if "test" in ds or "validation" in ds:
        valid_key = next(k for k in ("test", "validation", "valid") if k in ds)
        train_ds, valid_ds = ds["train"], ds[valid_key]
    else:
        full = ds["train"]
        train_ds = full.filter(lambda x: x["split"] == "train")
        valid_ds = full.filter(lambda x: x["split"] == "test")

    n_train = export_split(train_ds, out, args.max_per_class, "train")
    n_valid = export_split(valid_ds, out, args.max_per_class, "valid")
    print(f"\nExportado: train={n_train}, valid={n_valid} → {out.resolve()}")


if __name__ == "__main__":
    main()

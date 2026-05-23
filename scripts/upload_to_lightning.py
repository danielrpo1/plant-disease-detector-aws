#!/usr/bin/env python3
"""Sube plant-disease-detector-aws al Lightning Studio."""
from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)

# Reutilizar .env del repo hermano si existe
for env_file in (ROOT / ".env", ROOT.parent / "plant-disease-detector" / ".env"):
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())

USER = os.environ.get("LIGHTNING_USER", "ddrestrepo")
TEAMSPACE = os.environ.get("LIGHTNING_TEAMSPACE", "neural-network-development-project")
STUDIO_NAME = os.environ.get("LIGHTNING_STUDIO", "cognitive-bronze-moof")
REMOTE_DIR = "plant-disease-detector-aws"
SKIP = {
    ".env",
    ".git",
    "__pycache__",
    ".DS_Store",
    "checkpoints",
    "artifacts",
    "data",
    "wandb",
    ".venv",
}


def should_upload(rel: Path) -> bool:
    if any(p in SKIP for p in rel.parts):
        return False
    if rel.suffix in {".pyc", ".pt"}:
        return False
    return True


def main() -> None:
    from lightning_sdk import Studio

    studio = Studio(name=STUDIO_NAME, teamspace=TEAMSPACE, user=USER, create_ok=False)
    files = [p for p in ROOT.rglob("*") if p.is_file() and should_upload(p.relative_to(ROOT))]
    print(f"Subiendo {len(files)} archivos → {REMOTE_DIR}/")

    for local in sorted(files):
        rel = local.relative_to(ROOT)
        remote = f"{REMOTE_DIR}/{rel.as_posix()}"
        try:
            studio.upload_file(str(local), remote_path=remote, progress_bar=False)
            print(f"  OK {rel}")
        except Exception as e:
            print(f"  FAIL {rel}: {e}")

    out = studio.run(f"ls -la {REMOTE_DIR} && ls {REMOTE_DIR}/src")
    print("\n--- Studio ---\n", out)


if __name__ == "__main__":
    main()

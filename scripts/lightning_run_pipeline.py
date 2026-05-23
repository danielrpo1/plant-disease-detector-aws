#!/usr/bin/env python3
"""Sube el repo, lanza pipeline ResNet+export en Lightning, opcionalmente descarga artifacts."""
from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

for env_file in (ROOT / ".env", ROOT.parent / "plant-disease-detector" / ".env"):
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())

USER = os.environ.get("LIGHTNING_USER", "ddrestrepo")
TEAMSPACE = os.environ.get("LIGHTNING_TEAMSPACE", "neural-network-development-project")
STUDIO_NAME = os.environ.get("LIGHTNING_STUDIO", "cognitive-bronze-moof")
REMOTE = "plant-disease-detector-aws"


def main() -> None:
    print("1) Subiendo código...")
    subprocess.run([sys.executable, str(ROOT / "scripts/upload_to_lightning.py")], check=True)

    from lightning_sdk import Studio

    studio = Studio(name=STUDIO_NAME, teamspace=TEAMSPACE, user=USER, create_ok=False)

    # Encender GPU si hace falta
    try:
        print("Estado studio:", studio.status)
    except Exception:
        pass

    sh_local = ROOT / "scripts/run_lightning_pipeline.sh"
    studio.upload_file(
        str(sh_local),
        remote_path=f"{REMOTE}/scripts/run_lightning_pipeline.sh",
        progress_bar=False,
    )

    cmd = f"""
cd {REMOTE}
chmod +x scripts/run_lightning_pipeline.sh
rm -f pipeline.log pipeline_status.txt
nohup bash scripts/run_lightning_pipeline.sh > /dev/null 2>&1 &
sleep 3
head -30 pipeline.log 2>/dev/null || echo 'Log iniciando...'
cat pipeline_status.txt 2>/dev/null || true
"""
    print("\n2) Pipeline en background (GPU)...")
    print(studio.run(cmd))

    print("\n3) Polling cada 60s (máx 3h)...")
    for i in range(180):
        time.sleep(60)
        status = studio.run(f"cat {REMOTE}/pipeline_status.txt 2>/dev/null || echo RUNNING").strip()
        tail = studio.run(f"tail -5 {REMOTE}/pipeline.log 2>/dev/null")
        print(f"[{i+1} min] status={status}")
        print(tail)
        if status == "DONE":
            print(studio.run(f"ls -lh {REMOTE}/artifacts/"))
            print("\n✓ Pipeline terminado en Lightning.")
            return
        if "FAIL" in status or "ERROR" in status:
            print("Pipeline falló. Ver pipeline.log en Studio.")
            sys.exit(1)

    print("Timeout. Revisa pipeline.log en Lightning Studio.")


if __name__ == "__main__":
    main()

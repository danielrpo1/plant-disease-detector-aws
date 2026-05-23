#!/usr/bin/env bash
# Pipeline completo en Lightning Studio (GPU). Log: pipeline.log
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOG="$ROOT/pipeline.log"
STATUS="$ROOT/pipeline_status.txt"
echo "RUNNING" > "$STATUS"
exec > >(tee -a "$LOG") 2>&1

echo "=== $(date) — Plant Disease AWS pipeline ==="

pip install -q -r requirements.txt

# --- Rutas de datos (symlinks del compañero o HF) ---
TRAIN=""
VALID=""

for base in \
  "/teamspace/studios/this_studio/proyecto-plantas/data" \
  "/teamspace/studios/this_studio/plant-disease-detector-aws/data" \
  "$ROOT/data"; do
  if [[ -d "$base/plantas_train" ]]; then
    TRAIN="$base/plantas_train"
    VALID="$base/plantas_valid"
    break
  fi
  if [[ -d "$base/plantvillage/train" ]]; then
    TRAIN="$base/plantvillage/train"
    VALID="$base/plantvillage/valid"
    break
  fi
done

if [[ -z "$TRAIN" ]]; then
  echo "Descargando dataset desde Hugging Face..."
  python scripts/download_dataset_hf.py --out "$ROOT/data/plantvillage"
  TRAIN="$ROOT/data/plantvillage/train"
  VALID="$ROOT/data/plantvillage/valid"
fi

echo "TRAIN=$TRAIN"
echo "VALID=$VALID"

# --- Entrenar si no hay checkpoint ---
CKPT="$ROOT/checkpoints/resnet50.pt"
if [[ ! -f "$CKPT" ]]; then
  echo "Entrenando ResNet-50 (5 épocas)..."
  python -m src.train_resnet50 \
    --train-dir "$TRAIN" \
    --valid-dir "$VALID" \
    --epochs 5 \
    --batch-size 64 \
    --checkpoint-dir "$ROOT/checkpoints"
else
  echo "Checkpoint existente: $CKPT (omitir entrenamiento)"
fi

# --- Exportar artefactos AWS ---
echo "Exportando artefactos..."
python -m src.export_artifacts \
  --checkpoint "$CKPT" \
  --train-dir "$TRAIN" \
  --out "$ROOT/artifacts"

ls -lh "$ROOT/artifacts/"

echo "DONE" > "$STATUS"
echo "=== $(date) — FIN OK ==="

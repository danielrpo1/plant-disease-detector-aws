#!/bin/bash
# Referencia para EC2 Ubuntu — ejecutado desde /opt/plant-api
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/plant-api}"
cd "$APP_DIR"

echo "=== Swap 2GB ==="
if ! swapon --show | grep -q swapfile; then
  sudo fallocate -l 2G /swapfile 2>/dev/null || sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  grep -q swapfile /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo "=== Dependencias ==="
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip python3-venv awscli

echo "=== Venv Python ==="
python3 -m venv "$APP_DIR/.venv"
source "$APP_DIR/.venv/bin/activate"
pip install --upgrade pip -q
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu -q
pip install timm fastapi uvicorn[standard] python-multipart boto3 psycopg2-binary pydantic-settings pillow -q

echo "✓ Entorno listo en $APP_DIR/.venv"

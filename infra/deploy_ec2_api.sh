#!/usr/bin/env bash
# Despliega API FastAPI en EC2 (misma VPC que RDS) e instala servicio systemd.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
[[ -f .env.deployed ]] && set -a && source .env.deployed && set +a

export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-2}"
SUFFIX="${AWS_PROJECT_SUFFIX:-darestrepo-eafit}"
INSTANCE_TYPE="${EC2_INSTANCE_TYPE:-t3.micro}"
KEY_NAME="${EC2_KEY_NAME:-plant-disease-${SUFFIX}}"
DB_ID="${RDS_DB_INSTANCE_ID:-plant-disease-db-darestrepo-eafit}"
RDS_SG="${RDS_SECURITY_GROUP_ID:-sg-0f2b1310a4474ede6}"
ARTIFACTS_BUCKET="${S3_ARTIFACTS_BUCKET:?Falta S3_ARTIFACTS_BUCKET}"

echo "→ Bootstrap artifacts si faltan…"
if [[ ! -f artifacts/resnet50.pt ]]; then
  if [[ -x .venv/bin/python ]]; then
    .venv/bin/pip install -q torch timm 2>/dev/null || true
    .venv/bin/python scripts/bootstrap_artifacts.py
  else
    python3 -m venv .venv && .venv/bin/pip install -q torch timm && .venv/bin/python scripts/bootstrap_artifacts.py
  fi
fi

echo "→ Subiendo modelo a S3…"
aws s3 sync artifacts/ "s3://${ARTIFACTS_BUCKET}/models/" --region us-east-1

read -r VPC_ID SUBNET_ID <<<"$(
  aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
    --query 'DBInstances[0].[DBSubnetGroup.VpcId,DBSubnetGroup.Subnets[0].SubnetIdentifier]' \
    --output text
)"

AMI=$(aws ec2 describe-images --region "$AWS_DEFAULT_REGION" \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

SG_API="plant-disease-api-sg-${SUFFIX}"
aws ec2 create-security-group --group-name "$SG_API" --description "Ojoverde API" --vpc-id "$VPC_ID" 2>/dev/null || true
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_API" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 8000 --cidr 0.0.0.0/0 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "$RDS_SG" --protocol tcp --port 5432 --source-group "$SG_ID" 2>/dev/null || true

mkdir -p "$ROOT/infra/keys"
KEY_FILE="$ROOT/infra/keys/${KEY_NAME}.pem"
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_DEFAULT_REGION" &>/dev/null; then
  aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$AWS_DEFAULT_REGION" \
    --query KeyMaterial --output text > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
fi

EXISTING=$(aws ec2 describe-instances --region "$AWS_DEFAULT_REGION" \
  --filters "Name=tag:Name,Values=plant-disease-api" "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || true)

if [[ -n "$EXISTING" && "$EXISTING" != "None" ]]; then
  INSTANCE_ID="$EXISTING"
  echo "→ Reutilizando instancia API: $INSTANCE_ID"
else
  echo "→ Lanzando EC2 $INSTANCE_TYPE…"
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --subnet-id "$SUBNET_ID" \
    --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=plant-disease-api},{Key=Project,Value=ojoverde-aws}]" \
    --query 'Instances[0].InstanceId' --output text \
    --region "$AWS_DEFAULT_REGION")
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_DEFAULT_REGION"
fi

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_DEFAULT_REGION" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "→ Esperando SSH en $PUBLIC_IP…"
for i in $(seq 1 36); do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$KEY_FILE" "ubuntu@${PUBLIC_IP}" "echo ok" 2>/dev/null; then
    break
  fi
  [[ "$i" -eq 36 ]] && { echo "SSH timeout"; exit 1; }
  sleep 10
done

echo "→ Copiando código…"
ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" "ubuntu@${PUBLIC_IP}" "sudo mkdir -p /opt/plant-api && sudo chown ubuntu:ubuntu /opt/plant-api"
tar czf /tmp/plant-api.tgz --exclude='.venv' --exclude='.git' --exclude='data' --exclude='checkpoints' \
  -C "$ROOT" api src requirements.txt infra/ec2_setup.sh
scp -o StrictHostKeyChecking=no -i "$KEY_FILE" /tmp/plant-api.tgz "$ROOT/.env" "ubuntu@${PUBLIC_IP}:/opt/plant-api/"

ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" "ubuntu@${PUBLIC_IP}" bash -s <<REMOTE
set -euo pipefail
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
export S3_ARTIFACTS_BUCKET=${ARTIFACTS_BUCKET}
cd /opt/plant-api
tar xzf plant-api.tgz && rm plant-api.tgz
mkdir -p artifacts
bash infra/ec2_setup.sh
REMOTE

# Artefactos por SCP (EC2 sin rol IAM para S3)
scp -o StrictHostKeyChecking=no -i "$KEY_FILE" -r "$ROOT/artifacts" "ubuntu@${PUBLIC_IP}:/opt/plant-api/"

ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" "ubuntu@${PUBLIC_IP}" bash -s <<REMOTE
set -euo pipefail
cd /opt/plant-api
sudo tee /etc/systemd/system/plant-api.service > /dev/null <<'UNIT'
[Unit]
Description=Ojoverde Plant Disease API
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/plant-api
EnvironmentFile=/opt/plant-api/.env
Environment=MODEL_PATH=/opt/plant-api/artifacts/resnet50.pt
Environment=CLASSES_PATH=/opt/plant-api/artifacts/clases.json
Environment=DISPLAY_NAMES_PATH=/opt/plant-api/artifacts/nombres_display.json
ExecStart=/opt/plant-api/.venv/bin/uvicorn api.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable plant-api
sudo systemctl restart plant-api
sleep 5
curl -sf http://127.0.0.1:8000/health
REMOTE

API_URL="http://${PUBLIC_IP}:8000"
grep -v '^API_PUBLIC_URL=' "$ROOT/.env.deployed" > /tmp/deployed.tmp 2>/dev/null || true
mv /tmp/deployed.tmp "$ROOT/.env.deployed" 2>/dev/null || true
echo "API_PUBLIC_URL=${API_URL}" >> "$ROOT/.env.deployed"
echo "EC2_INSTANCE_ID=${INSTANCE_ID}" >> "$ROOT/.env.deployed"

echo ""
echo "✓ API desplegada: ${API_URL}"
echo "  Health: ${API_URL}/health"
echo "  Docs:   ${API_URL}/docs"

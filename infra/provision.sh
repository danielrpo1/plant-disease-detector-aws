#!/usr/bin/env bash
# Free tier: S3 + RDS db.t3.micro (+ guía EC2 t3.micro)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
else
  echo "Falta $ROOT/.env — cp .env.example .env y completa claves IAM."
  exit 1
fi

: "${AWS_ACCESS_KEY_ID:?Falta AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY:?Falta AWS_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"

SUFFIX="${AWS_PROJECT_SUFFIX:-darestrepo-eafit}"
ARTIFACTS_BUCKET="${S3_ARTIFACTS_BUCKET:-plant-artifacts-${SUFFIX}}"
DATALAKE_BUCKET="${S3_DATALAKE_BUCKET:-plant-datalake-${SUFFIX}}"
WEB_BUCKET="${S3_WEB_BUCKET:-plant-web-${SUFFIX}}"
RDS_DB="${RDS_DB_NAME:-plantdisease}"
RDS_USER="${RDS_MASTER_USERNAME:-plantadmin}"
RDS_PASS="${RDS_MASTER_PASSWORD:?Falta RDS_MASTER_PASSWORD}"
INSTANCE_TYPE="${EC2_INSTANCE_TYPE:-t3.micro}"

echo "=== Modo FREE TIER ==="
echo "Región: $AWS_DEFAULT_REGION"
echo "EC2 (manual después): $INSTANCE_TYPE"
echo "RDS: db.t3.micro"
echo "Buckets: $ARTIFACTS_BUCKET | $DATALAKE_BUCKET | $WEB_BUCKET"

if [[ "${FREE_TIER_AUTO_CONFIRM:-}" != "1" ]]; then
  read -r -p "¿Crear recursos? (free tier; budget alert recomendado) [y/N] " CONF
  [[ "${CONF,,}" == "y" ]] || exit 0
fi

command -v aws >/dev/null || { echo "Instala AWS CLI: brew install awscli"; exit 1; }
aws sts get-caller-identity

create_bucket() {
  local b="$1"
  if aws s3api head-bucket --bucket "$b" 2>/dev/null; then
    echo "Bucket OK: $b"
    return
  fi
  if [[ "$AWS_DEFAULT_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$b"
  else
    aws s3api create-bucket --bucket "$b" --region "$AWS_DEFAULT_REGION" \
      --create-bucket-configuration "LocationConstraint=$AWS_DEFAULT_REGION"
  fi
  if ! aws s3api put-public-access-block --bucket "$b" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true 2>/dev/null; then
    echo "  (aviso: sin permiso PutPublicAccessBlock; el bucket sigue válido)"
  fi
  echo "Creado: $b"
}

echo "=== S3 ==="
create_bucket "$ARTIFACTS_BUCKET"
create_bucket "$DATALAKE_BUCKET"
create_bucket "$WEB_BUCKET"

if [[ -d artifacts && -f artifacts/resnet50.pt ]]; then
  echo "=== Subiendo modelo ==="
  aws s3 sync artifacts/ "s3://${ARTIFACTS_BUCKET}/models/" \
    --exclude "*" --include "resnet50.pt" --include "*.json"
else
  echo "⚠ Sin artifacts/ local — sube después con:"
  echo "  aws s3 sync artifacts/ s3://${ARTIFACTS_BUCKET}/models/"
fi

echo "=== RDS PostgreSQL db.t3.micro (free tier, ~10 min) ==="
VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SG_DB="plant-disease-db-sg-${SUFFIX}"
aws ec2 create-security-group --group-name "$SG_DB" --description "RDS plant" --vpc-id "$VPC_ID" 2>/dev/null || true
DB_SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$SG_DB" --query 'SecurityGroups[0].GroupId' --output text)

RDS_ID="plant-disease-db-${SUFFIX}"
if ! aws rds describe-db-instances --db-instance-identifier "$RDS_ID" &>/dev/null; then
  aws rds create-db-instance \
    --db-instance-identifier "$RDS_ID" \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 16 \
    --master-username "$RDS_USER" \
    --master-user-password "$RDS_PASS" \
    --allocated-storage 20 \
    --storage-type gp2 \
    --db-name "$RDS_DB" \
    --backup-retention-period 0 \
    --no-publicly-accessible \
    --vpc-security-group-ids "$DB_SG_ID" \
    --tags Key=Project,Value=plant-disease-eafit Key=FreeTier,Value=true
  echo "Esperando RDS..."
  aws rds wait db-instance-available --db-instance-identifier "$RDS_ID"
fi

RDS_HOST=$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" \
  --query 'DBInstances[0].Endpoint.Address' --output text)
DATABASE_URL="postgresql://${RDS_USER}:${RDS_PASS}@${RDS_HOST}:5432/${RDS_DB}"

cat > "$ROOT/.env.deployed" <<EOF
# Generado por provision.sh — free tier
S3_ARTIFACTS_BUCKET=$ARTIFACTS_BUCKET
S3_DATALAKE_BUCKET=$DATALAKE_BUCKET
S3_WEB_BUCKET=$WEB_BUCKET
DATABASE_URL=$DATABASE_URL
RDS_ENDPOINT=$RDS_HOST
EC2_INSTANCE_TYPE=$INSTANCE_TYPE
EOF

echo ""
echo "✓ Free tier (fase 1) listo."
echo "  .env.deployed actualizado"
echo ""
echo "Siguiente:"
echo "  1. psql o cliente SQL → infra/sql/init.sql"
echo "  2. ./infra/deploy_ec2_free_tier.sh  (cuando tengas artifacts en S3)"
echo "  3. Al terminar el curso: ./infra/destroy.sh"

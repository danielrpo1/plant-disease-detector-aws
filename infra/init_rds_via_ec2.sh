#!/usr/bin/env bash
# Inicializa tabla predictions en RDS privado desde EC2 en la misma VPC.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a

export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-2}"
SUFFIX="${AWS_PROJECT_SUFFIX:-darestrepo-eafit}"
DB_ID="${RDS_DB_INSTANCE_ID:-plant-disease-db-darestrepo-eafit}"
RDS_SG="${RDS_SECURITY_GROUP_ID:-sg-0f2b1310a4474ede6}"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "Falta DATABASE_URL en .env" >&2
  exit 1
fi

echo "→ Leyendo VPC/subred de RDS…"
read -r VPC_ID SUBNET_ID <<<"$(
  aws rds describe-db-instances --db-instance-identifier "$DB_ID" \
    --query 'DBInstances[0].[DBSubnetGroup.VpcId,DBSubnetGroup.Subnets[0].SubnetIdentifier]' \
    --output text
)"

INIT_SG="plant-disease-rds-init-${SUFFIX}"
echo "→ Grupo de seguridad temporal: $INIT_SG (VPC $VPC_ID)"
aws ec2 create-security-group \
  --group-name "$INIT_SG" \
  --description "EC2 one-shot init RDS" \
  --vpc-id "$VPC_ID" \
  --region "$AWS_DEFAULT_REGION" 2>/dev/null || true

INIT_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$INIT_SG" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text)

echo "→ Permitiendo PostgreSQL desde $INIT_SG_ID hacia RDS ($RDS_SG)…"
aws ec2 authorize-security-group-ingress \
  --group-id "$RDS_SG" \
  --protocol tcp \
  --port 5432 \
  --source-group "$INIT_SG_ID" \
  --region "$AWS_DEFAULT_REGION" 2>/dev/null || true

AMI=$(aws ec2 describe-images --region "$AWS_DEFAULT_REGION" \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

SQL_B64=$(base64 < "$ROOT/infra/sql/init.sql" | tr -d '\n')
DB_URL_B64=$(printf '%s' "$DATABASE_URL" | base64 | tr -d '\n')

USER_DATA=$(cat <<EOF
#!/bin/bash
set -euo pipefail
exec > /var/log/rds-init.log 2>&1
echo "RDS init started"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv python3-pip
python3 -m venv /opt/rdsinit
/opt/rdsinit/bin/pip install -q psycopg2-binary
echo "$SQL_B64" | base64 -d > /tmp/init.sql
export DATABASE_URL="\$(echo "$DB_URL_B64" | base64 -d)"
/opt/rdsinit/bin/python3 << 'PY'
import os, psycopg2
from pathlib import Path
sql = Path("/tmp/init.sql").read_text(encoding="utf-8")
conn = psycopg2.connect(os.environ["DATABASE_URL"])
conn.autocommit = True
with conn.cursor() as cur:
    cur.execute(sql)
conn.close()
print("INIT_OK")
PY
echo "INIT_DONE"
shutdown -h now
EOF
)

echo "→ Lanzando EC2 temporal en $SUBNET_ID…"
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI" \
  --instance-type t3.micro \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$INIT_SG_ID" \
  --associate-public-ip-address \
  --user-data "$USER_DATA" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=plant-rds-init},{Key=Purpose,Value=rds-init}]" \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region "$AWS_DEFAULT_REGION")

echo "Instancia: $INSTANCE_ID — esperando stopped (init + apagado)…"
for i in $(seq 1 60); do
  STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' --output text --region "$AWS_DEFAULT_REGION")
  echo "  estado: $STATE ($i/60)"
  if [[ "$STATE" == "stopped" || "$STATE" == "terminated" ]]; then
    break
  fi
  sleep 15
done

echo "→ Log de consola:"
aws ec2 get-console-output --instance-id "$INSTANCE_ID" --latest \
  --query Output --output text --region "$AWS_DEFAULT_REGION" 2>/dev/null | tail -30 || true

if aws ec2 get-console-output --instance-id "$INSTANCE_ID" --latest \
  --query Output --output text --region "$AWS_DEFAULT_REGION" 2>/dev/null | grep -q INIT_OK; then
  echo "✓ Tabla predictions creada en RDS."
else
  echo "⚠ No se vio INIT_OK en consola. Verifica /var/log/rds-init.log con SSM o relanza."
  exit 1
fi

echo "→ Terminando instancia $INSTANCE_ID…"
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$AWS_DEFAULT_REGION" >/dev/null
echo "Listo."

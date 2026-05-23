#!/usr/bin/env bash
# Lanza EC2 t3.micro (free tier) con user-data para API FastAPI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
[[ -f .env.deployed ]] && set -a && source .env.deployed && set +a

export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"
SUFFIX="${AWS_PROJECT_SUFFIX:-darestrepo-eafit}"
INSTANCE_TYPE="${EC2_INSTANCE_TYPE:-t3.micro}"
KEY_NAME="${EC2_KEY_NAME:-plant-disease-${SUFFIX}}"
ARTIFACTS_BUCKET="${S3_ARTIFACTS_BUCKET:?Falta S3_ARTIFACTS_BUCKET — corre provision.sh primero}"

AMI=$(aws ssm get-parameters --names /aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id \
  --query 'Parameters[0].Value' --output text)

VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNET=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
  --query 'Subnets[0].SubnetId' --output text)

SG_API="plant-disease-api-sg-${SUFFIX}"
aws ec2 create-security-group --group-name "$SG_API" --description "API plant" --vpc-id "$VPC_ID" 2>/dev/null || true
SG_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$SG_API" --query 'SecurityGroups[0].GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 8000 --cidr 0.0.0.0/0 2>/dev/null || true

if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" &>/dev/null; then
  mkdir -p "$ROOT/infra/keys"
  aws ec2 create-key-pair --key-name "$KEY_NAME" --query KeyMaterial --output text > "$ROOT/infra/keys/${KEY_NAME}.pem"
  chmod 600 "$ROOT/infra/keys/${KEY_NAME}.pem"
  echo "Clave SSH: infra/keys/${KEY_NAME}.pem"
fi

USER_DATA=$(cat <<'UD'
#!/bin/bash
set -e
apt-get update
apt-get install -y python3-pip python3-venv git
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
UD
)

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --subnet-id "$SUBNET" \
  --user-data "$USER_DATA" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=plant-disease-api},{Key=FreeTier,Value=true}]" \
  --query 'Instances[0].InstanceId' --output text)

echo "Instancia: $INSTANCE_ID — esperando running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo ""
echo "EC2 free tier: $INSTANCE_ID"
echo "IP pública: $PUBLIC_IP"
echo "API (tras instalar manualmente o scp): http://${PUBLIC_IP}:8000"
echo ""
echo "Sube código: scp -i infra/keys/${KEY_NAME}.pem -r api src requirements.txt ubuntu@${PUBLIC_IP}:~/"
echo "En .env.deployed añade: API_PUBLIC_URL=http://${PUBLIC_IP}:8000"

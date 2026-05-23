#!/usr/bin/env bash
# Elimina recursos del proyecto para no seguir pagando.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
[[ -f .env.deployed ]] && set -a && source .env.deployed && set +a

export AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"
SUFFIX="${AWS_PROJECT_SUFFIX:-darestrepo-eafit}"
RDS_ID="plant-disease-db-${SUFFIX}"

read -r -p "¿Borrar RDS $RDS_ID y vaciar buckets? [y/N] " CONF
[[ "${CONF,,}" == "y" ]] || exit 0

if aws rds describe-db-instances --db-instance-identifier "$RDS_ID" &>/dev/null; then
  echo "Eliminando RDS (puede tardar)..."
  aws rds delete-db-instance --db-instance-identifier "$RDS_ID" --skip-final-snapshot
fi

for b in "${S3_ARTIFACTS_BUCKET:-}" "${S3_DATALAKE_BUCKET:-}" "${S3_WEB_BUCKET:-}"; do
  [[ -z "$b" ]] && continue
  if aws s3api head-bucket --bucket "$b" 2>/dev/null; then
    echo "Vaciando $b..."
    aws s3 rm "s3://$b" --recursive || true
    aws s3api delete-bucket --bucket "$b" || true
  fi
done

echo "EC2: termina instancias manualmente en consola si creaste alguna."
echo "Listo."

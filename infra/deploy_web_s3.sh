#!/usr/bin/env bash
# Publica webapp Ojoverde en S3 (sitio estático).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
[[ -f .env.deployed ]] && set -a && source .env.deployed && set +a

WEB_BUCKET="${S3_WEB_BUCKET:?Falta S3_WEB_BUCKET}"
API_URL="${API_PUBLIC_URL:-}"

if [[ -n "$API_URL" ]]; then
  cat > webapp/config.js <<EOF
window.API_URL = "${API_URL}";
EOF
else
  echo "⚠ API_PUBLIC_URL no definida — config.js queda vacío"
fi

aws s3 sync webapp/ "s3://${WEB_BUCKET}/" --delete --region us-east-1 \
  --exclude ".DS_Store"

aws s3 website "s3://${WEB_BUCKET}/" --index-document index.html --error-document index.html --region us-east-1 2>/dev/null || true

# Política lectura pública (si el usuario IAM lo permite)
POLICY=$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicRead",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::${WEB_BUCKET}/*"
  }]
}
JSON
)
echo "$POLICY" > /tmp/web-policy.json
aws s3api put-bucket-policy --bucket "$WEB_BUCKET" --policy file:///tmp/web-policy.json --region us-east-1 2>/dev/null || \
  echo "⚠ No se pudo aplicar bucket policy (sube manualmente o usa CloudFront)"

WEB_URL="http://${WEB_BUCKET}.s3-website-us-east-1.amazonaws.com"
echo "WEB_PUBLIC_URL=${WEB_URL}" >> .env.deployed
echo "✓ Web en S3: ${WEB_URL}"

# Datos que necesito de tu AWS (para desplegar yo el stack)

No compartas claves en chat público. Usa un archivo **`.env`** local (gitignored) o **AWS IAM Identity Center**.

## 1. Credenciales IAM (obligatorio)

Crea un usuario IAM **solo para el proyecto** con programático access, o un rol si usas SSO.

| Variable | Ejemplo | Para qué |
|----------|---------|----------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` | CLI / boto3 |
| `AWS_SECRET_ACCESS_KEY` | `wJalr...` | CLI / boto3 |
| `AWS_REGION` | `us-east-1` | Todos los recursos en la misma región |

**Permisos mínimos** (política personalizada recomendada):

- S3: crear bucket, `PutObject`, `GetObject` en tus buckets del proyecto
- EC2: `RunInstances`, `DescribeInstances`, security groups, key pairs
- RDS: `CreateDBInstance`, `DescribeDBInstances` (solo si creamos PostgreSQL)
- IAM: pasar rol a instancia EC2 (`PassRole`) si usamos instance profile

> Alternativa más segura: tú creas los buckets y RDS en consola y me pasas solo nombres + endpoint + usuario DB (sin admin keys).

## 2. Nombres únicos (elige un sufijo)

Los buckets deben ser **globalmente únicos**:

| Variable | Tu valor (ejemplo) |
|----------|-------------------|
| `S3_ARTIFACTS_BUCKET` | `plant-artifacts-darestrepo` |
| `S3_DATALAKE_BUCKET` | `plant-datalake-darestrepo` |
| `S3_WEB_BUCKET` | `plant-web-darestrepo` |

## 3. PostgreSQL RDS (obligatorio curso)

| Variable | Descripción |
|----------|-------------|
| `RDS_DB_NAME` | `plantdisease` |
| `RDS_MASTER_USERNAME` | `plantadmin` |
| `RDS_MASTER_PASSWORD` | **Contraseña fuerte** (16+ caracteres) — solo en `.env` |
| `DATABASE_URL` | Se arma tras crear RDS: `postgresql://user:pass@host:5432/plantdisease` |

Si prefieres crear RDS tú: pásame **endpoint**, **puerto**, **usuario**, **contraseña**, **nombre DB**.

## 4. EC2 (API FastAPI)

| Dato | Descripción |
|------|-------------|
| Par de claves `.pem` | Nombre en AWS: `plant-disease-key` (o subes tú la pública) |
| Tipo instancia | `t3.micro` (free tier, 1 GB RAM) o `t3.small` si ResNet no cabe |
| IP pública | La obtendremos al crear la instancia |

## 5. Presupuesto (obligatorio antes de crear nada)

- Confirmación de que creaste **Budget alert** (ej. 5 USD/mes) en AWS Budgets.
- ¿Tienes **free tier** activo o **créditos estudiante**? (sí/no + monto aprox.)

## 6. Dominio / HTTPS (opcional)

- Si quieres dominio propio: nombre + certificado ACM.
- Si no: usamos **CloudFront** + URL por defecto `*.cloudfront.net`.

---

## Plantilla `.env` (cópiala y complétala)

```bash
# === AWS (no subir a GitHub) ===
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=us-east-1

S3_ARTIFACTS_BUCKET=
S3_DATALAKE_BUCKET=
S3_WEB_BUCKET=

RDS_DB_NAME=plantdisease
RDS_MASTER_USERNAME=plantadmin
RDS_MASTER_PASSWORD=
# Tras crear RDS:
DATABASE_URL=postgresql://plantadmin:PASSWORD@endpoint.rds.amazonaws.com:5432/plantdisease

# URL pública API (tras EC2):
API_PUBLIC_URL=http://EC2_IP:8000
```

## Qué haré yo cuando tenga esto

1. Subir `artifacts/` (desde Lightning) a `S3_ARTIFACTS_BUCKET`.
2. Crear RDS + tabla `predictions` (`infra/sql/init.sql`).
3. Lanzar EC2, instalar API, conectar S3 + PostgreSQL.
4. Subir `webapp/` a S3 + CloudFront con `API_PUBLIC_URL` en `config.js`.

## Qué NO necesito

- Contraseña de tu cuenta root de AWS.
- Acceso a tu email de facturación.
- El dataset de 87k imágenes (solo el `.pt` + JSON).

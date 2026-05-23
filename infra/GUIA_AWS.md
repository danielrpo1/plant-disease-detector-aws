# Guía AWS — paso a paso (ResNet-50)

**Proyecto paralelo** al demo ONNX en GitHub Pages. No modifica el otro repositorio.

## Arquitectura objetivo

```
Usuario (web móvil / navegador)
    → S3 + CloudFront (HTML/JS estático)
    → POST imagen → EC2 FastAPI + ResNet-50
           ├→ S3 data lake (imagen cruda)
           └→ RDS PostgreSQL (predicción + metadata)
    ← JSON diagnóstico + confianza
```

## Etapa 0 — Budget alert (hazlo ANTES de crear recursos)

**Costo:** gratis (solo alertas).

1. AWS Console → **Billing** → **Budgets** → Create budget.
2. Tipo: **Cost budget**, monto fijo **5 USD** / mes.
3. Alerta al **80 %** y **100 %** → tu email.
4. Confirma que recibes el correo de prueba.

> El free tier de AWS cambió en julio 2025. Revisa en Billing → Free tier qué aplica a tu cuenta.

---

## Etapa 1 — Exportar modelo (Lightning) ✅ código en repo

Ver `notebooks/05_exportar_modelo.ipynb` o:

```bash
python -m src.export_artifacts \
  --checkpoint checkpoints/resnet50.pt \
  --train-dir /ruta/plantas_train \
  --out artifacts/
```

**Solo subes a AWS:** `resnet50.pt` (~100 MB) + 2 JSON. No el dataset de 87k imágenes.

---

## Etapa 2 — Subir artefactos a S3

**Costo estimado:** centavos (almacenamiento ~0.023 USD/GB-mes).

```bash
aws s3 mb s3://plant-disease-artifacts-TUINICIALES --region us-east-1
aws s3 cp artifacts/resnet50.pt s3://plant-disease-artifacts-TUINICIALES/models/
aws s3 cp artifacts/clases.json s3://plant-disease-artifacts-TUINICIALES/models/
aws s3 cp artifacts/nombres_display.json s3://plant-disease-artifacts-TUINICIALES/models/
```

Bloquea acceso público al bucket de artefactos (solo EC2 con IAM role).

---

## Etapa 3 — Data lake (imágenes de usuarios)

**Costo:** crece con uso; lifecycle policy recomendada.

```bash
aws s3 mb s3://plant-disease-datalake-TUINICIALES
```

Prefijo sugerido: `uploads/YYYY/MM/DD/{uuid}.jpg`

---

## Etapa 4 — RDS PostgreSQL (obligatorio curso)

**Costo:** db.t3.micro ~0 USD primer año (free tier) si aplica; si no, ~15–20 USD/mes.

⚠ **Irreversible sin snapshot:** borrar instancia pierde datos si no hay backup.

1. RDS → Create database → **PostgreSQL**.
2. Template: Free tier (si disponible).
3. DB identifier: `plant-disease-db`
4. Master user / password (guárdalos en `.env`, nunca en git).
5. Public access: **No** (más seguro); EC2 en la misma VPC.
6. Crear tabla (desde EC2 o bastion):

```sql
CREATE TABLE predictions (
  id SERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  s3_key VARCHAR(512) NOT NULL,
  predicted_class VARCHAR(128) NOT NULL,
  confidence REAL NOT NULL,
  display_name VARCHAR(256),
  top3 JSONB
);
```

---

## Etapa 5 — EC2 + FastAPI

**Costo:** t2/t3.micro free tier 750 h/mes (1 instancia); si RAM no alcanza → t3.small ~15 USD/mes.

**Riesgo RAM:** ResNet-50 + PyTorch CPU ~1–1.5 GB. En 1 GB RAM:

- Instalar `torch` CPU-only.
- Añadir **2 GB swap** en disco.
- O usar **t3.small** (2 GB RAM).

Pasos resumidos:

1. AMI Ubuntu 22.04, tipo **t3.micro**, par de claves `.pem`.
2. Security group: puerto **22** (tu IP), **8000** (API) o **443** detrás de ALB.
3. IAM role en la instancia: lectura bucket artefactos + escritura data lake.
4. Clonar repo, `pip install -r requirements.txt`, copiar `.env`.
5. Descargar modelo desde S3 a `/opt/models/`.
6. `uvicorn api.main:app --host 0.0.0.0 --port 8000`.

Script de ayuda: [`ec2_setup.sh`](ec2_setup.sh) (referencia, revisar antes de ejecutar).

---

## Etapa 6 — Frontend en S3 + CloudFront

**Costo:** bajo para tráfico académico; CloudFront tiene capa gratuita limitada.

1. Bucket web estático → subir `webapp/`.
2. En `webapp/config.js` poner URL pública de la API EC2.
3. CORS en FastAPI debe permitir el origen del bucket/CloudFront.
4. CloudFront → HTTPS → bucket.

---

## Checklist antes de entregar

- [ ] Budget alert activo
- [ ] Predicción funciona con imagen de prueba
- [ ] Imagen guardada en S3 data lake
- [ ] Fila insertada en PostgreSQL
- [ ] Web accesible por HTTPS
- [ ] Documentar costos estimados en el informe

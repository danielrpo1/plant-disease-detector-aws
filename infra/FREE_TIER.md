# Despliegue en AWS Free Tier (académico, ~0 USD)

## Recursos que usamos

| Recurso | Tamaño free tier | Notas |
|---------|------------------|--------|
| S3 × 3 | ~5 GB gratis | Modelo + fotos + web |
| RDS PostgreSQL | **db.t3.micro** | Marca “Free tier” al crear en consola |
| EC2 API | **t3.micro** | 750 h/mes; ResNet con swap |
| Sin NAT Gateway | — | Muy caro; no lo usamos |
| Sin Elastic IP fija | — | Evita cargos si no está asociada |

## Antes de provisionar

1. Budget alert **1 USD** en [AWS Budgets](https://console.aws.amazon.com/billing/home#/budgets).
2. Archivo `.env` con claves IAM (ver `.env.example`).
3. `artifacts/resnet50.pt` + JSON (desde Lightning).

## Crear infraestructura

```bash
cd plant-disease-detector-aws
cp .env.example .env   # completar claves
./infra/provision.sh
```

## Al terminar el curso (importante)

```bash
./infra/destroy.sh
```

Borra RDS y EC2 (lo que más cuesta). Los buckets puedes vaciarlos y borrarlos.

## Si EC2 se queda sin RAM

El script `ec2_setup.sh` añade 2 GB de swap. Inferencia con PyTorch **CPU only**.

# Arquitectura AWS — Ojoverde (Plant Disease Detector)

Proyecto integrador EAFIT: clasificación de enfermedades en hojas con **ResNet-50**, desplegado en AWS.

## Diagrama de arquitectura

```mermaid
flowchart TB
  subgraph users [Usuarios]
    U[📱 Navegador móvil / desktop]
  end

  subgraph aws [Amazon Web Services — us-east-1 / us-east-2]
    subgraph static [Frontend estático]
      S3W[(S3 plant-web<br/>Ojoverde webapp)]
    end

    subgraph compute [Cómputo]
      EC2[EC2 t3.micro<br/>FastAPI + ResNet-50<br/>puerto 8000]
    end

    subgraph storage [Almacenamiento]
      S3A[(S3 plant-artifacts<br/>resnet50.pt, clases.json)]
      S3D[(S3 plant-datalake<br/>uploads/YYYY/MM/DD)]
      RDS[(RDS PostgreSQL<br/>plantdisease.predictions)]
    end
  end

  U -->|HTTPS GET| S3W
  U -->|POST /predict multipart| EC2
  EC2 -->|Descarga modelo al arrancar| S3A
  EC2 -->|Guarda imagen| S3D
  EC2 -->|INSERT predicción| RDS
  S3W -.->|config.js API_URL| EC2
```

## Flujo de una predicción

```mermaid
sequenceDiagram
  participant U as Usuario
  participant W as Web S3
  participant A as API EC2
  participant M as ResNet-50
  participant S as S3 datalake
  participant D as RDS PostgreSQL

  U->>W: Abre Ojoverde
  W->>U: HTML/CSS/JS + API_URL
  U->>A: POST /predict (imagen)
  A->>M: Inferencia CPU
  M-->>A: top-3 clases + confianza
  A->>S: put_object uploads/…
  A->>D: INSERT predictions
  A-->>U: JSON resultado + s3_key + prediction_id
```

## Componentes

| Servicio | Recurso | Región | Rol |
|----------|---------|--------|-----|
| **S3 web** | `plant-web-darestrepo-eafit` | us-east-1 | Frontend Ojoverde (HTML/JS/CSS) |
| **S3 artifacts** | `plant-artifacts-darestrepo-eafit` | us-east-1 | Modelo `resnet50.pt` y JSON de clases |
| **S3 datalake** | `plant-datalake-darestrepo-eafit` | us-east-1 | Imágenes subidas por usuarios |
| **RDS** | `plant-disease-db-darestrepo-eafit` | us-east-2 | Historial en tabla `predictions` |
| **EC2** | `plant-disease-api` (t3.micro) | us-east-2 | API FastAPI + inferencia |

## Red y seguridad

```mermaid
flowchart LR
  subgraph vpc [VPC us-east-2]
    EC2[EC2 API SG]
    RDS[RDS SG :5432]
  end
  Internet((Internet)) -->|:8000| EC2
  Internet -->|:5432 solo dev| RDS
  EC2 -->|:5432| RDS
```

- La API EC2 y RDS comparten VPC; el grupo de seguridad de RDS permite PostgreSQL desde el SG de la API.
- RDS puede estar en modo privado en producción; la API accede por red interna.
- Las claves IAM del despliegue **no** van al repositorio (`.env` en `.gitignore`).

## Repos relacionados

| Repo | URL | Rol |
|------|-----|-----|
| Demo ONNX (GitHub Pages) | [plant-disease-detector](https://github.com/danielrpo1/plant-disease-detector) | EfficientNet-B0 en navegador |
| **AWS (este)** | [plant-disease-detector-aws](https://github.com/danielrpo1/plant-disease-detector-aws) | ResNet-50 + S3 + RDS + EC2 |

## Scripts de despliegue

```bash
./infra/deploy_ec2_api.sh   # EC2 + systemd + health check
./infra/deploy_web_s3.sh    # webapp → S3 + config.js con API_URL
python scripts/init_rds.py   # tabla predictions (desde Mac si RDS público)
```

## Coste estimado (free tier)

- EC2 t3.micro: 750 h/mes gratis (12 meses)
- RDS db.t3.micro: 750 h/mes gratis (12 meses)
- S3: pocos GB → centavos
- **Budget alert recomendado:** 5 USD/mes

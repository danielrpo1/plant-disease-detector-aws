# Qué necesito de ti para crear TODO en AWS

Yo puedo crear buckets, RDS, EC2, subir el modelo y la web **desde tu máquina** con scripts, pero AWS solo obedece a **tu cuenta**. Necesito acceso programático (como una llave API), no tu contraseña de la consola web.

---

## Lo mínimo (4 cosas)

### 1. Usuario IAM con acceso programático

En [AWS Console → IAM → Users → Create user](https://console.aws.amazon.com/iam/):

1. Nombre: `plant-disease-deploy`
2. **No** marques acceso a consola (opcional).
3. Permisos: **Attach policies directly** → **Create policy** → JSON → pega el archivo del repo:  
   [`infra/iam-policy-deploy.json`](../infra/iam-policy-deploy.json)  
   Nombre sugerido: `PlantDiseaseDeployPolicy`
4. Crea el usuario y en **Security credentials** → **Create access key** → tipo **CLI**.
5. Guarda **Access key ID** y **Secret access key** (solo se muestra una vez).

### 2. Archivo `.env` en tu laptop (no en GitHub, no en el chat)

Copia en la raíz del proyecto AWS:

```bash
cd plant-disease-detector-aws
cp .env.example .env
```

Edita `.env` con esto:

```bash
AWS_ACCESS_KEY_ID=AKIAxxxxxxxx
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_REGION=us-east-1

# Sufijo único (solo letras minúsculas y guiones) — yo genero los nombres de buckets
AWS_PROJECT_SUFFIX=darestrepo-eafit

# Contraseña para PostgreSQL (tú la inventas, 16+ caracteres)
RDS_MASTER_PASSWORD=TuContraseñaSegura123!

# Opcional: tipo EC2 (t3.small recomendado para ResNet50)
EC2_INSTANCE_TYPE=t3.small
```

**No me pegues las claves en WhatsApp/Discord/chat de Cursor.**  
Dime solo: *“ya está el .env en la carpeta del proyecto”* y yo ejecuto los scripts desde aquí.

### 3. Budget alert (obligatorio, lo haces tú en 2 minutos)

[AWS Budgets](https://console.aws.amazon.com/billing/home#/budgets) → Create budget → **5 USD/mes** → alerta al 80 % y 100 % → tu email.

Respóndeme: **“budget listo”**.

### 4. Artefactos del modelo (cuando Lightning termine)

Necesito la carpeta `artifacts/` con:

- `resnet50.pt`
- `clases.json`
- `nombres_display.json`

Puedes descargarla del Studio a:

`plant-disease-detector-aws/artifacts/`

Si aún entrena, esperamos; sin esto creo la infra pero la API no predice hasta subir el `.pt`.

---

## Lo que NO necesito

| No hace falta | Por qué |
|---------------|---------|
| Usuario root de AWS | Muy peligroso |
| Contraseña de login a console.aws.amazon.com | Uso Access Key, no login web |
| Tarjeta de crédito | Ya la tienes en la cuenta |
| Dataset de 87k imágenes | Solo el modelo ~100 MB |
| Que crees buckets a mano | Los crea `infra/provision.sh` |

---

## Lo que yo crearé automáticamente

| Recurso | Para qué |
|---------|----------|
| **S3** `plant-artifacts-*` | `resnet50.pt` + JSON |
| **S3** `plant-datalake-*` | Fotos que suban usuarios |
| **S3** `plant-web-*` | HTML/JS del front |
| **RDS** PostgreSQL `db.t3.micro` | Historial de predicciones (requisito curso) |
| **EC2** + FastAPI | ResNet-50 en servidor |
| **Security groups** | Puertos 22, 8000, RDS |
| **CloudFront** (opcional fase 2) | HTTPS al front |

---

## Costos aproximados (para tu informe)

| Servicio | Free tier / estimado |
|----------|----------------------|
| S3 | Centavos en demo |
| RDS db.t3.micro | 0–20 USD/mes según cuenta |
| EC2 t3.small | ~15 USD/mes si no hay créditos |
| CloudFront | Bajo tráfico académico |

**Apaga o borra** recursos después del curso: RDS y EC2 son los que más cuestan.

---

## Cómo seguimos

1. Tú: IAM + `.env` + budget alert.  
2. Tú: “listo” (sin pegar secretos).  
3. Yo: instalo AWS CLI si falta, ejecuto `infra/provision.sh` y despliegue EC2/API.  
4. Te devuelvo URLs: web CloudFront/S3 + API + ejemplo de prueba.

---

## Si prefieres política administrador (solo para prueba rápida)

En cuenta **personal de prueba** puedes adjuntar `AdministratorAccess` al usuario IAM.  
**No recomendado** en cuenta de producción o con datos sensibles.

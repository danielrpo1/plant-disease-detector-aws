# RDS lista — un paso en consola (acceso desde tu Mac)

Tu base **ya está disponible**:

- **Endpoint:** `plant-disease-db-darestrepo-eafit.cbis88iw4dxg.us-east-2.rds.amazonaws.com`
- **Usuario:** `plantadmin`
- **Base:** `plantdisease`
- **Región:** `us-east-2`

Hoy está con **acceso público: No**, por eso el script desde tu laptop no conecta aún.

## Habilitar acceso (consola, 2 min)

1. **RDS** → **Bases de datos** → `plant-disease-db-darestrepo-eafit`
2. **Modificar**
3. **Conectividad** → **Acceso público: Sí**
4. **Continuar** → **Aplicar de inmediato**
5. En la misma instancia, pestaña **Conectividad y seguridad** → clic en el **grupo de seguridad** (VPC)
6. **Reglas de entrada** → **Agregar regla**:
   - Tipo: PostgreSQL
   - Puerto: 5432
   - Origen: **Mi IP** (recomendado) o temporalmente `0.0.0.0/0` solo para prueba
7. Guardar

## Crear la tabla

```bash
cd plant-disease-detector-aws
python3 -m venv .venv
source .venv/bin/activate
pip install psycopg2-binary
python scripts/init_rds.py
```

Debe imprimir: `✓ Tabla predictions lista.`

## Variables ya en `.env`

`DATABASE_URL` ya está configurada en el proyecto AWS.

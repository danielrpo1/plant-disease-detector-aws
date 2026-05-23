#!/usr/bin/env python3
"""Crea tabla predictions en RDS. Lee DATABASE_URL desde .env"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
env = ROOT / ".env"
if env.exists():
    for line in env.read_text().splitlines():
        if "=" in line and not line.strip().startswith("#"):
            k, v = line.split("=", 1)
            import os

            os.environ.setdefault(k.strip(), v.strip())

import os
from urllib.parse import urlparse, urlunparse

import psycopg2

SQL = (ROOT / "infra" / "sql" / "init.sql").read_text(encoding="utf-8")

url = os.environ.get("DATABASE_URL")
if not url:
    raise SystemExit("Falta DATABASE_URL en .env")

db_name = os.environ.get("RDS_DB_NAME", "plantdisease")


def admin_url(target_db: str = "postgres") -> str:
    parsed = urlparse(url)
    return urlunparse(parsed._replace(path=f"/{target_db}"))


print("Conectando a RDS…")
admin = psycopg2.connect(admin_url("postgres"))
admin.autocommit = True
with admin.cursor() as cur:
    cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (db_name,))
    if not cur.fetchone():
        cur.execute(f'CREATE DATABASE "{db_name}"')
        print(f"✓ Base de datos «{db_name}» creada.")
admin.close()

conn = psycopg2.connect(url)
conn.autocommit = True
with conn.cursor() as cur:
    cur.execute(SQL)
conn.close()
print("✓ Tabla predictions lista.")

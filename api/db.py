"""PostgreSQL — historial de predicciones (Etapa 4+)."""

from __future__ import annotations

import json
from contextlib import contextmanager
from typing import Any

import psycopg2
from psycopg2.extras import Json

from api.config import settings


@contextmanager
def get_conn():
    if not settings.database_url:
        raise RuntimeError("DATABASE_URL no configurada en .env")
    conn = psycopg2.connect(settings.database_url)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def insert_prediction(
    s3_key: str,
    predicted_class: str,
    confidence: float,
    display_name: str,
    top3: list[dict[str, Any]],
) -> int:
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO predictions (s3_key, predicted_class, confidence, display_name, top3)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id
                """,
                (s3_key, predicted_class, confidence, display_name, Json(top3)),
            )
            row = cur.fetchone()
            return int(row[0])

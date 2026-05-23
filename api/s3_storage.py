"""Subida de imágenes al data lake S3."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

import boto3

from api.config import settings


def upload_image_bytes(data: bytes, content_type: str = "image/jpeg") -> str:
    if not settings.s3_datalake_bucket:
        raise RuntimeError("S3_DATALAKE_BUCKET no configurado")
    now = datetime.now(timezone.utc)
    key = f"uploads/{now:%Y/%m/%d}/{uuid.uuid4().hex}.jpg"
    client = boto3.client("s3", region_name=settings.aws_region)
    client.put_object(
        Bucket=settings.s3_datalake_bucket,
        Key=key,
        Body=data,
        ContentType=content_type,
    )
    return key

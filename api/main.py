"""
FastAPI en EC2 — Etapa 5+

  uvicorn api.main:app --host 0.0.0.0 --port 8000

Sin AWS configurado: predice igual, pero no guarda S3/RDS.
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from api.config import settings
from src.inference import load_inference_bundle, predict_image

_model = None
_class_names: list[str] = []
_display_names: dict[str, str] = {}
_device = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _model, _class_names, _display_names, _device
    _model, _class_names, _display_names, _device = load_inference_bundle(
        settings.model_path,
        settings.classes_path,
        settings.display_names_path,
    )
    yield


app = FastAPI(title="Plant Disease API (ResNet-50)", lifespan=lifespan)

_origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok", "model": "resnet50"}


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    data = await file.read()
    # Guardar temporalmente en memoria vía PIL
    import io
    from PIL import Image

    img = Image.open(io.BytesIO(data)).convert("RGB")
    import tempfile
    from pathlib import Path

    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
        img.save(tmp.name)
        tmp_path = Path(tmp.name)

    try:
        result = predict_image(
            _model,
            tmp_path,
            _class_names,
            _display_names,
            device=_device,
        )
    finally:
        tmp_path.unlink(missing_ok=True)

    s3_key = None
    db_id = None

    if settings.s3_datalake_bucket:
        try:
            from api.s3_storage import upload_image_bytes

            s3_key = upload_image_bytes(data, file.content_type or "image/jpeg")
        except Exception as e:
            result["s3_warning"] = str(e)

    if settings.database_url and s3_key:
        try:
            from api.db import insert_prediction

            top = result["predictions"][0]
            db_id = insert_prediction(
                s3_key=s3_key,
                predicted_class=result["top_prediction"],
                confidence=result["confidence"],
                display_name=top["display_name"],
                top3=result["predictions"],
            )
        except Exception as e:
            result["db_warning"] = str(e)

    result["s3_key"] = s3_key
    result["prediction_id"] = db_id
    return result

"""Nombres legibles en español para las 38 clases PlantVillage."""

from __future__ import annotations

DISPLAY_NAMES_ES: dict[str, str] = {
    "Apple___Apple_scab": "Manzana — Sarna",
    "Apple___Black_rot": "Manzana — Podredumbre negra",
    "Apple___Cedar_apple_rust": "Manzana — Roya del cedro",
    "Apple___healthy": "Manzana — Sano",
    "Blueberry___healthy": "Arándano — Sano",
    "Cherry_(including_sour)___Powdery_mildew": "Cereza — Oídio",
    "Cherry_(including_sour)___healthy": "Cereza — Sano",
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": "Maíz — Mancha foliar",
    "Corn_(maize)___Common_rust_": "Maíz — Roya común",
    "Corn_(maize)___Northern_Leaf_Blight": "Maíz — Tizón foliar del norte",
    "Corn_(maize)___healthy": "Maíz — Sano",
    "Grape___Black_rot": "Uva — Podredumbre negra",
    "Grape___Esca_(Black_Measles)": "Uva — Esca",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": "Uva — Mancha foliar",
    "Grape___healthy": "Uva — Sano",
    "Orange___Haunglongbing_(Citrus_greening)": "Naranja — Huanglongbing",
    "Peach___Bacterial_spot": "Durazno — Mancha bacteriana",
    "Peach___healthy": "Durazno — Sano",
    "Pepper,_bell___Bacterial_spot": "Pimiento — Mancha bacteriana",
    "Pepper,_bell___healthy": "Pimiento — Sano",
    "Potato___Early_blight": "Papa — Tizón temprano",
    "Potato___Late_blight": "Papa — Tizón tardío",
    "Potato___healthy": "Papa — Sano",
    "Raspberry___healthy": "Frambuesa — Sano",
    "Soybean___healthy": "Soja — Sano",
    "Squash___Powdery_mildew": "Calabaza — Oídio",
    "Strawberry___Leaf_scorch": "Fresa — Quemadura foliar",
    "Strawberry___healthy": "Fresa — Sano",
    "Tomato___Bacterial_spot": "Tomate — Mancha bacteriana",
    "Tomato___Early_blight": "Tomate — Tizón temprano",
    "Tomato___Late_blight": "Tomate — Tizón tardío",
    "Tomato___Leaf_Mold": "Tomate — Moho foliar",
    "Tomato___Septoria_leaf_spot": "Tomate — Septoria",
    "Tomato___Spider_mites Two-spotted_spider_mite": "Tomate — Ácaros",
    "Tomato___Target_Spot": "Tomate — Mancha anillada",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": "Tomate — Virus del rizado amarillo",
    "Tomato___Tomato_mosaic_virus": "Tomate — Virus del mosaico",
    "Tomato___healthy": "Tomate — Sano",
}


def display_name(class_id: str) -> str:
    return DISPLAY_NAMES_ES.get(
        class_id, class_id.replace("___", " — ").replace("_", " ")
    )

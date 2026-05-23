from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    model_path: str = Field(default="artifacts/resnet50.pt", validation_alias="MODEL_PATH")
    classes_path: str = Field(default="artifacts/clases.json", validation_alias="CLASSES_PATH")
    display_names_path: str = Field(
        default="artifacts/nombres_display.json", validation_alias="DISPLAY_NAMES_PATH"
    )

    aws_region: str = Field(default="us-east-1", validation_alias="AWS_REGION")
    s3_datalake_bucket: str = Field(default="", validation_alias="S3_DATALAKE_BUCKET")
    database_url: str = Field(default="", validation_alias="DATABASE_URL")

    cors_origins: str = "*"


settings = Settings()

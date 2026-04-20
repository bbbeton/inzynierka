from __future__ import annotations

from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "Flatground Backend"
    app_version: str = "0.2.0"
    environment: str = "development"

    data_dir: Path = Field(default_factory=lambda: Path(__file__).resolve().parent.parent / "data")
    upload_dir: Path = Field(default_factory=lambda: Path(__file__).resolve().parent.parent / "uploads")

    database_url: str | None = None
    cors_allowed_origins: str = "*"

    storage_provider: str = "local"  # local | supabase
    supabase_url: str | None = None
    supabase_service_key: str | None = None
    supabase_bucket: str = "spot-photos"

    max_upload_mb: int = 16
    create_spot_limit_per_minute: int = 20
    upload_photos_limit_per_minute: int = 12
    min_spot_distance_meters: float = 30.0

    profanity_words: str = "spam,scam,fake,idiot"

    @property
    def resolved_database_url(self) -> str:
        if self.database_url:
            return self.database_url
        self.data_dir.mkdir(parents=True, exist_ok=True)
        return f"sqlite:///{self.data_dir / 'app.db'}"

    @property
    def allowed_origins(self) -> list[str]:
        if self.cors_allowed_origins.strip() == "*":
            if self.environment.lower() == "production":
                raise ValueError(
                    "CORS_ALLOWED_ORIGINS cannot be '*' in production. "
                    "Set a comma-separated list of allowed HTTPS origins.",
                )
            return ["*"]
        return [item.strip() for item in self.cors_allowed_origins.split(",") if item.strip()]

    @property
    def forbidden_words(self) -> list[str]:
        return [item.strip().lower() for item in self.profanity_words.split(",") if item.strip()]


settings = Settings()

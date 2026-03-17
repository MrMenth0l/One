from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "One API"
    environment: str = "development"
    database_url: str = "sqlite+pysqlite:///./one.db"

    supabase_url: str | None = None
    supabase_anon_key: str | None = None
    supabase_service_role_key: str | None = None

    dev_auth_secret: str = Field(default="change-me-in-prod")
    access_token_ttl_seconds: int = 3600
    refresh_token_ttl_seconds: int = 60 * 60 * 24 * 30


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()

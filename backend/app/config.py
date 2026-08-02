"""
Application configuration loaded from environment variables.

All sensitive values (passwords, secrets) must be provided via the environment.
This module centralizes configuration to make migration and switching easier.
"""

from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Database
    database_url: str = "mysql+pymysql://root:password@localhost:3306/porten?charset=utf8mb4"

    # Security
    secret_key: str = "change-me"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 10080  # 7 days

    # SMTP
    smtp_host: str = "smtp.qq.com"
    smtp_port: int = 465
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_sender_name: str = "Porten"

    # Application
    default_avatar_url: str = "https://haowallpaper.com/link//common/file/previewFileImg/19197325717754752"
    app_name: str = "Porten"
    app_env: str = "development"

    @property
    def sender_address(self) -> str:
        return f"{self.smtp_sender_name} <{self.smtp_username}>"


@lru_cache()
def get_settings() -> Settings:
    """Return cached settings instance."""
    return Settings()

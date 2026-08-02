"""Media file tracking for uploaded images/videos/files."""

from datetime import datetime, timezone, timedelta
from typing import Optional

from sqlalchemy import BigInteger, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


MEDIA_TTL_DAYS = 14


class MediaFile(Base):
    """A media file uploaded for chat messages."""

    __tablename__ = "media_files"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    uploader_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        index=True,
        comment="User who uploaded the file",
    )
    message_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        nullable=True,
        index=True,
        comment="Associated message after sending",
    )
    file_path: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        comment="Relative or absolute path on disk",
    )
    file_type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        comment="image, video, file",
    )
    original_name: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="Original file name for file messages",
    )
    file_size: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
        comment="File size in bytes",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )
    expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc) + timedelta(days=MEDIA_TTL_DAYS),
        nullable=True,
        index=True,
        comment="NULL = permanent (e.g. group avatars), never auto-cleaned",
    )

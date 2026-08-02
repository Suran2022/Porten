"""Background cleanup task for expired media files."""

from __future__ import annotations

import asyncio
import logging
import os
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import MediaFile

logger = logging.getLogger(__name__)


async def cleanup_expired_media_task(interval_seconds: int = 3600) -> None:
    """Periodically delete media files whose expires_at has passed."""
    while True:
        try:
            await asyncio.sleep(interval_seconds)
            await _cleanup_once()
        except Exception as exc:
            logger.exception("media cleanup task failed: %s", exc)


async def _cleanup_once() -> None:
    db: Session = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        expired = db.query(MediaFile).filter(
            MediaFile.expires_at.isnot(None),
            MediaFile.expires_at <= now,
        ).all()
        for media in expired:
            try:
                if os.path.isfile(media.file_path):
                    os.remove(media.file_path)
            except OSError as exc:
                logger.warning("failed to remove file %s: %s", media.file_path, exc)
            db.delete(media)
        db.commit()
        if expired:
            logger.info("cleaned up %d expired media files", len(expired))
    finally:
        db.close()

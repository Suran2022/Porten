"""Security event model for the audit trail.

Privacy note: rows store metadata and features only (L1/L2 of the
three-layer data view); raw message content (L3) is never persisted
here. The ``detail`` column holds a short human-readable summary and
``meta`` holds structured, non-content evidence.
"""

from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy import BigInteger, ForeignKey, Index, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class SecurityEvent(Base):
    """A recorded security-relevant event."""

    __tablename__ = "security_events"

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True, index=True
    )
    event_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
        comment="Event identifier, e.g. malicious_url_blocked",
    )
    severity: Mapped[str] = mapped_column(
        String(20),
        default="info",
        nullable=False,
        comment="info | warning | critical",
    )
    user_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    detail: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="Short human-readable summary; must not contain raw content",
    )
    meta: Mapped[Optional[dict[str, Any]]] = mapped_column(
        JSON,
        nullable=True,
        comment="Structured non-content evidence for review",
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

    __table_args__ = (
        Index("ix_security_events_type_created", "event_type", "created_at"),
    )

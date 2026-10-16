"""Audit log model with hash chaining.

Every administrative and moderation action is recorded here. Each row
carries the hash of the previous row (``prev_hash``) plus its own
``entry_hash`` computed over canonical row content, forming a tamper-
evident chain (design doc §9 chain-of-custody layer): altering any row
breaks every subsequent hash.

Privacy note: rows store who/when/what-object/action only. Raw message
content and diary text are never persisted here.
"""

from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy import (
    BigInteger,
    ForeignKey,
    Index,
    JSON,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class AuditLog(Base):
    """A single audited action, chained to the previous entry."""

    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True, index=True
    )
    actor_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="Acting user (admin/moderator); NULL for system actors",
    )
    actor_role: Mapped[Optional[str]] = mapped_column(
        String(30),
        nullable=True,
        comment="Role snapshot at action time, e.g. moderator | admin",
    )
    action: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
        comment="Action identifier, e.g. content_recalled, user_frozen",
    )
    target_type: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        comment="Object kind the action targeted, e.g. message | user",
    )
    target_id: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
        comment="Object identifier (string to allow heterogeneous ids)",
    )
    summary: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="Short human-readable summary; must not contain raw content",
    )
    meta: Mapped[Optional[dict[str, Any]]] = mapped_column(
        JSON,
        nullable=True,
        comment="Structured action context (redacted, non-content)",
    )
    ip_hash: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
        comment="Salted hash of the actor IP (not reversible)",
    )
    prev_hash: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
        comment="entry_hash of the previous row in the chain; NULL for the first row",
    )
    entry_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        comment="SHA-256 over canonical row content including prev_hash",
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

    __table_args__ = (
        Index("ix_audit_logs_action_created", "action", "created_at"),
        Index("ix_audit_logs_actor_created", "actor_id", "created_at"),
        Index("ix_audit_logs_target", "target_type", "target_id"),
    )

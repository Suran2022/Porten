"""Moderation rule version model (admin-managed rule sets).

Rule sets are versioned and append-only: publishing a change creates a
new row with ``version = previous + 1`` for the same name, so the
admin surface can always show what was in force at any point (the
audit chain records who published each version).
"""

from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy import BigInteger, Boolean, ForeignKey, Index, Integer, JSON, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class ModerationRuleVersion(Base):
    """One published version of a named moderation rule set."""

    __tablename__ = "moderation_rule_versions"

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True, index=True
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="Rule set name, e.g. message_keywords",
    )
    version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="Monotonically increasing version per name",
    )
    patterns: Mapped[Optional[list[Any]]] = mapped_column(
        JSON,
        nullable=True,
        comment="Non-content rule data (patterns, thresholds, weights)",
    )
    enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_by: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

    __table_args__ = (
        UniqueConstraint("name", "version", name="uq_rule_name_version"),
        Index("ix_rule_name_latest", "name", "version"),
    )

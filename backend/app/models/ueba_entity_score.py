"""UEBA entity score model (aggregated risk scores, design doc §5.2).

Periodic aggregation rolls up per-entity risk signals (login anomalies,
privilege-escalation clustering, message bursts, reputation hits) into
a single score per time window. Scores feed the admin console triage
queue and automated response thresholds. Rows are append-only per
window; re-running aggregation for the same window is idempotent via
the unique constraint.
"""

from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy import (
    BigInteger,
    DateTime,
    Index,
    Integer,
    JSON,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class UebaEntityScore(Base):
    """An aggregated risk score for one entity over one time window."""

    __tablename__ = "ueba_entity_scores"

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True, index=True
    )
    entity_type: Mapped[str] = mapped_column(
        String(20),
        default="user",
        nullable=False,
        comment="user | ip | device",
    )
    entity_id: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        comment="Identifier of the scored entity",
    )
    window_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="Aggregation window start (inclusive)",
    )
    window_end: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="Aggregation window end (exclusive)",
    )
    score: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="Aggregated risk score, 0-100",
    )
    level: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        index=True,
        comment="low | medium | high | critical",
    )
    signals: Mapped[Optional[dict[str, Any]]] = mapped_column(
        JSON,
        nullable=True,
        comment="Per-signal contributions, e.g. {login_anomaly: 30, ...}",
    )
    top_reasons: Mapped[Optional[list[dict[str, Any]]]] = mapped_column(
        JSON,
        nullable=True,
        comment="Human-readable reason list (redacted, non-content)",
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

    __table_args__ = (
        UniqueConstraint(
            "entity_type",
            "entity_id",
            "window_start",
            name="uq_ueba_entity_window",
        ),
        Index("ix_ueba_entity_scores_entity", "entity_type", "entity_id"),
        Index("ix_ueba_entity_scores_level_created", "level", "created_at"),
    )

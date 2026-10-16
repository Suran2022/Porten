"""Approval ticket model (two-person / two-key rule, design doc §10.1).

A sensitive operation requires two hardware keys pressed in sequence:

1. the primary operator starts a ticket bound to the exact action,
   target and payload (one-shot);
2. a reviewer authorizes the same ticket with their own key within
   the validity window (default 5 minutes).

Only an approved-and-unexpired ticket may be consumed once by the
operation it was issued for; both authorizations are recorded for the
audit trail. The key carrier itself is abstracted (FIDO2/WebAuthn by
default, national-cipher USB key reserved).
"""

from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    Index,
    JSON,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base

APPROVAL_TTL_SECONDS = 300  # two-key authorization window: 5 minutes


class ApprovalTicket(Base):
    """A one-shot, time-boxed two-key authorization ticket."""

    __tablename__ = "approval_tickets"

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True, index=True
    )
    action: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Authorized action identifier, e.g. user_freeze, rule_rollback",
    )
    target_type: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        comment="Object kind the action targets, e.g. user | rule",
    )
    target_id: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
        comment="Object identifier the action targets",
    )
    request_payload: Mapped[Optional[dict[str, Any]]] = mapped_column(
        JSON,
        nullable=True,
        comment="Exact parameters snapshot the authorization is bound to",
    )
    primary_user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Operator who requested the action",
    )
    reviewer_user_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        comment="Second person who authorized the action",
    )
    status: Mapped[str] = mapped_column(
        String(20),
        default="pending",
        nullable=False,
        index=True,
        comment="pending | approved | rejected | expired | consumed | cancelled",
    )
    challenge_nonce: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        comment="Random nonce binding the two key ceremonies (anti-replay)",
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
        comment="Hard deadline for the second key (created + TTL)",
    )
    primary_credential_id: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="Key credential id used by the primary operator",
    )
    reviewer_credential_id: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="Key credential id used by the reviewer",
    )
    primary_authorized_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    reviewer_authorized_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    consumed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="When the approved ticket was spent by the operation",
    )
    decision_note: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="Optional reviewer note (rejection reason etc.)",
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

    __table_args__ = (
        Index("ix_approval_tickets_status_expires", "status", "expires_at"),
        Index("ix_approval_tickets_target", "target_type", "target_id"),
    )

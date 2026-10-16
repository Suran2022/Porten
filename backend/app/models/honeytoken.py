"""Honeytoken model (decoy credentials, design doc §5.5).

Honeytokens are fake credentials planted where an attacker would probe:
decoy admin sessions, decoy API keys, decoy password-reset links. Only
the token hash is stored; any presentation of a matching token is proof
of compromise and raises a critical event. Honeytokens are never valid
for any real operation.
"""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Honeytoken(Base):
    """A planted decoy credential used to detect probing/compromise."""

    __tablename__ = "honeytokens"

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True, index=True
    )
    token_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        unique=True,
        index=True,
        comment="SHA-256 of the decoy token (plaintext never stored)",
    )
    token_type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        comment="admin_session | api_key | reset_link",
    )
    label: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="Internal deployment label, e.g. decoy-admin-endpoint-1",
    )
    planted_by: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        comment="Operator who deployed this decoy",
    )
    hit_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
        comment="Number of times the token was presented",
    )
    last_hit_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    last_hit_ip_hash: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
        comment="Salted hash of the IP that last presented the token",
    )
    active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        comment="Whether the decoy is still deployed",
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

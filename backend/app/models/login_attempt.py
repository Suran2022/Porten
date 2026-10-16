"""Login attempt model (behavior analysis input).

Failed attempts have no user_id (the account may not exist); they are
keyed by email instead. IP addresses are stored as salted hashes so
grouping and anomaly detection work without keeping raw addresses in
the behavior tables.
"""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import BigInteger, Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class LoginAttempt(Base):
    """A single login attempt (successful or failed)."""

    __tablename__ = "login_attempts"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        nullable=True,
        index=True,
        comment="User id when the account exists",
    )
    email: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
        comment="Attempted account identifier (email, or Porten ID for ID logins)",
    )
    ip_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        comment="Salted hash of the client IP (not reversible)",
    )
    success: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    failure_reason: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        comment="bad_credentials | inactive | unknown_user | rate_limited",
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

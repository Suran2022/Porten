"""Device session model for token-device binding.

Each login may bind the issued token to a client-supplied stable
device identifier. The binding lets the platform revoke one device
without logging the account out everywhere, and lets anomaly
detection treat a new device as a signal.
"""

from datetime import datetime
from typing import Optional

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class DeviceSession(Base):
    """A device bound to a user's tokens."""

    __tablename__ = "device_sessions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Owner of the device session",
    )
    device_id: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        comment="Client-supplied stable device identifier",
    )
    device_name: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="Human-readable device label",
    )
    platform: Mapped[Optional[str]] = mapped_column(
        String(30),
        nullable=True,
        comment="ios | android | web | desktop",
    )
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Last authenticated use of this device",
    )
    revoked: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        comment="Whether the binding has been revoked",
    )

    __table_args__ = (
        UniqueConstraint("user_id", "device_id", name="uq_device_sessions_user_device"),
    )

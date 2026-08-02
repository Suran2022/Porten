"""System message model and per-user read state."""

from datetime import datetime
from enum import Enum as PyEnum
from typing import Optional

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class SystemMessageType(str, PyEnum):
    """System message category."""

    UPDATE = "update"
    FIX = "fix"


class SystemMessage(Base, TimestampMixin):
    """A system-wide announcement, e.g. version update or bug fix note."""

    __tablename__ = "system_messages"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    version: Mapped[str] = mapped_column(
        String(20),
        unique=True,
        nullable=False,
        index=True,
        comment="Version in v x.x.x format",
    )
    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Short title shown on the card",
    )
    content: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="Detailed update/fix content",
    )
    message_type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default=SystemMessageType.UPDATE.value,
        comment="update or fix",
    )
    is_custom_title: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        comment="Display title instead of version label",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        comment="Soft delete flag",
    )


class UserSystemMessageRead(Base, TimestampMixin):
    """Per-user read state for system messages."""

    __tablename__ = "user_system_message_reads"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    system_message_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("system_messages.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    is_read: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    read_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    __table_args__ = (
        Index(
            "ix_user_system_message_user_message",
            user_id,
            system_message_id,
            unique=True,
        ),
    )

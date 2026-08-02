"""Conversation model for friend and group chats."""

from enum import Enum as PyEnum
from typing import Optional

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, utc_now


class ConversationType(str, PyEnum):
    """Conversation type values."""

    FRIEND = "friend"
    GROUP = "group"


class Conversation(Base, TimestampMixin):
    """A conversation between friends or a group chat."""

    __tablename__ = "conversations"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        comment="friend or group",
    )
    user_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
        comment="For friend conversations: one participant id",
    )
    friend_user_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
        comment="For friend conversations: the other participant id",
    )
    group_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        ForeignKey("groups.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
        comment="For group conversations: the group id",
    )
    last_message_text: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
        comment="Preview text of the last message",
    )
    last_message_time: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=utc_now,
        comment="Timestamp of the last message",
    )
    last_message_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        nullable=True,
        comment="Optional id of the last message",
    )

    messages = relationship(
        "Message",
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="Message.created_at.asc()",
    )

    user: Mapped[Optional["User"]] = relationship(
        "User", foreign_keys=[user_id], lazy="selectin"
    )
    friend_user: Mapped[Optional["User"]] = relationship(
        "User", foreign_keys=[friend_user_id], lazy="selectin"
    )
    group: Mapped[Optional["Group"]] = relationship(
        "Group", foreign_keys=[group_id], lazy="selectin"
    )

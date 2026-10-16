"""Message model for conversation messages."""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.types import EncryptedText


class Message(Base):
    """A single message within a conversation."""

    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    conversation_id: Mapped[int] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sender_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    content: Mapped[str] = mapped_column(
        EncryptedText,
        nullable=False,
        comment="Message body; P0 field, encrypted at rest (design doc §5.4.2)",
    )
    extra: Mapped[Optional[dict]] = mapped_column(
        JSON,
        nullable=True,
        comment="Media/file metadata such as url, width, height, name, size",
    )
    message_type: Mapped[str] = mapped_column(
        String(20),
        default="text",
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    conversation = relationship("Conversation", back_populates="messages")
    sender = relationship("User", backref="messages")

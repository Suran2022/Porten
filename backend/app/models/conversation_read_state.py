"""Conversation read state model."""

from sqlalchemy import BigInteger, Column, ForeignKey, Integer, UniqueConstraint

from app.models.base import Base


class ConversationReadState(Base):
    """Tracks per-user read position for a conversation."""

    __tablename__ = "conversation_read_states"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    conversation_id = Column(
        BigInteger,
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    last_read_message_id = Column(BigInteger, nullable=True)

    __table_args__ = (
        UniqueConstraint("user_id", "conversation_id", name="uq_read_state"),
    )

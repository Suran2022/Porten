"""Contact (friend) related models."""

from enum import Enum as PyEnum
from typing import Optional

from sqlalchemy import BigInteger, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class FriendRequestStatus(str, PyEnum):
    """Friend request status values."""

    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class Friendship(Base, TimestampMixin):
    """Bi-directional friendship relationship between two users."""

    __tablename__ = "friendships"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    friend_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    __table_args__ = (
        UniqueConstraint("user_id", "friend_id", name="uq_friendships_user_friend"),
    )

    user: Mapped["User"] = relationship("User", foreign_keys=[user_id], lazy="selectin")
    friend: Mapped["User"] = relationship(
        "User", foreign_keys=[friend_id], lazy="selectin"
    )


class FriendRequest(Base, TimestampMixin):
    """Friend request sent from one user to another."""

    __tablename__ = "friend_requests"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    sender_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    receiver_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    message: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="Optional message accompanying the request",
    )
    status: Mapped[str] = mapped_column(
        String(20),
        default=FriendRequestStatus.PENDING.value,
        nullable=False,
        comment="pending, accepted, or rejected",
    )
    source: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="Source of the friend request",
    )
    viewed: Mapped[bool] = mapped_column(
        default=False,
        nullable=False,
        comment="Whether the receiver has viewed this request",
    )

    sender: Mapped["User"] = relationship(
        "User", foreign_keys=[sender_id], lazy="selectin"
    )
    receiver: Mapped["User"] = relationship(
        "User", foreign_keys=[receiver_id], lazy="selectin"
    )

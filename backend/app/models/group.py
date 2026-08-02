"""Group (camp) related models."""

from enum import Enum as PyEnum
from typing import Optional

from sqlalchemy import BigInteger, Boolean, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class GroupMemberRole(str, PyEnum):
    """Roles a member can have within a group."""

    OWNER = "owner"
    ADMIN = "admin"
    MEMBER = "member"


class GroupRequestType(str, PyEnum):
    """Type of group membership request."""

    APPLY = "apply"
    INVITE = "invite"


class GroupRequestStatus(str, PyEnum):
    """Status of a group membership request."""

    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class Group(Base, TimestampMixin):
    """A group/camp that users can join and converse in."""

    __tablename__ = "groups"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    owner_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True,
        comment="Group display name",
    )
    avatar_url: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
        comment="Group avatar image URL or base64 data URI",
    )
    member_count: Mapped[int] = mapped_column(
        BigInteger,
        default=0,
        nullable=False,
        comment="Cached member count",
    )
    tags: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="Comma-separated or JSON tags for the group",
    )
    group_type: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        comment="Group category/type",
    )
    camp_id: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        unique=True,
        index=True,
        comment="Unique camp identifier, e.g. yd123456789",
    )
    searchable_by_name: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        comment="Whether the group appears in name search",
    )
    description: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
        comment="Group description",
    )
    discoverable_by: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        comment="How the group can be discovered: name, id, none",
    )
    max_members: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        nullable=True,
        comment="Maximum member limit for the camp",
    )

    owner: Mapped["User"] = relationship("User", foreign_keys=[owner_id], lazy="selectin")


class GroupMember(Base, TimestampMixin):
    """Membership of a user in a group."""

    __tablename__ = "group_members"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    group_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("groups.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(
        String(20),
        default=GroupMemberRole.MEMBER.value,
        nullable=False,
        comment="owner, admin, or member",
    )

    __table_args__ = (
        UniqueConstraint("group_id", "user_id", name="uq_group_members_group_user"),
    )

    group: Mapped["Group"] = relationship("Group", foreign_keys=[group_id], lazy="selectin")
    user: Mapped["User"] = relationship("User", foreign_keys=[user_id], lazy="selectin")


class GroupRequest(Base, TimestampMixin):
    """Request to join or invitation to a group."""

    __tablename__ = "group_requests"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    group_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("groups.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="User who applied or was invited",
    )
    inviter_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="User who sent the invitation, null for applications",
    )
    type: Mapped[str] = mapped_column(
        String(20),
        default=GroupRequestType.APPLY.value,
        nullable=False,
        comment="apply or invite",
    )
    message: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="Optional message accompanying the request",
    )
    status: Mapped[str] = mapped_column(
        String(20),
        default=GroupRequestStatus.PENDING.value,
        nullable=False,
        comment="pending, accepted, or rejected",
    )
    viewed: Mapped[bool] = mapped_column(
        default=False,
        nullable=False,
        comment="Whether an admin/owner has viewed this request",
    )

    group: Mapped["Group"] = relationship("Group", foreign_keys=[group_id], lazy="selectin")
    user: Mapped["User"] = relationship("User", foreign_keys=[user_id], lazy="selectin")
    inviter: Mapped[Optional["User"]] = relationship(
        "User", foreign_keys=[inviter_id], lazy="selectin"
    )

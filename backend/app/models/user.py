"""User model."""

from enum import Enum as PyEnum
from typing import Optional

from sqlalchemy import BigInteger, Boolean, Integer, String
from sqlalchemy.dialects.mysql import LONGTEXT
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class UserRole(str, PyEnum):
    """User roles for shared user/admin data access."""

    USER = "user"
    ADMIN = "admin"


class Gender(str, PyEnum):
    """Supported gender identity options."""

    CIS_FEMALE = "cis_female"
    CIS_MALE = "cis_male"
    TRANS_FEMALE = "trans_female"
    TRANS_MALE = "trans_male"
    NON_BINARY = "non_binary"
    GENDERQUEER = "genderqueer"
    GENDERFLUID = "genderfluid"
    AGENDER = "agender"
    BIGENDER = "bigender"
    PANGENDER = "pangender"
    QUESTIONING = "questioning"
    INTERSEX = "intersex"
    PREFER_NOT_TO_SAY = "prefer_not_to_say"
    OTHER = "other"


#: Values considered cisgender; all other non-null genders count as transgender
#: for the purpose of trans-days calculation.
CIS_GENDERS = {Gender.CIS_FEMALE.value, Gender.CIS_MALE.value}


class User(Base, TimestampMixin):
    """A registered user."""

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        index=True,
        comment="User login email",
    )
    password_hash: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="Bcrypt password hash",
    )
    porten_id: Mapped[str] = mapped_column(
        String(12),
        unique=True,
        nullable=False,
        index=True,
        comment="Public Porten account number, 6-12 digits without 4",
    )
    nickname: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Display name, defaults to porten_id",
    )
    avatar_url: Mapped[Optional[str]] = mapped_column(
        LONGTEXT,
        nullable=True,
        comment="Avatar image URL or base64 data URI",
    )
    background_url: Mapped[Optional[str]] = mapped_column(
        LONGTEXT,
        nullable=True,
        comment="Profile background image URL or base64 data URI",
    )
    role: Mapped[str] = mapped_column(
        String(20),
        default=UserRole.USER.value,
        nullable=False,
        comment="user or admin; admin can access user data",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        comment="Soft delete flag",
    )
    email_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        comment="Whether the email has been verified",
    )
    gender: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        comment="User gender identity",
    )
    latest_diary: Mapped[Optional[str]] = mapped_column(
        LONGTEXT,
        nullable=True,
        comment="Cached content of the user's current emotion diary entry",
    )
    mood: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="Cached mood tag of the user's current emotion diary entry",
    )
    token_version: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
        comment="Token version; incremented on logout to invalidate tokens",
    )

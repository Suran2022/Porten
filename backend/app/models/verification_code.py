"""Email verification code model."""

from sqlalchemy import BigInteger, Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, utc_now


class VerificationCode(Base, TimestampMixin):
    """Stores email verification codes for register/login/reset flows."""

    __tablename__ = "verification_codes"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
        comment="Target email address",
    )
    code: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        comment="Verification code",
    )
    purpose: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
        comment="Purpose: register, login, reset_password",
    )
    expires_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="Code expiration time",
    )
    used: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        comment="Whether the code has been consumed",
    )

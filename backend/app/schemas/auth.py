"""Authentication related schemas."""

from typing import Optional

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.utils.validators import validate_password


class LogoutRequest(BaseModel):
    """Logout request; device_id revokes just that device."""

    device_id: Optional[str] = Field(default=None, max_length=64)


class SendVerificationCodeRequest(BaseModel):
    """Request to send an email verification code."""
    email: EmailStr
    purpose: str = Field(
        default="register",
        pattern="^(register|login|reset_password|change_email_old|change_email_new)$",
    )


class RegisterRequest(BaseModel):
    """User registration request."""

    email: EmailStr
    password: str = Field(..., min_length=8, max_length=128)
    confirm_password: str = Field(..., min_length=8, max_length=128)
    verification_code: str = Field(..., min_length=6, max_length=10)
    # Optional device binding fields; omitting them keeps tokens
    # device-unbound (backward compatible).
    device_id: Optional[str] = Field(
        default=None, max_length=64, description="Stable client device id"
    )
    device_name: Optional[str] = Field(default=None, max_length=100)
    platform: Optional[str] = Field(
        default=None, max_length=30, pattern="^(ios|android|web|desktop)?$"
    )


    @field_validator("password")
    @classmethod
    def password_strength(cls, value: str) -> str:
        validate_password(value)
        return value

    @field_validator("confirm_password")
    @classmethod
    def passwords_match(cls, value: str, info) -> str:
        if value != info.data.get("password"):
            raise ValueError("passwords do not match")
        return value


class EmailPasswordLoginRequest(BaseModel):
    """Login with email and password."""

    email: EmailStr
    password: str = Field(..., min_length=1, max_length=128)
    # Optional device binding fields; omitting them keeps tokens
    # device-unbound (backward compatible).
    device_id: Optional[str] = Field(
        default=None, max_length=64, description="Stable client device id"
    )
    device_name: Optional[str] = Field(default=None, max_length=100)
    platform: Optional[str] = Field(
        default=None, max_length=30, pattern="^(ios|android|web|desktop)?$"
    )



class EmailCodeLoginRequest(BaseModel):
    """Login with email verification code."""

    email: EmailStr
    verification_code: str = Field(..., min_length=6, max_length=10)
    # Optional device binding fields; omitting them keeps tokens
    # device-unbound (backward compatible).
    device_id: Optional[str] = Field(
        default=None, max_length=64, description="Stable client device id"
    )
    device_name: Optional[str] = Field(default=None, max_length=100)
    platform: Optional[str] = Field(
        default=None, max_length=30, pattern="^(ios|android|web|desktop)?$"
    )



class PortenIdLoginRequest(BaseModel):
    """Login with Porten ID and password."""

    porten_id: str = Field(..., min_length=6, max_length=12, pattern="^[0-9]+$")
    password: str = Field(..., min_length=1, max_length=128)
    # Optional device binding fields; omitting them keeps tokens
    # device-unbound (backward compatible).
    device_id: Optional[str] = Field(
        default=None, max_length=64, description="Stable client device id"
    )
    device_name: Optional[str] = Field(default=None, max_length=100)
    platform: Optional[str] = Field(
        default=None, max_length=30, pattern="^(ios|android|web|desktop)?$"
    )



class TokenResponse(BaseModel):
    """Login token response."""

    access_token: str
    token_type: str = "bearer"
    expires_in: int


class LoginResponse(BaseModel):
    """Login response containing token and basic user info."""

    token: TokenResponse
    user: "UserBriefResponse"


class UserBriefResponse(BaseModel):
    """Minimal public user info returned after login."""

    id: int
    email: str
    porten_id: str
    nickname: str
    avatar_url: Optional[str]
    background_url: Optional[str]
    role: str

    class Config:
        from_attributes = True


class DefaultAvatarResponse(BaseModel):
    """Default avatar URL response."""

    avatar_url: str


class DefaultNicknameResponse(BaseModel):
    """Default nickname response."""

    nickname: str


# Resolve forward references
LoginResponse.model_rebuild()

"""User related schemas."""

from typing import Literal, Optional

from pydantic import BaseModel, EmailStr, Field

GenderValue = Literal[
    "cis_female",
    "cis_male",
    "trans_female",
    "trans_male",
    "non_binary",
    "genderqueer",
    "genderfluid",
    "agender",
    "bigender",
    "pangender",
    "questioning",
    "intersex",
    "prefer_not_to_say",
    "other",
]


class UserProfileResponse(BaseModel):
    """Current user profile response."""

    id: int
    email: str
    porten_id: str
    nickname: str
    avatar_url: Optional[str]
    background_url: Optional[str]
    role: str
    gender: Optional[str] = None
    friend_count: int = 0
    trans_days: int = 0
    latest_diary: Optional[str] = None
    mood: Optional[str] = None

    class Config:
        from_attributes = True


class UpdateNicknameRequest(BaseModel):
    """Request to update user nickname."""

    nickname: str = Field(..., min_length=1, max_length=50)


class UpdateAvatarRequest(BaseModel):
    """Request to update user avatar."""

    avatar_url: str = Field(..., min_length=1)


class UpdateBackgroundRequest(BaseModel):
    """Request to update user profile background."""

    background_url: str = Field(..., min_length=1)


class UpdateProfileRequest(BaseModel):
    """Request to update multiple profile fields."""

    nickname: Optional[str] = Field(None, min_length=1, max_length=50)
    avatar_url: Optional[str] = Field(None, min_length=1)
    background_url: Optional[str] = Field(None, min_length=1)
    gender: Optional[GenderValue] = None


class ChangeEmailRequest(BaseModel):
    """Request to change the user's bound email."""

    new_email: EmailStr
    old_code: str = Field(..., min_length=6, max_length=10)
    new_code: str = Field(..., min_length=6, max_length=10)

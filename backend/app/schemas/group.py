"""Group/camp related schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


def _split_tags(value: object) -> list[str]:
    """Split a comma-separated tag string into a list."""
    if isinstance(value, str):
        return [tag.strip() for tag in value.split(",") if tag.strip()]
    return value or []


class SearchGroupResponse(BaseModel):
    """Group search result returned by name or camp id partial match."""

    id: int
    name: str
    avatar_url: Optional[str]
    member_count: int
    tags: list[str] = []
    group_type: Optional[str]
    searchable_by_name: bool
    camp_id: Optional[str]
    description: Optional[str]
    discoverable_by: Optional[str]
    max_members: Optional[int]

    @field_validator("tags", mode="before")
    @classmethod
    def split_tags(cls, value: object) -> list[str]:
        return _split_tags(value)

    class Config:
        from_attributes = True


class CreateGroupRequest(BaseModel):
    """Request to create a new camp/group."""

    name: str = Field(..., min_length=1, max_length=30)
    group_type: str = Field(..., min_length=1, max_length=50)
    description: Optional[str] = Field(None, max_length=500)
    avatar_url: Optional[str] = Field(None, max_length=500)
    tags: list[str] = Field(default_factory=list, max_length=5)
    discoverable_by: Optional[str] = Field(None, max_length=50)
    max_members: Optional[int] = Field(None, gt=0)


class CreateGroupResponse(BaseModel):
    """Response after creating a new camp/group."""

    id: int
    name: str
    avatar_url: Optional[str]
    member_count: int
    group_type: Optional[str]
    conversation_id: int
    camp_id: Optional[str]

    class Config:
        from_attributes = True


class UpdateGroupRequest(BaseModel):
    """Request to update an existing camp/group profile."""

    name: Optional[str] = Field(None, min_length=1, max_length=30)
    description: Optional[str] = Field(None, max_length=500)
    avatar_url: Optional[str] = Field(None, max_length=500)
    tags: Optional[list[str]] = Field(None, max_length=5)
    discoverable_by: Optional[str] = Field(None, max_length=50)
    max_members: Optional[int] = Field(None, gt=0)


class GroupProfileResponse(BaseModel):
    """Full camp/group profile response."""

    id: int
    name: str
    avatar_url: Optional[str]
    member_count: int
    tags: list[str] = []
    group_type: Optional[str]
    searchable_by_name: bool
    camp_id: Optional[str]
    description: Optional[str]
    discoverable_by: Optional[str]
    max_members: Optional[int]

    @field_validator("tags", mode="before")
    @classmethod
    def split_tags(cls, value: object) -> list[str]:
        return _split_tags(value)

    class Config:
        from_attributes = True


class SendGroupRequestRequest(BaseModel):
    """Request to apply to join a group."""

    group_id: int = Field(..., gt=0)
    message: Optional[str] = Field(None, max_length=255)


class GroupRequestResponse(BaseModel):
    """Group membership request response."""

    id: int
    group_id: int
    group_name: str
    group_avatar_url: Optional[str]
    user_id: int
    user_nickname: str
    user_avatar_url: Optional[str]
    message: Optional[str]
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


class GroupMemberResponse(BaseModel):
    """Group member response."""

    id: int
    user_id: int
    nickname: str
    avatar_url: Optional[str]
    role: str
    created_at: datetime

    class Config:
        from_attributes = True


class ContactGroupResponse(BaseModel):
    """A group entry in the contact list."""

    id: int
    group_id: int
    name: str
    avatar_url: Optional[str]
    role: str
    created_at: datetime

    class Config:
        from_attributes = True

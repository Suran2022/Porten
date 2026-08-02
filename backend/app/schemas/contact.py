"""Contact/friend related schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.schemas.group import ContactGroupResponse


class SearchUserResponse(BaseModel):
    """User search result returned by Porten ID exact match."""

    id: int
    porten_id: str
    nickname: str
    avatar_url: Optional[str]

    class Config:
        from_attributes = True


class SendFriendRequestRequest(BaseModel):
    """Request to send a friend request."""

    receiver_porten_id: str = Field(..., min_length=1)
    message: Optional[str] = Field(None, max_length=255)


class HandleRequestRequest(BaseModel):
    """Request to accept or reject a friend/group request."""

    action: str = Field(..., pattern="^(accept|reject)$")


class FriendRequestResponse(BaseModel):
    """Friend request response."""

    id: int
    sender_id: int
    receiver_id: int
    sender_nickname: str
    sender_avatar_url: Optional[str]
    message: Optional[str]
    status: str
    source: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class ContactFriendResponse(BaseModel):
    """A friend entry in the contact list."""

    id: int
    user_id: int
    nickname: str
    avatar_url: Optional[str]
    created_at: datetime


class ContactListResponse(BaseModel):
    """Contact list containing friends and groups."""

    friends: list[ContactFriendResponse]
    groups: list["ContactGroupResponse"]

"""Notification related schemas."""

from pydantic import BaseModel, Field


class BadgeResponse(BaseModel):
    """Notification badge counts."""

    friend_requests: int
    group_requests: int


class ReadNotificationRequest(BaseModel):
    """Request to mark notifications of a type as read."""

    type: str = Field(..., pattern="^(friend|group)$")

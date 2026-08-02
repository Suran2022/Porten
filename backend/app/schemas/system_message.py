"""System message schemas."""

from datetime import datetime

from pydantic import BaseModel


class SystemMessageItem(BaseModel):
    """A system message as shown to the user."""

    id: int
    version: str
    title: str
    content: str
    message_type: str
    is_custom_title: bool
    is_read: bool
    created_at: datetime


class SystemMessageListResponse(BaseModel):
    """List of system messages."""

    messages: list[SystemMessageItem]
    unread_count: int


class SystemMessageUnreadResponse(BaseModel):
    """Unread system message count."""

    unread_count: int

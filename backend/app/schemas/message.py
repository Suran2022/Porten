"""Message schemas."""

from datetime import datetime
from typing import Any, Dict, Optional

from pydantic import BaseModel, ConfigDict, Field


class MessageResponse(BaseModel):
    """Message response schema."""

    id: int
    conversation_id: int
    sender_id: Optional[int]
    sender_nickname: Optional[str]
    sender_avatar_url: Optional[str]
    content: str
    extra: Optional[Dict[str, Any]] = None
    message_type: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class MessageCreate(BaseModel):
    """Request schema for sending a message."""

    conversation_id: int
    message_type: str = Field(..., pattern="^(text|image|video|file|voice|system)$")
    content: str = ""
    extra: Optional[Dict[str, Any]] = None
    media_file_id: Optional[int] = None

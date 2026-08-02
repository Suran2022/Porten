"""Conversation related schemas."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class ConversationResponse(BaseModel):
    """Conversation list item."""

    id: int
    type: str
    name: str
    avatar: Optional[str]
    last_message: Optional[str]
    last_message_time: Optional[datetime]
    last_message_sender_id: Optional[int] = None
    last_message_sender_name: Optional[str] = None
    unread_count: int = 0
    member_count: Optional[int] = None
    # 好友会话对方的用户 id（同胞资料页"传达消息"据此定位会话）
    friend_user_id: Optional[int] = None

    class Config:
        from_attributes = True


class ConversationListResponse(BaseModel):
    """Wrapper for a list of conversations."""

    conversations: list[ConversationResponse]

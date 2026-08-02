"""Assistant (Porten 伙伴) schemas."""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class PortenAssistantItem(BaseModel):
    """A Porten assistant (e.g. 情小绪) shown on the partner list page."""

    id: str = Field(..., description="Assistant id, e.g. qin_xiaoxu")
    name: str
    avatar: Optional[str] = Field(None, description="Image URL; null = use text placeholder")
    bio: Optional[str] = None
    article_count: int = Field(0, description="Total active articles for this assistant")
    unread_count: int = Field(0, description="Unread articles for current user")


class PortenAssistantListResponse(BaseModel):
    """List of Porten assistants."""

    assistants: List[PortenAssistantItem]


class AssistantArticleListItem(BaseModel):
    """Article metadata for the assistant's article list."""

    id: int
    assistant_id: str
    title: str
    summary: str
    publish_time: datetime
    publisher: str
    is_read: bool = False


class AssistantArticleListResponse(BaseModel):
    """List of articles for an assistant."""

    assistant_id: str
    articles: List[AssistantArticleListItem]
    unread_count: int


class AssistantArticleDetail(BaseModel):
    """Full article (metadata + markdown body) for rendering."""

    id: int
    assistant_id: str
    title: str
    summary: str
    content: str = Field(..., description="Raw markdown body, rendered by the client")
    publish_time: datetime
    publisher: str
    is_read: bool = False

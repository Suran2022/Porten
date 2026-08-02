"""Emotion diary Pydantic schemas."""

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field

from app.models.emotion_diary import MOOD_LABELS


class EmotionDiaryCreateRequest(BaseModel):
    """Request body for creating a new diary entry."""

    content: str = Field(..., min_length=1, max_length=4000)
    mood: str = Field(..., min_length=1, max_length=20)
    is_public: bool = True


class EmotionDiaryAuthorBrief(BaseModel):
    """Brief author info embedded in diary responses."""

    id: int
    nickname: str
    avatar_url: Optional[str] = None
    porten_id: str


class EmotionDiaryResponse(BaseModel):
    """Single diary entry response."""

    id: int
    content: str
    mood: str
    mood_label: str
    is_public: bool
    is_current: bool
    view_count: int
    created_at: datetime
    updated_at: datetime
    author: EmotionDiaryAuthorBrief
    is_mine: bool = False


class EmotionDiaryListResponse(BaseModel):
    """Paginated list of diary entries."""

    items: List[EmotionDiaryResponse]
    total: int


class EmotionDiaryViewerItem(BaseModel):
    """A single viewer record (avatar on top, nickname on bottom layout)."""

    id: int
    user_id: int
    nickname: str
    avatar_url: Optional[str] = None
    porten_id: str
    viewed_at: datetime


class EmotionDiaryViewerListResponse(BaseModel):
    """Response for a diary's viewer list."""

    items: List[EmotionDiaryViewerItem]
    total: int


def resolve_mood_label(mood: str) -> str:
    """Resolve a mood enum value to its Chinese label."""
    return MOOD_LABELS.get(mood, mood)

"""Note related schemas.

Field names mirror the mock model (frontend NoteItem) exactly:
one field neither more nor less. ``time`` is the display string
(``今天 HH:mm`` / ``昨天 HH:mm`` / ``M月D日 HH:mm``).
"""

from typing import List, Optional

from pydantic import BaseModel, Field


class NoteCreate(BaseModel):
    """Request to create a note; empty tags fall back to ['随记']."""

    content: str = Field(..., min_length=1, max_length=2000)
    tags: List[str] = Field(default_factory=list)


class NoteUpdate(BaseModel):
    """Request to update a note; provided fields are overwritten."""

    content: Optional[str] = Field(None, min_length=1, max_length=2000)
    tags: Optional[List[str]] = None
    archived: Optional[bool] = None


class NoteResponse(BaseModel):
    """Note response; identical to the mock model fields."""

    id: int
    content: str
    time: str
    tags: List[str]
    archived: bool

    class Config:
        from_attributes = True


class NoteListResponse(BaseModel):
    """Note list response."""

    items: List[NoteResponse]

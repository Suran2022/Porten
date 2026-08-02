"""Search related schemas (global search across users / camps / files / knowledge / images)."""

from datetime import datetime
from typing import Any, List, Optional, Union

from pydantic import BaseModel, field_validator


def _split_tags(value: Any) -> list[str]:
    """Split a comma-separated tag string (or None / list) into a list."""
    if value is None:
        return []
    if isinstance(value, str):
        return [tag.strip() for tag in value.split(",") if tag.strip()]
    if isinstance(value, list):
        return [str(t).strip() for t in value if str(t).strip()]
    return []


class SearchComradeItem(BaseModel):
    """A user / comrade in search results."""

    id: int
    porten_id: str
    nickname: str
    avatar_url: Optional[str] = None

    class Config:
        from_attributes = True


class SearchCampItem(BaseModel):
    """A camp / group in search results."""

    id: int
    name: str
    avatar_url: Optional[str] = None
    member_count: int = 0
    tags: List[str] = []
    group_type: Optional[str] = None
    camp_id: Optional[str] = None
    description: Optional[str] = None

    @field_validator("tags", mode="before")
    @classmethod
    def split_tags(cls, value: Any) -> list[str]:
        return _split_tags(value)

    class Config:
        from_attributes = True


class SearchFileItem(BaseModel):
    """A file (non-image) media in search results."""

    id: int
    name: str
    url: str
    size: Optional[int] = None
    uploader_id: Optional[int] = None
    uploader_nickname: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SearchImageItem(BaseModel):
    """An image media in search results."""

    id: int
    name: str
    url: str
    size: Optional[int] = None
    uploader_id: Optional[int] = None
    uploader_nickname: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SearchKnowledgeItem(BaseModel):
    """A knowledge (article / video / share) item in search results."""

    id: str
    kind: str  # article | video | share
    title: str
    summary: Optional[str] = None
    cover_url: Optional[str] = None
    author_id: Optional[str] = None
    author_nickname: Optional[str] = None
    author_avatar: Optional[str] = None


class SearchAllResponse(BaseModel):
    """Aggregated results for the "全部" view.

    Items are always returned in a fixed order:
    同胞 → 营地 → 文件 → 知识 → 图片
    """

    query: str
    comrade: list[SearchComradeItem] = []
    camp: list[SearchCampItem] = []
    file: list[SearchFileItem] = []
    knowledge: list[SearchKnowledgeItem] = []
    image: list[SearchImageItem] = []


class SearchCategoryResponse(BaseModel):
    """Results for a single search category."""

    query: str
    items: list[
        Union[
            SearchComradeItem,
            SearchCampItem,
            SearchFileItem,
            SearchKnowledgeItem,
            SearchImageItem,
        ]
    ] = []

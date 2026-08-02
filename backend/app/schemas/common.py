"""Common response schemas."""

from typing import Any, Generic, Optional, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class ResponseModel(BaseModel, Generic[T]):
    """Unified API response wrapper."""

    code: int = 0
    message: str = "success"
    data: Optional[T] = None


class PaginationParams(BaseModel):
    """Standard pagination parameters."""

    page: int = 1
    page_size: int = 20


class PaginationMeta(BaseModel):
    """Pagination metadata."""

    page: int
    page_size: int
    total: int
    total_pages: int


class PaginatedResponse(BaseModel, Generic[T]):
    """Paginated list response."""

    items: list[T]
    meta: PaginationMeta

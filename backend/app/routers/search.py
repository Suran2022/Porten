"""Global search router (同胞 / 营地 / 文件 / 知识 / 图片)."""

from typing import Optional, Union

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.common import ResponseModel
from app.schemas.search import (
    SearchAllResponse,
    SearchCategoryResponse,
)
from app.services.search_service import (
    ALL_SEARCH_TYPES,
    SEARCH_TYPE_ALL,
    search_service,
)

router = APIRouter(prefix="/api/v1/search", tags=["search"])


def _safe_limit(value: Optional[int]) -> int:
    if value is None or value <= 0:
        return search_service.DEFAULT_LIMIT
    return min(value, 50)


@router.get("", response_model=ResponseModel[Union[SearchAllResponse, SearchCategoryResponse]])
def global_search(
    q: str = Query("", description="Search keyword"),
    type: str = Query(SEARCH_TYPE_ALL, description=f"Search type, one of: all, {', '.join(ALL_SEARCH_TYPES)}"),
    limit: Optional[int] = Query(None, description="Maximum number of items per category"),
    db: Session = Depends(get_db),
):
    """Unified search endpoint.

    - `type=all` (default) → returns SearchAllResponse with five fixed-order
      fields: `comrade` → `camp` → `file` → `knowledge` → `image`.
    - `type=<single>` → returns SearchCategoryResponse with a single `items` list.
    """
    limit = _safe_limit(limit)

    if type == SEARCH_TYPE_ALL:
        aggregated = search_service.search(db, query=q, search_type=SEARCH_TYPE_ALL, limit=limit)
        data = SearchAllResponse(
            query=q,
            comrade=aggregated["comrade"],
            camp=aggregated["camp"],
            file=aggregated["file"],
            knowledge=aggregated["knowledge"],
            image=aggregated["image"],
        )
        return ResponseModel(data=data)

    if type not in ALL_SEARCH_TYPES:
        return ResponseModel(code=400, message=f"invalid type: {type}", data=None)

    items = search_service.search(db, query=q, search_type=type, limit=limit)
    return ResponseModel(data=SearchCategoryResponse(query=q, items=items))

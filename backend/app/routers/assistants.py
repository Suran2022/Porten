"""Assistant / article router.

- GET    /api/v1/assistants                                助手列表（含文章数 / 未读数）
- GET    /api/v1/assistants/{assistant_id}/articles         助手下的文章列表
- GET    /api/v1/assistants/{assistant_id}/articles/{id}    文章详情（含 markdown 正文）
- POST   /api/v1/assistants/{assistant_id}/articles/{id}/read  标记已读
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas.assistant import (
    AssistantArticleDetail,
    AssistantArticleListResponse,
    PortenAssistantListResponse,
)
from app.schemas.common import ResponseModel
from app.services import AssistantArticleService
from app.services.assistant_article_service import ASSISTANTS

router = APIRouter(prefix="/api/v1/assistants", tags=["assistants"])
assistant_article_service = AssistantArticleService()


@router.get(
    "",
    response_model=ResponseModel[PortenAssistantListResponse],
    status_code=status.HTTP_200_OK,
)
def list_assistants(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return all Porten assistants with article + unread stats."""
    assistants = assistant_article_service.list_assistants(db, current_user.id)
    return ResponseModel(
        data=PortenAssistantListResponse(assistants=assistants)
    )


@router.get(
    "/{assistant_id}/articles",
    response_model=ResponseModel[AssistantArticleListResponse],
    status_code=status.HTTP_200_OK,
)
def list_assistant_articles(
    assistant_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the list of active articles for an assistant."""
    if not any(a.id == assistant_id for a in ASSISTANTS):
        raise HTTPException(status_code=404, detail="assistant not found")
    data = assistant_article_service.list_articles(
        db, current_user.id, assistant_id
    )
    return ResponseModel(data=AssistantArticleListResponse(**data))


@router.get(
    "/{assistant_id}/articles/{article_id}",
    response_model=ResponseModel[AssistantArticleDetail],
    status_code=status.HTTP_200_OK,
)
def get_assistant_article(
    assistant_id: str,
    article_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return a single article (with markdown body) and auto-mark it read."""
    if not any(a.id == assistant_id for a in ASSISTANTS):
        raise HTTPException(status_code=404, detail="assistant not found")
    data = assistant_article_service.get_article(
        db, current_user.id, assistant_id, article_id
    )
    if not data:
        raise HTTPException(status_code=404, detail="article not found")
    return ResponseModel(data=AssistantArticleDetail(**data))


@router.post(
    "/{assistant_id}/articles/{article_id}/read",
    response_model=ResponseModel[dict],
    status_code=status.HTTP_200_OK,
)
def mark_article_read(
    assistant_id: str,
    article_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mark an article as read for the current user."""
    ok = assistant_article_service.mark_article_read(
        db, current_user.id, article_id
    )
    if not ok:
        raise HTTPException(status_code=404, detail="article not found")
    return ResponseModel(data={"marked": True})

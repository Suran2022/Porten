"""Emotion diary routers."""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import EmotionDiary, EmotionDiaryView, User
from app.schemas.common import ResponseModel
from app.schemas.emotion_diary import (
    EmotionDiaryAuthorBrief,
    EmotionDiaryCreateRequest,
    EmotionDiaryListResponse,
    EmotionDiaryResponse,
    EmotionDiaryViewerItem,
    EmotionDiaryViewerListResponse,
    resolve_mood_label,
)
from app.services import EmotionDiaryService

router = APIRouter(
    prefix="/api/v1/emotion-diaries", tags=["emotion-diaries"]
)
service = EmotionDiaryService()


def _build_diary_response(
    diary: EmotionDiary,
    current_user_id: int,
    view_count: Optional[int] = None,
) -> EmotionDiaryResponse:
    if view_count is None:
        view_count = len(diary.views or [])
    author = diary.author
    return EmotionDiaryResponse(
        id=diary.id,
        content=diary.content,
        mood=diary.mood,
        mood_label=resolve_mood_label(diary.mood),
        is_public=diary.is_public,
        is_current=diary.is_current,
        view_count=view_count,
        created_at=diary.created_at,
        updated_at=diary.updated_at,
        author=EmotionDiaryAuthorBrief(
            id=author.id if author else 0,
            nickname=author.nickname if author else "",
            avatar_url=author.avatar_url if author else None,
            porten_id=author.porten_id if author else "",
        ),
        is_mine=(author.id == current_user_id) if author else False,
    )


@router.post(
    "",
    response_model=ResponseModel[EmotionDiaryResponse],
    status_code=status.HTTP_201_CREATED,
)
def create_diary(
    payload: EmotionDiaryCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new emotion diary entry. The previous current row, if any,
    is demoted to history; the new row becomes the current one and the
    user's cached latest_diary + mood are updated accordingly."""
    try:
        diary = service.create_diary(
            db,
            user=current_user,
            content=payload.content,
            mood=payload.mood,
            is_public=payload.is_public,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    return ResponseModel(data=_build_diary_response(diary, current_user.id))


@router.patch(
    "/current",
    response_model=ResponseModel[EmotionDiaryResponse],
)
def update_current_diary(
    payload: EmotionDiaryCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Save a new version of the current diary. The previous current row
    is kept as history; the new row becomes the current one and the
    user's cached latest_diary + mood are updated accordingly."""
    try:
        diary = service.update_diary(
            db,
            user=current_user,
            content=payload.content,
            mood=payload.mood,
            is_public=payload.is_public,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    return ResponseModel(data=_build_diary_response(diary, current_user.id))


@router.get(
    "/current",
    response_model=ResponseModel[EmotionDiaryResponse],
)
def get_current_diary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current (latest) diary of the current user, or null."""
    diary = service.get_current_diary(db, current_user.id)
    if not diary:
        # Return a null payload (200 with data: null) so the frontend can
        # easily distinguish "not created yet" from "error".
        return ResponseModel(data=None)
    return ResponseModel(
        data=_build_diary_response(diary, current_user.id)
    )


@router.get(
    "/history",
    response_model=ResponseModel[EmotionDiaryListResponse],
)
def list_history(
    cursor: Optional[int] = Query(None, ge=1),
    limit: int = Query(50, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List all diary entries for the current user, newest first."""
    items, total = service.list_history(
        db, user_id=current_user.id, cursor=cursor, limit=limit
    )
    return ResponseModel(
        data=EmotionDiaryListResponse(
            items=[
                _build_diary_response(d, current_user.id) for d in items
            ],
            total=total,
        )
    )


@router.get(
    "/{diary_id}",
    response_model=ResponseModel[EmotionDiaryResponse],
)
def get_diary(
    diary_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get a single diary entry. Non-author viewers are only allowed for
    the author's current row; older rows are author-only. Successful
    non-author fetches record the view."""
    diary = service.get_diary(db, diary_id)
    if not diary:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="diary not found"
        )
    is_mine = diary.user_id == current_user.id
    if not is_mine:
        if not diary.is_current:
            # Older history rows are private to the author.
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="this diary is private",
            )
        if not diary.is_public:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="this diary is private",
            )
        service.record_view(db, diary=diary, viewer=current_user)
        db.refresh(diary)
    return ResponseModel(
        data=_build_diary_response(diary, current_user.id)
    )


@router.delete(
    "/{diary_id}",
    response_model=ResponseModel[dict],
)
def delete_diary(
    diary_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Delete a diary entry. Only the author can delete."""
    diary = service.get_diary(db, diary_id)
    if not diary:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="diary not found"
        )
    if diary.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="only the author can delete this diary",
        )
    was_current = diary.is_current
    service.delete_diary(db, diary)
    # If we deleted the current row, promote the most recent remaining
    # row (by id desc) and sync the user's cached fields.
    if was_current:
        next_current = (
            db.query(EmotionDiary)
            .filter(EmotionDiary.user_id == current_user.id)
            .order_by(EmotionDiary.id.desc())
            .first()
        )
        if next_current:
            next_current.is_current = True
            current_user.latest_diary = next_current.content
            current_user.mood = next_current.mood
            db.add(current_user)
            db.commit()
        else:
            current_user.latest_diary = None
            current_user.mood = None
            db.add(current_user)
            db.commit()
    return ResponseModel(data={"deleted": True})


@router.get(
    "/{diary_id}/viewers",
    response_model=ResponseModel[EmotionDiaryViewerListResponse],
)
def list_diary_viewers(
    diary_id: int,
    cursor: Optional[int] = Query(None, ge=1),
    limit: int = Query(50, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List users who have viewed this diary. Author-only."""
    diary = service.get_diary(db, diary_id)
    if not diary:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="diary not found"
        )
    if diary.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="only the author can view the viewer list",
        )
    items, total = service.list_viewers(
        db, diary=diary, cursor=cursor, limit=limit
    )

    def _to_item(v: EmotionDiaryView) -> EmotionDiaryViewerItem:
        viewer = v.viewer
        return EmotionDiaryViewerItem(
            id=v.id,
            user_id=viewer.id if viewer else 0,
            nickname=viewer.nickname if viewer else "",
            avatar_url=viewer.avatar_url if viewer else None,
            porten_id=viewer.porten_id if viewer else "",
            viewed_at=v.viewed_at,
        )

    return ResponseModel(
        data=EmotionDiaryViewerListResponse(
            items=[_to_item(v) for v in items],
            total=total,
        )
    )

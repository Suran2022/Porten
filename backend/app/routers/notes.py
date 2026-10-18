"""Note routers (personal notebook).

Routes mirror the web mock model: ``/notes`` (list/create),
``/notes/{id}`` (update/delete). Response fields match the mock note
model one-for-one.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas.common import ResponseModel
from app.schemas.note import (
    NoteCreate,
    NoteListResponse,
    NoteResponse,
    NoteUpdate,
)
from app.services import NoteService

router = APIRouter(prefix="/api/v1/notes", tags=["notes"])
service = NoteService()


@router.get(
    "",
    response_model=ResponseModel[NoteListResponse],
)
def list_notes(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List the user's notes, newest first."""
    items = service.list_notes(db, user=current_user)
    return ResponseModel(data=NoteListResponse(items=items))


@router.post(
    "",
    response_model=ResponseModel[NoteResponse],
    status_code=status.HTTP_201_CREATED,
)
def create_note(
    payload: NoteCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a note; omitted tags fall back to ['随记']."""
    note = service.create_note(db, user=current_user, payload=payload)
    return ResponseModel(data=note)


@router.patch(
    "/{note_id}",
    response_model=ResponseModel[NoteResponse],
)
def update_note(
    note_id: int,
    payload: NoteUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Partially update a note (only provided fields change)."""
    try:
        note = service.update_note(
            db, user=current_user, note_id=note_id, payload=payload
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc
    return ResponseModel(data=note)


@router.delete(
    "/{note_id}",
    response_model=ResponseModel[dict],
)
def delete_note(
    note_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Delete a note owned by the current user."""
    try:
        service.delete_note(db, user=current_user, note_id=note_id)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc
    return ResponseModel(data={"deleted": True})

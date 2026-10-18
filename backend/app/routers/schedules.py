"""Schedule routers (personal schedule entries).

Routes mirror the mock engine paths exactly: ``/schedules``,
``/schedules/related`` and ``/schedules/{id}``; response fields match
the mock schedule model one-for-one.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas.common import ResponseModel
from app.schemas.schedule import (
    ScheduleCreate,
    ScheduleListResponse,
    ScheduleRelatedResponse,
    ScheduleResponse,
    ScheduleUpdate,
)
from app.services import ScheduleService

router = APIRouter(prefix="/api/v1/schedules", tags=["schedules"])
service = ScheduleService()


@router.get(
    "",
    response_model=ResponseModel[ScheduleListResponse],
)
def list_schedules(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List schedules of the current user, sorted by date + start time."""
    items = service.list_schedules(db, user=current_user)
    return ResponseModel(data=ScheduleListResponse(items=items))


@router.get(
    "/related",
    response_model=ResponseModel[ScheduleRelatedResponse],
)
def list_related_candidates(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Related-object candidates for the schedule form: linkable trips,
    agreements (empty until the agreements module ships) and comrades."""
    return ResponseModel(
        data=service.related_candidates(db, user=current_user)
    )


@router.post(
    "",
    response_model=ResponseModel[ScheduleResponse],
    status_code=status.HTTP_201_CREATED,
)
def create_schedule(
    payload: ScheduleCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a schedule entry. The card color is randomly assigned."""
    schedule = service.create_schedule(db, user=current_user, payload=payload)
    return ResponseModel(data=schedule)


@router.patch(
    "/{schedule_id}",
    response_model=ResponseModel[ScheduleResponse],
)
def update_schedule(
    schedule_id: int,
    payload: ScheduleUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Partially update a schedule entry (only provided fields change)."""
    try:
        schedule = service.update_schedule(
            db, user=current_user, schedule_id=schedule_id, payload=payload
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc
    return ResponseModel(data=schedule)

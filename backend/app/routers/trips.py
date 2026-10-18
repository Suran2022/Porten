"""Trip routers (flight journeys).

``/trips`` lists the journey cards (the create-journey result syncs
here), ``/trips/assistant`` feeds the my-journey entry card on the
message list, and ``POST /trips`` creates a journey. Response fields
match the mock model one-for-one.
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas.common import ResponseModel
from app.schemas.trip import (
    TripAssistantResponse,
    TripCreate,
    TripListResponse,
    TripResponse,
)
from app.services import TripService

router = APIRouter(prefix="/api/v1/trips", tags=["trips"])
service = TripService()


@router.get(
    "",
    response_model=ResponseModel[TripListResponse],
)
def list_trips(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List the user's journeys ordered by departure time."""
    items = service.list_trips(db, user=current_user)
    return ResponseModel(data=TripListResponse(items=items))


@router.get(
    "/assistant",
    response_model=ResponseModel[TripAssistantResponse],
)
def get_assistant_card(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """My-journey entry card: upcoming journey count + latest summary."""
    return ResponseModel(data=service.assistant_card(db, user=current_user))


@router.post(
    "",
    response_model=ResponseModel[TripResponse],
    status_code=status.HTTP_201_CREATED,
)
def create_trip(
    payload: TripCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a journey. Title and reminder text are derived server-side."""
    trip = service.create_trip(db, user=current_user, payload=payload)
    return ResponseModel(data=trip)

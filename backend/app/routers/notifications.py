"""Notifications router."""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas.common import ResponseModel
from app.schemas.notification import BadgeResponse, ReadNotificationRequest
from app.services import NotificationService

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])
notification_service = NotificationService()


@router.get(
    "/badge",
    response_model=ResponseModel[BadgeResponse],
    status_code=status.HTTP_200_OK,
)
def get_badge_counts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return pending friend and group request counts."""
    counts = notification_service.get_badge_counts(db, current_user)
    return ResponseModel(data=BadgeResponse(**counts))


@router.post(
    "/read",
    response_model=ResponseModel[dict],
    status_code=status.HTTP_200_OK,
)
def mark_notifications_read(
    payload: ReadNotificationRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mark all pending requests of the given type as viewed."""
    notification_service.mark_read(db, current_user, payload.type)
    return ResponseModel(data={"marked": True})

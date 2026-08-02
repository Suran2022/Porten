"""System messages router."""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas.common import ResponseModel
from app.schemas.system_message import (
    SystemMessageListResponse,
    SystemMessageUnreadResponse,
)
from app.services import SystemMessageService

router = APIRouter(prefix="/api/v1/system-messages", tags=["system-messages"])
system_message_service = SystemMessageService()


@router.get(
    "",
    response_model=ResponseModel[SystemMessageListResponse],
    status_code=status.HTTP_200_OK,
)
def list_system_messages(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return system messages for the current user with read state."""
    data = system_message_service.get_messages_for_user(db, current_user)
    return ResponseModel(
        data=SystemMessageListResponse(
            messages=data["messages"],
            unread_count=data["unread_count"],
        )
    )


@router.get(
    "/unread-count",
    response_model=ResponseModel[SystemMessageUnreadResponse],
    status_code=status.HTTP_200_OK,
)
def get_unread_count(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the unread system message count for the current user."""
    count = system_message_service.get_unread_count(db, current_user)
    return ResponseModel(data=SystemMessageUnreadResponse(unread_count=count))


@router.patch(
    "/{message_id}/read",
    response_model=ResponseModel[dict],
    status_code=status.HTTP_200_OK,
)
def mark_system_message_read(
    message_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mark a single system message as read."""
    system_message_service.mark_as_read(db, current_user, message_id)
    return ResponseModel(data={"marked": True})


@router.post(
    "/read-all",
    response_model=ResponseModel[dict],
    status_code=status.HTTP_200_OK,
)
def mark_all_system_messages_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mark all active system messages as read for the current user."""
    system_message_service.mark_all_as_read(db, current_user)
    return ResponseModel(data={"marked": True})

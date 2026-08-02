"""Friend requests router."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas.common import ResponseModel
from app.schemas.contact import (
    FriendRequestResponse,
    HandleRequestRequest,
    SendFriendRequestRequest,
)
from app.services import ContactService

router = APIRouter(prefix="/api/v1/friend-requests", tags=["friend-requests"])
contact_service = ContactService()


@router.post(
    "/",
    response_model=ResponseModel[FriendRequestResponse],
    status_code=status.HTTP_201_CREATED,
)
def send_friend_request(
    payload: SendFriendRequestRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Send a friend request to a user by Porten ID."""
    try:
        request = contact_service.send_friend_request(
            db,
            current_user,
            payload.receiver_porten_id,
            payload.message,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return ResponseModel(
        data=FriendRequestResponse(
            id=request.id,
            sender_id=request.sender_id,
            receiver_id=request.receiver_id,
            sender_nickname=request.sender.nickname if request.sender else "",
            sender_avatar_url=request.sender.avatar_url if request.sender else None,
            message=request.message,
            status=request.status,
            source=request.source,
            created_at=request.created_at,
        )
    )


@router.get(
    "/received",
    response_model=ResponseModel[list[FriendRequestResponse]],
    status_code=status.HTTP_200_OK,
)
def list_received_friend_requests(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return pending friend requests received by the current user."""
    requests = contact_service.list_received_friend_requests(db, current_user)
    return ResponseModel(
        data=[
            FriendRequestResponse(
                id=request.id,
                sender_id=request.sender_id,
                receiver_id=request.receiver_id,
                sender_nickname=request.sender.nickname if request.sender else "",
                sender_avatar_url=request.sender.avatar_url
                if request.sender
                else None,
                message=request.message,
                status=request.status,
                source=request.source,
                created_at=request.created_at,
            )
            for request in requests
        ]
    )


@router.post(
    "/{request_id}/handle",
    response_model=ResponseModel[FriendRequestResponse],
    status_code=status.HTTP_200_OK,
)
def handle_friend_request(
    request_id: int,
    payload: HandleRequestRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Accept or reject a received friend request."""
    try:
        request = contact_service.handle_friend_request(
            db, current_user, request_id, payload.action
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return ResponseModel(
        data=FriendRequestResponse(
            id=request.id,
            sender_id=request.sender_id,
            receiver_id=request.receiver_id,
            sender_nickname=request.sender.nickname if request.sender else "",
            sender_avatar_url=request.sender.avatar_url if request.sender else None,
            message=request.message,
            status=request.status,
            source=request.source,
            created_at=request.created_at,
        )
    )

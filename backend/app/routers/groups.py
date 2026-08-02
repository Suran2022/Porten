"""Groups router."""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas.common import ResponseModel
from app.schemas.contact import HandleRequestRequest
from app.schemas.group import (
    CreateGroupRequest,
    CreateGroupResponse,
    GroupProfileResponse,
    GroupRequestResponse,
    SearchGroupResponse,
    SendGroupRequestRequest,
    UpdateGroupRequest,
)
from app.services import GroupService

router = APIRouter(prefix="/api/v1/groups", tags=["groups"])
group_service = GroupService()


@router.get(
    "/search",
    response_model=ResponseModel[list[SearchGroupResponse]],
    status_code=status.HTTP_200_OK,
)
def search_groups(
    keyword: str = Query(..., min_length=1, description="Group name or camp id keyword"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Search camps by name or camp id according to each camp's discovery setting."""
    groups = group_service.search_groups(db, keyword)
    return ResponseModel(
        data=[SearchGroupResponse.model_validate(group) for group in groups]
    )


@router.post(
    "/create",
    response_model=ResponseModel[CreateGroupResponse],
    status_code=status.HTTP_201_CREATED,
)
def create_group(
    payload: CreateGroupRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new camp (group)."""
    group, conversation_id = group_service.create_group(
        db,
        current_user,
        name=payload.name,
        group_type=payload.group_type,
        description=payload.description,
        avatar_url=payload.avatar_url,
        tags=payload.tags,
        discoverable_by=payload.discoverable_by,
        max_members=payload.max_members,
    )
    return ResponseModel(
        data=CreateGroupResponse(
            id=group.id,
            name=group.name,
            avatar_url=group.avatar_url,
            member_count=group.member_count,
            group_type=group.group_type,
            conversation_id=conversation_id,
            camp_id=group.camp_id,
        )
    )


@router.patch(
    "/{group_id}",
    response_model=ResponseModel[GroupProfileResponse],
    status_code=status.HTTP_200_OK,
)
def update_group(
    group_id: int,
    payload: UpdateGroupRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update a camp/group profile. Only owner or admin can edit."""
    group = group_service.get_group_by_id(db, group_id)
    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="group not found",
        )
    try:
        updated = group_service.update_group(
            db,
            group,
            current_user,
            name=payload.name,
            description=payload.description,
            avatar_url=payload.avatar_url,
            tags=payload.tags,
            discoverable_by=payload.discoverable_by,
            max_members=payload.max_members,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exc),
        ) from exc
    return ResponseModel(data=GroupProfileResponse.model_validate(updated))


@router.post(
    "/requests",
    response_model=ResponseModel[GroupRequestResponse],
    status_code=status.HTTP_201_CREATED,
)
def send_group_request(
    payload: SendGroupRequestRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Apply to join a group."""
    try:
        request = group_service.apply_join_group(
            db, current_user, payload.group_id, payload.message
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return ResponseModel(
        data=GroupRequestResponse(
            id=request.id,
            group_id=request.group_id,
            group_name=request.group.name if request.group else "",
            group_avatar_url=request.group.avatar_url if request.group else None,
            user_id=request.user_id,
            user_nickname=request.user.nickname if request.user else "",
            user_avatar_url=request.user.avatar_url if request.user else None,
            message=request.message,
            status=request.status,
            created_at=request.created_at,
        )
    )


@router.get(
    "/requests/received",
    response_model=ResponseModel[list[GroupRequestResponse]],
    status_code=status.HTTP_200_OK,
)
def list_received_group_requests(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return pending group requests for groups managed by the user."""
    requests = group_service.list_received_group_requests(db, current_user)
    return ResponseModel(
        data=[
            GroupRequestResponse(
                id=request.id,
                group_id=request.group_id,
                group_name=request.group.name if request.group else "",
                group_avatar_url=request.group.avatar_url if request.group else None,
                user_id=request.user_id,
                user_nickname=request.user.nickname if request.user else "",
                user_avatar_url=request.user.avatar_url if request.user else None,
                message=request.message,
                status=request.status,
                created_at=request.created_at,
            )
            for request in requests
        ]
    )


@router.post(
    "/requests/{request_id}/handle",
    response_model=ResponseModel[GroupRequestResponse],
    status_code=status.HTTP_200_OK,
)
def handle_group_request(
    request_id: int,
    payload: HandleRequestRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Accept or reject a group membership request."""
    try:
        request = group_service.handle_group_request(
            db, current_user, request_id, payload.action
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return ResponseModel(
        data=GroupRequestResponse(
            id=request.id,
            group_id=request.group_id,
            group_name=request.group.name if request.group else "",
            group_avatar_url=request.group.avatar_url if request.group else None,
            user_id=request.user_id,
            user_nickname=request.user.nickname if request.user else "",
            user_avatar_url=request.user.avatar_url if request.user else None,
            message=request.message,
            status=request.status,
            created_at=request.created_at,
        )
    )

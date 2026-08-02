"""Contacts router."""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas.common import ResponseModel
from app.schemas.contact import (
    ContactFriendResponse,
    ContactListResponse,
    SearchUserResponse,
)
from app.schemas.group import ContactGroupResponse
from app.services import ContactService, GroupService

router = APIRouter(prefix="/api/v1/contacts", tags=["contacts"])
contact_service = ContactService()
group_service = GroupService()


@router.get(
    "/",
    response_model=ResponseModel[ContactListResponse],
    status_code=status.HTTP_200_OK,
)
def list_contacts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current user's contact list (friends and groups)."""
    friendships = contact_service.list_friends(db, current_user)
    friends = [
        ContactFriendResponse(
            id=friendship.id,
            user_id=friendship.friend_id,
            nickname=friendship.friend.nickname if friendship.friend else "",
            avatar_url=friendship.friend.avatar_url if friendship.friend else None,
            created_at=friendship.created_at,
        )
        for friendship in friendships
    ]

    memberships = group_service.list_groups_for_user(db, current_user)
    groups = [
        ContactGroupResponse(
            id=membership.id,
            group_id=membership.group_id,
            name=membership.group.name if membership.group else "",
            avatar_url=membership.group.avatar_url if membership.group else None,
            role=membership.role,
            created_at=membership.created_at,
        )
        for membership in memberships
    ]

    return ResponseModel(
        data=ContactListResponse(friends=friends, groups=groups)
    )


@router.get(
    "/search/users",
    response_model=ResponseModel[SearchUserResponse],
    status_code=status.HTTP_200_OK,
)
def search_user(
    porten_id: Optional[str] = Query(None, min_length=1, description="Exact Porten ID"),
    nickname: Optional[str] = Query(None, min_length=1, description="Nickname fuzzy match (self only)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Search for a user by exact Porten ID or by nickname (nickname returns self only)."""
    if porten_id:
        user = contact_service.search_user_by_porten_id(db, porten_id)
    elif nickname:
        user = contact_service.search_user_by_nickname(db, current_user, nickname)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="porten_id or nickname is required",
        )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="user not found",
        )
    return ResponseModel(data=SearchUserResponse.model_validate(user))

"""User routers."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas.common import ResponseModel
from app.schemas.user import (
    ChangeEmailRequest,
    UpdateAvatarRequest,
    UpdateBackgroundRequest,
    UpdateNicknameRequest,
    UpdateProfileRequest,
    UserProfileResponse,
)
from app.services import EmailService, UserService

router = APIRouter(prefix="/api/v1/users", tags=["users"])
user_service = UserService()
email_service = EmailService()


def _build_profile_response(user: User, db: Session) -> UserProfileResponse:
    """Build a profile response including computed friend_count and trans_days."""
    return UserProfileResponse.model_validate(user).model_copy(
        update={
            "friend_count": user_service.get_friend_count(db, user.id),
            "trans_days": user_service.get_trans_days(user),
        }
    )


@router.get(
    "/me",
    response_model=ResponseModel[UserProfileResponse],
    status_code=status.HTTP_200_OK,
)
def get_current_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get the current user's profile."""
    return ResponseModel(data=_build_profile_response(current_user, db))


@router.get(
    "/{user_id}/profile",
    response_model=ResponseModel[UserProfileResponse],
    status_code=status.HTTP_200_OK,
)
def get_user_public_profile(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get another user's public profile by id (for comrade profile page)."""
    user = user_service.get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="user not found",
        )
    return ResponseModel(data=_build_profile_response(user, db))


@router.patch(
    "/me/nickname",
    response_model=ResponseModel[UserProfileResponse],
    status_code=status.HTTP_200_OK,
)
def update_nickname(
    payload: UpdateNicknameRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update the current user's nickname."""
    user = user_service.update_nickname(db, current_user, payload.nickname)
    return ResponseModel(data=_build_profile_response(user, db))


@router.patch(
    "/me/avatar",
    response_model=ResponseModel[UserProfileResponse],
    status_code=status.HTTP_200_OK,
)
def update_avatar(
    payload: UpdateAvatarRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update the current user's avatar URL."""
    user = user_service.update_avatar(db, current_user, payload.avatar_url)
    return ResponseModel(data=_build_profile_response(user, db))


@router.patch(
    "/me/background",
    response_model=ResponseModel[UserProfileResponse],
    status_code=status.HTTP_200_OK,
)
def update_background(
    payload: UpdateBackgroundRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update the current user's profile background URL."""
    user = user_service.update_background(db, current_user, payload.background_url)
    return ResponseModel(data=_build_profile_response(user, db))


@router.patch(
    "/me",
    response_model=ResponseModel[UserProfileResponse],
    status_code=status.HTTP_200_OK,
)
def update_profile(
    payload: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update the current user's profile (nickname, avatar, background, gender)."""
    user = user_service.update_profile(
        db,
        current_user,
        nickname=payload.nickname,
        avatar_url=payload.avatar_url,
        background_url=payload.background_url,
        gender=payload.gender,
    )
    return ResponseModel(data=_build_profile_response(user, db))


@router.post(
    "/me/change-email",
    response_model=ResponseModel[UserProfileResponse],
    status_code=status.HTTP_200_OK,
)
def change_email(
    payload: ChangeEmailRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Change the current user's bound email.

    Requires:
    - old_code: a valid verification code sent to the **current** bound email
      (purpose = "change_email_old").
    - new_code: a valid verification code sent to the **new** email
      (purpose = "change_email_new").
    """
    new_email = payload.new_email.strip().lower()
    if new_email == current_user.email.strip().lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="new email must be different from current email",
        )

    # 校验原邮箱验证码（发到当前邮箱）
    if not email_service.verify_code(
        db, current_user.email, payload.old_code, "change_email_old"
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="原邮箱验证码不正确或已过期",
        )

    # 校验新邮箱验证码（发到新邮箱）
    if not email_service.verify_code(
        db, new_email, payload.new_code, "change_email_new"
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="新邮箱验证码不正确或已过期",
        )

    # 邮箱唯一性
    existing = user_service.get_by_email(db, new_email)
    if existing and existing.id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该邮箱已被其他账号绑定",
        )

    old_email = current_user.email.strip().lower()
    current_user.email = new_email
    db.add(current_user)
    db.commit()
    db.refresh(current_user)

    # 消费两个验证码（按 email + purpose 匹配最新未消费记录）
    email_service.consume_code(
        db, new_email, payload.new_code, "change_email_new"
    )
    email_service.consume_code(
        db, old_email, payload.old_code, "change_email_old"
    )

    return ResponseModel(data=_build_profile_response(current_user, db))

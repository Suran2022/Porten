"""Authentication routers."""

import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import get_db
from app.dependencies import get_current_user
from app.models import User

logger = logging.getLogger(__name__)
from app.schemas.auth import (
    DefaultAvatarResponse,
    DefaultNicknameResponse,
    EmailCodeLoginRequest,
    EmailPasswordLoginRequest,
    LoginResponse,
    PortenIdLoginRequest,
    RegisterRequest,
    SendVerificationCodeRequest,
)
from app.schemas.common import ResponseModel
from app.services import EmailService, PortenIdService, UserService

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])
settings = get_settings()
email_service = EmailService()
user_service = UserService()
porten_service = PortenIdService()


async def _background_send_email(recipient: str, code: str) -> None:
    """Background task: try to send the verification email and log failures."""
    try:
        await email_service.send_verification_email(recipient, code)
    except Exception:
        logger.exception("background email failed for %s", recipient)


@router.post(
    "/send-verification-code",
    response_model=ResponseModel[dict],
    status_code=status.HTTP_200_OK,
)
def send_verification_code(
    payload: SendVerificationCodeRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """Create and persist a verification code, then queue email sending."""
    try:
        code = email_service.create_verification_code(db, payload.email, payload.purpose)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=str(exc),
        ) from exc

    background_tasks.add_task(_background_send_email, payload.email, code)
    return ResponseModel(data={"sent": True})


@router.post(
    "/register",
    response_model=ResponseModel[LoginResponse],
    status_code=status.HTTP_201_CREATED,
)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    """Register a new user account."""
    if not email_service.verify_code(db, payload.email, payload.verification_code, "register"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="invalid or expired verification code",
        )

    try:
        user = user_service.register(db, payload.email, payload.password)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    email_service.consume_code(db, payload.email, payload.verification_code, "register")
    return ResponseModel(data=user_service.build_login_response(user))


@router.post(
    "/login/email-code",
    response_model=ResponseModel[LoginResponse],
    status_code=status.HTTP_200_OK,
)
def login_email_code(payload: EmailCodeLoginRequest, db: Session = Depends(get_db)):
    """Login using email and verification code."""
    if not email_service.verify_code(db, payload.email, payload.verification_code, "login"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="invalid or expired verification code",
        )

    user = user_service.get_user_by_email(db, payload.email)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="user not found",
        )

    email_service.consume_code(db, payload.email, payload.verification_code, "login")
    return ResponseModel(data=user_service.build_login_response(user))


@router.post(
    "/login/password",
    response_model=ResponseModel[LoginResponse],
    status_code=status.HTTP_200_OK,
)
def login_password(payload: EmailPasswordLoginRequest, db: Session = Depends(get_db)):
    """Login using email and password."""
    try:
        user = user_service.authenticate_by_password(db, payload.email, payload.password)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc

    return ResponseModel(data=user_service.build_login_response(user))


@router.post(
    "/login/porten-id",
    response_model=ResponseModel[LoginResponse],
    status_code=status.HTTP_200_OK,
)
def login_porten_id(payload: PortenIdLoginRequest, db: Session = Depends(get_db)):
    """Login using Porten account number and password."""
    try:
        user = user_service.authenticate_by_porten_id(
            db, payload.porten_id, payload.password
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc

    return ResponseModel(data=user_service.build_login_response(user))


@router.post(
    "/logout",
    response_model=ResponseModel[dict],
    status_code=status.HTTP_200_OK,
)
def logout(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Invalidate the current user's token by incrementing token_version."""
    user_service.logout(db, current_user)
    return ResponseModel(data={"success": True})


@router.get(
    "/default-avatar",
    response_model=ResponseModel[DefaultAvatarResponse],
    status_code=status.HTTP_200_OK,
)
def default_avatar():
    """Return the default avatar URL."""
    return ResponseModel(data=DefaultAvatarResponse(avatar_url=settings.default_avatar_url))


@router.get(
    "/default-nickname",
    response_model=ResponseModel[DefaultNicknameResponse],
    status_code=status.HTTP_200_OK,
)
def default_nickname():
    """Return a generated default nickname (a random Porten ID)."""
    nickname = porten_service.generate()
    return ResponseModel(data=DefaultNicknameResponse(nickname=nickname))

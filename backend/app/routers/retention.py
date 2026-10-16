"""Retention policy router (user-side retention settings)."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models import User
from app.schemas.common import ResponseModel
from app.schemas.security import (
    RetentionPolicyResponse,
    RetentionPolicyUpdate,
)
from app.services.retention_service import RetentionService

router = APIRouter(prefix="/api/v1/retention", tags=["retention"])

retention_service = RetentionService()


def _build_response(current_user: User, db: Session) -> RetentionPolicyResponse:
    """Build the retention response for the current user."""
    retention_days = retention_service.get_retention_days(db, current_user)
    return RetentionPolicyResponse(
        retention_days=retention_days,
        min_days=retention_service.MIN_RETENTION_DAYS,
        max_days=retention_service.MAX_RETENTION_DAYS,
        default_days=retention_service.DEFAULT_RETENTION_DAYS,
        is_customized=retention_days != retention_service.DEFAULT_RETENTION_DAYS,
    )


@router.get("", response_model=ResponseModel[RetentionPolicyResponse])
def get_retention_policy(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get the current user's effective retention settings."""
    return ResponseModel(data=_build_response(current_user, db))


@router.put("", response_model=ResponseModel[RetentionPolicyResponse])
def update_retention_policy(
    payload: RetentionPolicyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update the current user's retention window."""
    try:
        retention_service.set_retention_days(
            db, current_user, payload.retention_days
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    return ResponseModel(data=_build_response(current_user, db))

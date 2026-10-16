"""Authentication dependencies for FastAPI."""

import logging
from typing import Optional

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import get_db
from app.models import User
from app.security.singleton import get_security_capabilities
from app.services.device_binding_service import device_binding_service
from app.services.honeytoken_service import honeytoken_service
from app.utils.security import decode_access_token

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)


def _check_honeytoken(db: Session, request: Request, token: str) -> None:
    """Flag planted decoy credentials on the invalid-token path.

    A honeytoken reaching this path proves the decoy leaked: record
    the hit, raise a critical event and optionally block the source.
    Never raises -- authentication must behave identically whether or
    not the check succeeds.
    """
    settings = get_settings()
    if not settings.security_honeypot_enabled or request is None:
        return
    client_ip = request.client.host if request.client else "unknown"
    honeytoken = honeytoken_service.lookup(db, token)
    if honeytoken is None:
        return
    honeytoken_service.register_hit(db, honeytoken, client_ip)
    try:
        get_security_capabilities().event_sink.emit(
            db,
            "honeypot_honeytoken_presented",
            severity="critical",
            detail=f"{request.method} {request.url.path}",
            meta={"path": request.url.path, "method": request.method},
        )
    except Exception:
        logger.warning("honeytoken event emission failed", exc_info=True)
    if settings.security_honeypot_autoblock:
        blocklist = getattr(get_security_capabilities(), "edge_blocklist", None)
        if blocklist is not None:
            try:
                blocklist.block_ip(client_ip)
            except Exception:
                logger.warning("honeytoken autoblock failed", exc_info=True)


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db),
    request: Request = None,
) -> User:
    """Validate the bearer token and return the current user."""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_access_token(credentials.credentials)
    if not payload:
        # A planted decoy credential presented here is proof of
        # compromise; genuine invalid tokens fall through untouched.
        _check_honeytoken(db, request, credentials.credentials)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid token payload",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token_version = payload.get("tv")

    user = db.query(User).filter_by(id=int(user_id), is_active=True).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="user not found",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Tokens issued before token_version was introduced are accepted once.
    # Tokens issued after logout carry a token_version that must match the user.
    if token_version is not None and user.token_version != token_version:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="token has been revoked",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Device binding: tokens carrying a did claim are only valid while
    # the bound device session exists and is not revoked. Tokens issued
    # before device binding carry no claim and are accepted as-is.
    device_id = payload.get("did")
    if device_id is not None:
        if not device_binding_service.is_device_valid(db, user.id, device_id):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="device session revoked",
                headers={"WWW-Authenticate": "Bearer"},
            )
        device_binding_service.touch_device(db, user.id, device_id)

    return user

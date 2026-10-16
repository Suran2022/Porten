"""Honeypot decoy endpoints (design doc §5.5).

Decoy admin and internal paths that do not exist in the real product.
They answer like the genuine article so a probing attacker stays
engaged, while every hit raises a security event and -- when the edge
blocklist is available -- automatically blocks the source IP.

Honeytokens (planted decoy credentials) are checked wherever a token
is presented here: a match is proof of compromise and raises a
critical event.

When the honeypot is disabled the endpoints answer 404, making them
indistinguishable from routes that were never deployed.
"""

import asyncio
import logging
from typing import Optional

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse, JSONResponse
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import get_db
from app.security.singleton import get_security_capabilities
from app.services.honeytoken_service import honeytoken_service

logger = logging.getLogger(__name__)

router = APIRouter(tags=["honeypot"])

# Small delay before answering a decoy: wastes a prober's time without
# being noticeable to a real client (which never sees these paths).
_DECOY_DELAY_SECONDS = 0.2

# Fake admin console served at the decoy paths.
_DECOY_LOGIN_PAGE = """<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Porten Admin</title></head>
<body>
<form method="post" action="/admin/login">
  <label>Username <input name="username" type="text"></label>
  <label>Password <input name="password" type="password"></label>
  <button type="submit">Sign in</button>
</form>
</body>
</html>
"""

# Fake runtime configuration served at the actuator decoy. Values are
# decoys: nothing here is a real credential.
_DECOY_ENV = {
    "activeProfiles": ["prod"],
    "server.port": 8000,
    "spring.datasource.url": "jdbc:mysql:<b>db.internal:3306/porten</b>",
    "management.endpoints.web.exposure.include": "env,health,metrics",
}


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _honeypot_on() -> bool:
    return get_settings().security_honeypot_enabled


def _not_found() -> JSONResponse:
    return JSONResponse(status_code=404, content={"detail": "Not Found"})


def _emit_hit(request: Request, db: Session, severity: str, event_type: str) -> None:
    """Record a decoy hit; never raises to the request path."""
    try:
        get_security_capabilities().event_sink.emit(
            db,
            event_type,
            severity=severity,
            detail=f"{request.method} {request.url.path}",
            meta={"path": request.url.path, "method": request.method},
        )
    except Exception:
        logger.warning("honeypot event emission failed", exc_info=True)


def _maybe_autoblock(client_ip: str) -> None:
    """Block the probing IP when configured and a blocklist exists."""
    if not get_settings().security_honeypot_autoblock:
        return
    blocklist = getattr(get_security_capabilities(), "edge_blocklist", None)
    if blocklist is None:
        return
    try:
        blocklist.block_ip(client_ip)
    except Exception:
        logger.warning("honeypot autoblock failed", exc_info=True)


def _check_presented_token(
    db: Session, request: Request, token: Optional[str]
) -> bool:
    """Return True when ``token`` is a planted honeytoken.

    A match updates the decoy's counters and raises a critical event;
    the caller still answers like a genuine service would.
    """
    if not token or not _honeypot_on():
        return False
    honeytoken = honeytoken_service.lookup(db, token)
    if honeytoken is None:
        return False
    honeytoken_service.register_hit(db, honeytoken, _client_ip(request))
    _emit_hit(request, db, "critical", "honeypot_honeytoken_presented")
    return True


def _bearer_token(request: Request) -> Optional[str]:
    header = request.headers.get("authorization") or ""
    if header.lower().startswith("bearer "):
        return header[7:].strip()
    return None


@router.get("/admin", response_class=HTMLResponse)
async def decoy_admin_console(request: Request, db: Session = Depends(get_db)):
    """Decoy admin console login page."""
    if not _honeypot_on():
        return _not_found()
    await asyncio.sleep(_DECOY_DELAY_SECONDS)
    _check_presented_token(db, request, _bearer_token(request))
    _emit_hit(request, db, "high", "honeypot_endpoint_hit")
    _maybe_autoblock(_client_ip(request))
    return HTMLResponse(_DECOY_LOGIN_PAGE)


@router.post("/admin/login")
async def decoy_admin_login(request: Request, db: Session = Depends(get_db)):
    """Decoy admin login: always fails, like the genuine endpoint."""
    if not _honeypot_on():
        return _not_found()
    await asyncio.sleep(_DECOY_DELAY_SECONDS)
    _check_presented_token(db, request, _bearer_token(request))
    _emit_hit(request, db, "high", "honeypot_endpoint_hit")
    _maybe_autoblock(_client_ip(request))
    return JSONResponse(
        status_code=401, content={"detail": "Invalid username or password"}
    )


@router.get("/api/admin")
async def decoy_admin_api(request: Request, db: Session = Depends(get_db)):
    """Decoy admin API: looks like an authenticated JSON surface."""
    if not _honeypot_on():
        return _not_found()
    await asyncio.sleep(_DECOY_DELAY_SECONDS)
    _check_presented_token(db, request, _bearer_token(request))
    _emit_hit(request, db, "high", "honeypot_endpoint_hit")
    _maybe_autoblock(_client_ip(request))
    return JSONResponse(status_code=401, content={"detail": "admin token required"})


@router.get("/internal/metrics")
async def decoy_internal_metrics(request: Request, db: Session = Depends(get_db)):
    """Decoy metrics endpoint with plausible-looking counters."""
    if not _honeypot_on():
        return _not_found()
    await asyncio.sleep(_DECOY_DELAY_SECONDS)
    _emit_hit(request, db, "high", "honeypot_endpoint_hit")
    _maybe_autoblock(_client_ip(request))
    return JSONResponse(
        content={
            "uptime_seconds": 184673,
            "requests_total": 9284411,
            "error_rate": 0.0004,
        }
    )


@router.get("/actuator/env")
async def decoy_actuator_env(request: Request, db: Session = Depends(get_db)):
    """Decoy Spring-actuator style configuration dump."""
    if not _honeypot_on():
        return _not_found()
    await asyncio.sleep(_DECOY_DELAY_SECONDS)
    _emit_hit(request, db, "high", "honeypot_endpoint_hit")
    _maybe_autoblock(_client_ip(request))
    return JSONResponse(content=_DECOY_ENV)


@router.get("/manage")
async def decoy_manage(request: Request, db: Session = Depends(get_db)):
    """Decoy management console redirect target."""
    if not _honeypot_on():
        return _not_found()
    await asyncio.sleep(_DECOY_DELAY_SECONDS)
    _emit_hit(request, db, "high", "honeypot_endpoint_hit")
    _maybe_autoblock(_client_ip(request))
    return JSONResponse(status_code=302, content={"detail": "Found"})

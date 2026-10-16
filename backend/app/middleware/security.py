"""Security middleware: response hardening and edge rate limiting."""

import logging

from fastapi import Request
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.config import get_settings
from app.schemas.common import ResponseModel
from app.security.singleton import get_security_capabilities

logger = logging.getLogger(__name__)

settings = get_settings()

# Rate-limit buckets: (requests per window, window seconds). Sensitive
# endpoints are limited aggressively; everything else gets a generous
# global bucket keyed by client IP only, keeping limiter memory bounded.
_AUTH_BUCKET = ("auth", 30, 60)
_GLOBAL_BUCKET = ("global", 600, 60)

_AUTH_PREFIXES = ("/api/v1/auth/",)
_EXEMPT_PATHS = ("/health", "/docs", "/redoc", "/openapi.json")


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Attach hardening headers to every response."""

    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        if request.url.scheme == "https":
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains"
            )
        return response


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Process-local sliding-window rate limiter (lite profile).

    Exceeding a bucket yields a unified 429 response and a warning
    security event. The limiter is fail-open on internal errors so a
    security malfunction can never take the service down.
    """
    async def dispatch(self, request: Request, call_next):
        if not settings.security_rate_limit_enabled:
            return await call_next(request)

        path = request.url.path
        if path in _EXEMPT_PATHS:
            return await call_next(request)

        bucket = (
            _AUTH_BUCKET
            if path.startswith(_AUTH_PREFIXES)
            else _GLOBAL_BUCKET
        )
        bucket_name, limit, window = bucket

        client_ip = request.client.host if request.client else "unknown"
        key = f"{bucket_name}:{client_ip}"

        try:
            allowed = get_security_capabilities().rate_limiter.allow(
                key, limit, window
            )
        except Exception:
            # Fail-open: rate limiting must never break the service.
            logger.warning("rate limit check failed, allowing request", exc_info=True)
            return await call_next(request)

        if not allowed:
            logger.warning(
                "rate limit exceeded: bucket=%s window=%ss", bucket_name, window
            )
            return JSONResponse(
                status_code=429,
                content=jsonable_encoder(
                    ResponseModel(code=429, message="too many requests", data=None)
                ),
                headers={"Retry-After": str(window)},
            )

        return await call_next(request)


class BlocklistMiddleware(BaseHTTPMiddleware):
    """Edge blocklist check (standard+ profiles).

    Rejects requests from blocked client IPs with 403. With no
    blocklist configured (lite profile, or degraded standard without
    Redis) the middleware is a no-op; internal errors fail open so a
    blocklist malfunction never blocks legitimate traffic.
    """

    async def dispatch(self, request: Request, call_next):
        blocklist = getattr(get_security_capabilities(), "edge_blocklist", None)
        if blocklist is None:
            return await call_next(request)

        client_ip = request.client.host if request.client else "unknown"
        try:
            blocked = blocklist.is_blocked(client_ip)
        except Exception:
            logger.warning("blocklist check failed, allowing request", exc_info=True)
            return await call_next(request)

        if blocked:
            logger.warning("blocked client rejected: ip=%s", client_ip)
            return JSONResponse(
                status_code=403,
                content=jsonable_encoder(
                    ResponseModel(code=403, message="request rejected", data=None)
                ),
            )

        return await call_next(request)


class WafMiddleware(BaseHTTPMiddleware):
    """Request-level WAF check (standard+ profiles).

    Uses the profile's WAF rule provider; with no provider configured
    (lite profile) the middleware is a no-op. Rule hits are logged and
    rejected with 403; internal errors fail open so a broken rule set
    never blocks legitimate traffic.
    """

    async def dispatch(self, request: Request, call_next):
        waf_rules = getattr(get_security_capabilities(), "waf_rules", None)
        if waf_rules is None:
            return await call_next(request)

        try:
            rule_name = waf_rules.matches(
                request.url.path, request.url.query
            )
        except Exception:
            logger.warning("waf check failed, allowing request", exc_info=True)
            return await call_next(request)

        if rule_name is not None:
            logger.warning("waf rule hit: %s path=%s", rule_name, request.url.path)
            return JSONResponse(
                status_code=403,
                content=jsonable_encoder(
                    ResponseModel(code=403, message="request rejected", data=None)
                ),
            )

        return await call_next(request)

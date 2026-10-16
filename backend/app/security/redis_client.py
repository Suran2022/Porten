"""Redis client helper with graceful degradation support."""

import logging
from typing import Optional

import redis

from app.config import get_settings

logger = logging.getLogger(__name__)

# Short timeouts keep capability assembly and request paths from
# blocking on an unreachable Redis.
_CONNECT_TIMEOUT = 2
_SOCKET_TIMEOUT = 2


def create_redis_client(url: Optional[str] = None) -> Optional[redis.Redis]:
    """Return a connected Redis client, or None when unreachable.

    Callers treat None as "capability unavailable" and degrade to the
    in-process implementation; a missing Redis never fails startup
    unless ``security_redis_required`` is set.
    """
    settings = get_settings()
    target = url or settings.redis_url
    client = redis.Redis.from_url(
        target,
        decode_responses=True,
        socket_connect_timeout=_CONNECT_TIMEOUT,
        socket_timeout=_SOCKET_TIMEOUT,
    )
    try:
        client.ping()
    except redis.RedisError:
        logger.warning("redis unreachable at %s", target)
        return None
    return client

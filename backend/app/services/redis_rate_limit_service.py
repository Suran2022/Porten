"""Redis-backed sliding-window rate limiter (standard profile).

Uses a Redis sorted set per key: members are request timestamps and
the window is trimmed on every check, so counts stay exact across
instances. Falls back to an in-process limiter when Redis calls fail
so rate limiting can never take the service down.
"""

import logging
import time
from typing import Optional

import redis

from app.services.rate_limit_service import InMemoryRateLimiter

logger = logging.getLogger(__name__)


class RedisRateLimiter:
    """Sliding-window rate limiter backed by Redis."""

    _KEY_PREFIX = "porten:ratelimit"

    def __init__(
        self,
        client: redis.Redis,
        fallback: Optional[InMemoryRateLimiter] = None,
    ) -> None:
        self._client = client
        self._fallback = fallback or InMemoryRateLimiter()

    def allow(self, key: str, limit: int, window_seconds: int) -> bool:
        """Return True if the request identified by key is within quota."""
        try:
            return self._allow_redis(key, limit, window_seconds)
        except redis.RedisError:
            logger.warning("redis rate limit check failed, using fallback", exc_info=True)
            return self._fallback.allow(key, limit, window_seconds)

    def _allow_redis(self, key: str, limit: int, window_seconds: int) -> bool:
        redis_key = f"{self._KEY_PREFIX}:{key}"
        now = time.time()
        window_start = now - window_seconds
        member = f"{now:.6f}"

        pipe = self._client.pipeline()
        # Drop timestamps that fell out of the window.
        pipe.zremrangebyscore(redis_key, 0, window_start)
        pipe.zcard(redis_key)
        pipe.zadd(redis_key, {member: now})
        pipe.expire(redis_key, window_seconds)
        results = pipe.execute()

        count = results[1]
        if count >= limit:
            # Over quota: roll back this request's timestamp so the
            # count reflects accepted requests only.
            self._client.zrem(redis_key, member)
            return False
        return True

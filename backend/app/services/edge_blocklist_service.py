"""Edge blocklist backed by Redis (standard profile).

Blocked client IPs live in a Redis SET; the provider caches the set
locally and re-pulls it when the refresh interval elapses, so bans and
unbans take effect across instances without a restart (the same
hot-reload pattern as the WAF rule provider). Redis failures keep the
last known set and ``is_blocked`` never raises: a blocklist
malfunction must not take the service down.
"""

import logging
import threading
import time
from typing import Optional

import redis

logger = logging.getLogger(__name__)

_DEFAULT_REFRESH_SECONDS = 5


class RedisEdgeBlocklist:
    """Hot-reloaded IP blocklist."""

    def __init__(
        self,
        client: redis.Redis,
        key: str = "porten:security:blocklist:ips",
        refresh_seconds: int = _DEFAULT_REFRESH_SECONDS,
    ) -> None:
        self._client = client
        self._key = key
        self._refresh_seconds = refresh_seconds
        self._lock = threading.Lock()
        self._blocked: frozenset[str] = frozenset()
        self._last_refresh = 0.0

    def is_blocked(self, ip: str) -> bool:
        """Return True when the IP is on the active blocklist."""
        self._maybe_refresh()
        return ip in self._blocked

    def block_ip(self, ip: str) -> None:
        """Add an IP to the blocklist and refresh the local cache."""
        try:
            self._client.sadd(self._key, ip)
        except redis.RedisError:
            logger.warning("blocklist add failed", exc_info=True)
            return
        self._last_refresh = 0.0  # force refresh on next use
        self._maybe_refresh()

    def unblock_ip(self, ip: str) -> None:
        """Remove an IP from the blocklist and refresh the local cache."""
        try:
            self._client.srem(self._key, ip)
        except redis.RedisError:
            logger.warning("blocklist remove failed", exc_info=True)
            return
        self._last_refresh = 0.0
        self._maybe_refresh()

    def _maybe_refresh(self) -> None:
        """Re-pull the set when the refresh interval elapsed."""
        now = time.monotonic()
        if now - self._last_refresh < self._refresh_seconds:
            return
        with self._lock:
            if now - self._last_refresh < self._refresh_seconds:
                return
            self._last_refresh = now
            try:
                members = self._client.smembers(self._key)
            except redis.RedisError:
                logger.warning("blocklist refresh failed, keeping current", exc_info=True)
                return
            if members is None:
                return
            self._blocked = frozenset(members)

    def current_size(self) -> int:
        """Number of blocked IPs in the active cache (diagnostics)."""
        self._maybe_refresh()
        return len(self._blocked)

"""In-memory sliding-window rate limiter (lite profile).

Single-process limiter with a bounded key cache: on low-memory machines
the cache must never grow without bound, so the least recently seen keys
are evicted once the capacity is reached.
"""

import threading
import time
from collections import OrderedDict, deque


class InMemoryRateLimiter:
    """Sliding-window rate limiter with a bounded in-process key cache."""

    def __init__(self, max_tracked_keys: int = 10_000) -> None:
        self._windows: "OrderedDict[str, deque[float]]" = OrderedDict()
        self._max_tracked_keys = max_tracked_keys
        self._lock = threading.Lock()

    def allow(self, key: str, limit: int, window_seconds: int) -> bool:
        """Return True if the request identified by key is within quota."""
        now = time.monotonic()
        cutoff = now - window_seconds

        with self._lock:
            window = self._windows.get(key)
            if window is None:
                window = deque()
                self._windows[key] = window

            while window and window[0] <= cutoff:
                window.popleft()

            if len(window) >= limit:
                # Touch to keep the key recently used before refusing.
                self._windows.move_to_end(key)
                return False

            window.append(now)
            self._windows.move_to_end(key)
            self._evict_if_needed()
            return True

    def _evict_if_needed(self) -> None:
        """Drop least recently seen keys when capacity is exceeded."""
        while len(self._windows) > self._max_tracked_keys:
            self._windows.popitem(last=False)

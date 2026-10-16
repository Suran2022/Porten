"""Asynchronous security event queue backed by Redis Stream.

Every security event is first persisted to the database (durable audit)
and then published to a Redis Stream (fan-out for asynchronous review).
The queue keeps a durable cursor: after an outage, consumers replay
everything after the last processed id so nothing slips through
unreviewed (architecture doc: event replay catch-up).
"""

import json
import logging
from typing import Any, Optional

import redis

logger = logging.getLogger(__name__)

# Approximate stream cap; old entries age out while the cursor keeps
# replay bounded to unconsumed events.
_STREAM_MAXLEN = 100_000


class RedisStreamEventQueue:
    """Redis Stream publisher with a durable replay cursor."""

    def __init__(
        self,
        client: redis.Redis,
        stream_key: str,
        cursor_key: str,
    ) -> None:
        self._client = client
        self._stream_key = stream_key
        self._cursor_key = cursor_key

    def publish(self, event_type: str, payload: dict) -> Optional[str]:
        """Append an event to the stream; returns the entry id or None."""
        fields = {"type": event_type}
        for key, value in payload.items():
            fields[key] = _flatten(value)
        try:
            return self._client.xadd(
                self._stream_key, fields, maxlen=_STREAM_MAXLEN, approximate=True
            )
        except redis.RedisError:
            logger.warning("event stream publish failed", exc_info=True)
            return None

    def get_cursor(self) -> str:
        """Return the last processed entry id ("0" when nothing yet)."""
        try:
            return self._client.get(self._cursor_key) or "0"
        except redis.RedisError:
            return "0"

    def advance_cursor(self, entry_id: str) -> None:
        """Persist the replay position after an entry is processed."""
        try:
            self._client.set(self._cursor_key, entry_id)
        except redis.RedisError:
            logger.warning("event stream cursor update failed", exc_info=True)

    def replay_since(self, from_id: str, count: int = 100) -> list[dict]:
        """Return up to count entries after from_id, oldest first."""
        try:
            entries = self._client.xrange(
                self._stream_key, min=f"({from_id}", count=count
            )
        except redis.RedisError:
            logger.warning("event stream replay failed", exc_info=True)
            return []
        return [self._decode(entry_id, fields) for entry_id, fields in entries]

    def pending_count(self) -> int:
        """Number of stream entries not yet covered by the cursor."""
        cursor = self.get_cursor()
        try:
            if cursor == "0":
                return self._client.xlen(self._stream_key)
            return len(
                self._client.xrange(self._stream_key, min=f"({cursor}", count=1000)
            )
        except redis.RedisError:
            return 0

    @staticmethod
    def _decode(entry_id: str, fields: dict) -> dict:
        """Decode a stream entry back into an event dict."""
        event: dict[str, Any] = {"id": entry_id}
        for key, value in fields.items():
            if key == "payload":
                try:
                    event.update(json.loads(value))
                except (ValueError, TypeError):
                    pass
            else:
                event[key] = value
        return event


def _flatten(value: Any) -> str:
    """Render a payload value as a stream-safe string."""
    if isinstance(value, str):
        return value
    if isinstance(value, (int, float, bool)):
        return str(value)
    if value is None:
        return ""
    return json.dumps(value, ensure_ascii=False)


class StreamingEventSink:
    """Event sink that persists to the database and fans out to a stream.

    The database write is the durable record; the stream publish is
    best-effort so an unavailable Redis never loses audit data.
    """

    def __init__(self, db_sink, queue: RedisStreamEventQueue) -> None:
        self._db_sink = db_sink
        self._queue = queue

    def emit(
        self,
        db,
        event_type: str,
        severity: str = "info",
        user_id: Optional[int] = None,
        detail: Optional[str] = None,
        meta: Optional[dict] = None,
    ) -> None:
        """Persist the event, then publish it for asynchronous review."""
        self._db_sink.emit(db, event_type, severity, user_id, detail, meta)
        self._queue.publish(
            event_type,
            {
                "severity": severity,
                "user_id": user_id,
                "detail": detail,
                "meta": meta,
            },
        )

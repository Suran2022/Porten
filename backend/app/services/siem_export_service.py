"""SIEM export: ship the security event stream to a webhook.

A background consumer reads the Redis Stream with a dedicated consumer
group and POSTs batches of decoded events to the configured webhook.
Delivery is at-least-once: entries are acknowledged only after the
webhook accepts them, so an outage replays everything still pending.

The exporter never touches the business path. It runs in its own task,
every failure is logged and retried on the next round, and a broken
webhook can never delay or block request handling.
"""

import asyncio
import json
import logging
import os
import socket
from typing import Any, Dict, List, Optional

import httpx
import redis

from app.config import get_settings
from app.security.redis_client import create_redis_client

logger = logging.getLogger(__name__)

# Consumer name is per process so pending entries stay reclaimable by
# the instance that read them (no cross-instance stealing).
_CONSUMER_NAME = f"siem-{socket.gethostname()}-{os.getpid()}"


class SiemExporter:
    """Consumer-group exporter from the event stream to a webhook."""

    def __init__(
        self,
        client: redis.Redis,
        *,
        stream_key: str,
        group: str,
        webhook_url: str,
        batch_size: int = 100,
        timeout_seconds: float = 5.0,
        http_client: Optional[httpx.Client] = None,
    ) -> None:
        self._client = client
        self._stream_key = stream_key
        self._group = group
        self._webhook_url = webhook_url
        self._batch_size = batch_size
        self._http = http_client or httpx.Client(timeout=timeout_seconds)
        self._group_ready = False

    def export_once(self) -> int:
        """Deliver one round of events; returns the delivered count.

        Previously delivered-but-unacknowledged entries are retried
        first, then fresh entries are read. Each batch is acknowledged
        only after the webhook accepted it.
        """
        try:
            if not self._ensure_group():
                return 0
            delivered = 0
            # "0" replays this consumer's pending entries; ">" reads
            # never-before-delivered entries.
            for stream_id in ("0", ">"):
                entries = self._read(stream_id)
                if entries and self._post(entries):
                    self._ack(entries)
                    delivered += len(entries)
            return delivered
        except redis.RedisError:
            logger.warning("siem export round failed", exc_info=True)
            return 0

    def pending_count(self) -> int:
        """Entries delivered to this consumer but not yet acknowledged."""
        try:
            if not self._ensure_group():
                return 0
            info = self._client.xpending_range(
                self._stream_key, self._group, min="-", max="+", count=1000
            )
            return len(info)
        except redis.RedisError:
            return 0

    # -- internals -------------------------------------------------------

    def _ensure_group(self) -> bool:
        """Create the consumer group once (idempotent across restarts)."""
        if self._group_ready:
            return True
        try:
            self._client.xgroup_create(
                self._stream_key, self._group, id="0", mkstream=True
            )
        except redis.ResponseError as exc:
            if "BUSYGROUP" not in str(exc):
                logger.warning("siem consumer group creation failed: %s", exc)
                return False
        except redis.RedisError:
            logger.warning("siem consumer group creation failed", exc_info=True)
            return False
        self._group_ready = True
        return True

    def _read(self, stream_id: str) -> List[Dict[str, Any]]:
        """Read one batch for this consumer starting at ``stream_id``."""
        response = self._client.xreadgroup(
            self._group,
            _CONSUMER_NAME,
            {self._stream_key: stream_id},
            count=self._batch_size,
        )
        entries: List[Dict[str, Any]] = []
        for _stream, messages in response or []:
            for entry_id, fields in messages:
                entries.append(_decode_entry(entry_id, fields))
        return entries

    def _ack(self, entries: List[Dict[str, Any]]) -> None:
        try:
            self._client.xack(
                self._stream_key,
                self._group,
                *[entry["id"] for entry in entries],
            )
        except redis.RedisError:
            logger.warning("siem ack failed", exc_info=True)

    def _post(self, entries: List[Dict[str, Any]]) -> bool:
        """POST one batch to the webhook; True when it was accepted."""
        payload = {"source": "porten-security", "events": entries}
        try:
            response = self._http.post(self._webhook_url, json=payload)
        except httpx.HTTPError:
            logger.warning("siem webhook post failed", exc_info=True)
            return False
        if response.status_code // 100 != 2:
            logger.warning(
                "siem webhook rejected batch: status=%s", response.status_code
            )
            return False
        return True


def _decode_entry(entry_id: str, fields: dict) -> Dict[str, Any]:
    """Decode a stream entry into a JSON-safe event dict."""
    event: Dict[str, Any] = {"id": entry_id}
    for key, value in fields.items():
        if key == "payload":
            try:
                event.update(json.loads(value))
            except (ValueError, TypeError):
                pass
        else:
            event[key] = value
    return event


async def siem_export_task(exporter: SiemExporter, interval_seconds: int) -> None:
    """Background loop: export rounds until the process shuts down.

    The first round runs immediately; every iteration failure is
    swallowed so the loop can never die on a bad webhook or Redis.
    """
    while True:
        try:
            delivered = exporter.export_once()
            if delivered:
                logger.info("siem exported %d security events", delivered)
        except Exception:
            logger.warning("siem export iteration failed", exc_info=True)
        await asyncio.sleep(interval_seconds)


def build_siem_exporter() -> Optional[SiemExporter]:
    """Assemble the exporter, or None when it cannot run.

    Disabled by default: no webhook URL, an unreachable Redis or a
    malformed stream setup all yield None (no background task), so a
    misconfigured SIEM never affects the service.
    """
    settings = get_settings()
    if not settings.security_siem_enabled:
        return None
    if not settings.security_siem_webhook_url.strip():
        logger.warning("siem export enabled but no webhook url configured")
        return None
    client = create_redis_client()
    if client is None:
        logger.warning("siem export enabled but redis is unreachable")
        return None
    return SiemExporter(
        client,
        stream_key=settings.security_event_stream_key,
        group=settings.security_siem_consumer_group,
        webhook_url=settings.security_siem_webhook_url,
        batch_size=settings.security_siem_batch_size,
        timeout_seconds=settings.security_siem_timeout_seconds,
    )

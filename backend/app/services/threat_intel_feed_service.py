"""External threat-intelligence feed ingestion (advanced profile).

Fetches a configured feed of host verdicts and upserts them into the
same ``url_reputations`` table the scanner reads, so external
intelligence and manual review share one hot path.

Contract:

* Disabled by default (empty ``security_threat_feed_url``); the
  background loop is only started when the feed is configured.
* A failed fetch keeps the existing database records intact -- the
  locally cached reputation set remains the fallback.
* Every applied record carries a TTL (``security_threat_feed_ttl_seconds``)
  so stale feed entries age out instead of blocking hosts forever.
* Ingestion never raises: failures are logged and reported as a count
  of zero applied entries.

Supported feed formats (auto-detected):

* Line-based: ``host<TAB>level`` or ``host,level[,reason]`` with ``#``
  comments and blank lines.
* JSON: an array of objects, or newline-delimited JSON objects, each
  ``{"host": ..., "level": ..., "reason": ...}``.
"""

import asyncio
import json
import logging
import re
from datetime import datetime, timedelta, timezone
from typing import Callable, List, Optional, Tuple

import httpx
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import SessionLocal
from app.schemas.security import UrlVerdictLevel
from app.services.threat_intel_service import ReputationEntry, ThreatIntelService
from app.security.redis_client import create_redis_client

logger = logging.getLogger(__name__)

# One parsed feed entry: (host, level, reason).
_ParsedEntry = Tuple[str, UrlVerdictLevel, str]

_LINE_SPLIT_RE = re.compile(r"[\t,;]+")

_MAX_HOST_LENGTH = 253

_DEFAULT_REASON = "external threat feed"


class ThreatIntelFeedService:
    """Periodic ingestion of an external host-reputation feed."""

    def __init__(
        self,
        intel_service: ThreatIntelService,
        session_factory: Callable[[], Session] = SessionLocal,
        client: Optional[httpx.Client] = None,
        feed_url: Optional[str] = None,
        ttl_seconds: Optional[int] = None,
    ) -> None:
        settings = get_settings()
        self._intel = intel_service
        # A per-call factory keeps the feed session independent from any
        # request-scoped session (same pattern as ThreatIntelService).
        self._session_factory = session_factory
        self._feed_url = (
            feed_url if feed_url is not None else settings.security_threat_feed_url
        ).strip()
        self._ttl_seconds = (
            ttl_seconds
            if ttl_seconds is not None
            else settings.security_threat_feed_ttl_seconds
        )
        self._source = "feed"
        self._client = client or httpx.Client(
            timeout=settings.security_url_fetch_timeout_seconds
        )

    def ingest_once(self) -> int:
        """Fetch and apply the feed once; return the applied entry count.

        Never raises: fetch failures, parse failures and database
        failures all degrade to zero applied entries with the previous
        reputation records left untouched.
        """
        if not self._feed_url:
            return 0

        try:
            response = self._client.get(self._feed_url)
            response.raise_for_status()
            raw = response.text
        except Exception:
            logger.warning(
                "threat feed fetch failed: %s", self._feed_url, exc_info=True
            )
            return 0

        entries = self._parse(raw)
        if not entries:
            logger.info("threat feed contained no applicable entries")
            return 0

        expires_at = datetime.now(timezone.utc) + timedelta(seconds=self._ttl_seconds)
        items: List[ReputationEntry] = [
            (host, level, reason, self._source, expires_at)
            for host, level, reason in entries
        ]

        db = self._session_factory()
        try:
            applied = self._intel.record_reputations(db, items)
        except Exception:
            logger.warning("threat feed upsert failed", exc_info=True)
            try:
                db.rollback()
            except Exception:
                pass
            return 0
        finally:
            db.close()
        logger.info("threat feed applied %d host verdicts", applied)
        return applied

    def _parse(self, raw: str) -> List[_ParsedEntry]:
        """Parse the feed payload into validated entries."""
        text = raw.strip()
        if not text:
            return []

        if text[0] in "[{":
            try:
                data = json.loads(text)
            except ValueError:
                data = None
            if data is not None:
                records = data if isinstance(data, list) else [data]
                return self._coerce(records)

        return self._coerce(self._line_records(text))

    @staticmethod
    def _line_records(text: str) -> List[dict]:
        """Split a line-based payload into record dicts.

        Each line is ``host<sep>level[,reason]``; lines starting with
        ``{`` are parsed as individual JSON objects (JSON-lines feeds).
        """
        records: List[dict] = []
        for line in text.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("{"):
                try:
                    records.append(json.loads(line))
                except ValueError:
                    continue
                continue
            parts = [part.strip() for part in _LINE_SPLIT_RE.split(line)]
            if len(parts) < 2:
                continue
            records.append(
                {
                    "host": parts[0],
                    "level": parts[1],
                    "reason": parts[2] if len(parts) > 2 and parts[2] else None,
                }
            )
        return records

    @staticmethod
    def _coerce(records: List[dict]) -> List[_ParsedEntry]:
        """Validate raw records, skipping anything malformed."""
        entries: List[_ParsedEntry] = []
        for record in records:
            if not isinstance(record, dict):
                continue
            host = str(record.get("host", "")).strip().lower()
            if not host or len(host) > _MAX_HOST_LENGTH:
                continue
            if any(char in host for char in "/ \t\n\r@"):
                continue
            try:
                level = UrlVerdictLevel(
                    str(record.get("level", "")).strip().lower()
                )
            except ValueError:
                continue
            reason = str(record.get("reason") or _DEFAULT_REASON)[:200]
            entries.append((host, level, reason))
        return entries


async def threat_intel_feed_task(
    service: ThreatIntelFeedService,
    interval_seconds: Optional[int] = None,
) -> None:
    """Periodically ingest the external threat feed.

    The first iteration runs immediately so the reputation cache is
    warm, then polls at ``interval_seconds``. Blocking HTTP and database
    work run in a worker thread so the event loop is never blocked.
    """
    interval = (
        interval_seconds
        if interval_seconds is not None
        else get_settings().security_threat_feed_interval_seconds
    )
    while True:
        try:
            await asyncio.to_thread(service.ingest_once)
        except Exception as exc:
            logger.warning("threat feed ingest iteration failed: %s", exc)
        await asyncio.sleep(interval)


def build_threat_intel_feed_service() -> Optional[ThreatIntelFeedService]:
    """Assemble the feed service when a feed is configured.

    Returns None -- and therefore starts no background loop -- when the
    feed URL is empty or the Redis-backed reputation cache is
    unavailable.
    """
    settings = get_settings()
    if not settings.security_threat_feed_url.strip():
        return None
    client = create_redis_client()
    if client is None:
        logger.warning(
            "threat feed configured but redis is unreachable; "
            "feed ingestion disabled"
        )
        return None
    return ThreatIntelFeedService(ThreatIntelService(client))

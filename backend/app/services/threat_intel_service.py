"""Threat-intel URL reputation service (standard profile).

Verdicts are persisted in ``url_reputations`` (per host) and cached in
Redis for the hot path. Unknown hosts return None so callers can apply
their local rules. Recording is upsert-based: one current verdict per
host, with source and optional expiry.

Database access goes through an injectable session factory so the
service works both with request sessions and standalone lookups.
"""

import json
import logging
from datetime import datetime, timezone
from typing import Callable, Iterable, Optional, Tuple

import redis
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import UrlReputation
from app.schemas.security import UrlVerdict, UrlVerdictLevel

logger = logging.getLogger(__name__)

# One feed/review entry: (host, level, reason, source, expires_at).
ReputationEntry = Tuple[str, UrlVerdictLevel, str, str, Optional[datetime]]


class ThreatIntelService:
    """Host reputation lookup with Redis caching."""

    CACHE_PREFIX = "porten:urlrep"
    CACHE_TTL_SECONDS = 300

    def __init__(
        self,
        client: redis.Redis,
        session_factory: Callable[[], Session] = SessionLocal,
        cache_ttl_seconds: int = CACHE_TTL_SECONDS,
    ) -> None:
        self._client = client
        self._session_factory = session_factory
        self._cache_ttl = cache_ttl_seconds

    def get_reputation(self, host: str) -> Optional[UrlVerdict]:
        """Return the verdict for a host, or None when unknown.

        Redis failures fall through to the database; database failures
        return None (treated as unknown) rather than raising.
        """
        cached = self._cache_get(host)
        if cached is not None:
            return cached

        verdict = self._db_get(host)
        if verdict is not None:
            self._cache_set(host, verdict)
        return verdict

    def record_reputation(
        self,
        db: Session,
        host: str,
        level: UrlVerdictLevel,
        reason: str,
        source: str = "review",
        expires_at: Optional[datetime] = None,
    ) -> UrlReputation:
        """Upsert the verdict for a host and invalidate its cache."""
        record = self._upsert(db, host, level, reason, source, expires_at)
        db.commit()
        db.refresh(record)
        self._cache_delete(host)
        return record

    def record_reputations(
        self,
        db: Session,
        entries: Iterable[ReputationEntry],
    ) -> int:
        """Upsert several host verdicts in a single transaction.

        Cache entries are invalidated only after the commit, so readers
        never observe a cache miss against uncommitted rows.
        """
        hosts = []
        for host, level, reason, source, expires_at in entries:
            self._upsert(db, host, level, reason, source, expires_at)
            hosts.append(host)
        db.commit()
        for host in hosts:
            self._cache_delete(host)
        return len(hosts)

    def _upsert(
        self,
        db: Session,
        host: str,
        level: UrlVerdictLevel,
        reason: str,
        source: str,
        expires_at: Optional[datetime],
    ) -> UrlReputation:
        """Insert or update the reputation row (caller commits)."""
        record = db.query(UrlReputation).filter_by(host=host).first()
        if record:
            record.level = level.value
            record.reason = reason
            record.source = source
            record.expires_at = expires_at
        else:
            record = UrlReputation(
                host=host,
                level=level.value,
                reason=reason,
                source=source,
                expires_at=expires_at,
            )
            db.add(record)
        return record

    def _db_get(self, host: str) -> Optional[UrlVerdict]:
        db = self._session_factory()
        try:
            record = db.query(UrlReputation).filter_by(host=host).first()
        except Exception:
            logger.warning("url reputation db lookup failed", exc_info=True)
            return None
        finally:
            db.close()

        if record is None:
            return None
        if record.expires_at is not None and self._ensure_utc(
            record.expires_at
        ) < datetime.now(timezone.utc):
            return None
        return UrlVerdict(
            url=f"//{host}",
            level=UrlVerdictLevel(record.level),
            reason=record.reason,
        )

    def _cache_get(self, host: str) -> Optional[UrlVerdict]:
        try:
            raw = self._client.get(f"{self.CACHE_PREFIX}:{host}")
        except redis.RedisError:
            return None
        if not raw:
            return None
        try:
            data = json.loads(raw)
            return UrlVerdict(
                url=f"//{host}",
                level=UrlVerdictLevel(data["level"]),
                reason=data.get("reason"),
            )
        except (ValueError, KeyError):
            return None

    def _cache_set(self, host: str, verdict: UrlVerdict) -> None:
        try:
            self._client.set(
                f"{self.CACHE_PREFIX}:{host}",
                json.dumps(
                    {"level": verdict.level.value, "reason": verdict.reason}
                ),
                ex=self._cache_ttl,
            )
        except redis.RedisError:
            logger.warning("url reputation cache write failed", exc_info=True)

    def _cache_delete(self, host: str) -> None:
        try:
            self._client.delete(f"{self.CACHE_PREFIX}:{host}")
        except redis.RedisError:
            pass

    @staticmethod
    def _ensure_utc(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value

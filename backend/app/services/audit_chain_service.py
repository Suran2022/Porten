"""Tamper-evident audit log with hash chaining (design doc §9).

Every administrative and moderation action is appended here. Each row
carries the ``entry_hash`` of the previous row plus its own hash over
canonical row content, so altering any row breaks every subsequent
link. Combined with the forensic time anchor this forms the "process
evidence" layer of the four-layer fingerprint.

Privacy: rows store who/when/what-object/action only. Raw message
content and diary text are never persisted here.

Concurrency: appends are serialized with a MySQL/MariaDB advisory lock
(``GET_LOCK``) so two concurrent writers cannot fork the chain. The
lock is skipped on other dialects (e.g. SQLite in tests), where a
single-writer setup makes forking impossible.
"""

import hashlib
import json
import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models import AuditLog

logger = logging.getLogger(__name__)

# Serializes audit-chain appends on MySQL/MariaDB.
_CHAIN_LOCK_NAME = "porten_audit_chain"
_CHAIN_LOCK_TIMEOUT_SECONDS = 10


@dataclass
class ChainReport:
    """Outcome of verifying a range of the audit chain."""

    checked: int = 0
    valid: bool = True
    broken_at_id: Optional[int] = None
    errors: List[str] = field(default_factory=list)


class AuditChainError(RuntimeError):
    """Raised when an audit entry cannot be safely appended."""


def canonical_bytes(entry: dict) -> bytes:
    """Serialize an entry deterministically for hashing."""
    return json.dumps(
        entry, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")


def _ensure_utc(value: datetime) -> datetime:
    """Return ``value`` as an aware UTC datetime.

    Naive datetimes (e.g. read back from SQLite, which drops the
    offset) are treated as UTC; aware values are converted. This keeps
    hash computation stable regardless of how the timestamp round-
    tripped through the database.
    """
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def compute_entry_hash(
    *,
    actor_id: Optional[int],
    actor_role: Optional[str],
    action: str,
    target_type: Optional[str],
    target_id: Optional[str],
    summary: Optional[str],
    meta: Optional[dict],
    ip_hash: Optional[str],
    created_at: datetime,
    prev_hash: Optional[str],
) -> str:
    """Return the SHA-256 over the canonical entry content."""
    payload = {
        "actor_id": actor_id,
        "actor_role": actor_role,
        "action": action,
        "target_type": target_type,
        "target_id": target_id,
        "summary": summary,
        "meta": meta,
        "ip_hash": ip_hash,
        "created_at": _ensure_utc(created_at).isoformat(),
        "prev_hash": prev_hash,
    }
    return hashlib.sha256(canonical_bytes(payload)).hexdigest()


class AuditChainService:
    """Append-only, hash-chained audit log (design doc §9 chain layer)."""

    def append(
        self,
        db: Session,
        *,
        actor_id: Optional[int],
        action: str,
        actor_role: Optional[str] = None,
        target_type: Optional[str] = None,
        target_id: Optional[str] = None,
        summary: Optional[str] = None,
        meta: Optional[dict] = None,
        ip_hash: Optional[str] = None,
    ) -> AuditLog:
        """Append one chained entry and return it.

        Raises :class:`AuditChainError` when the chain lock cannot be
        acquired, so a caller must never silently skip auditing.
        """
        locked = self._acquire_lock(db)
        try:
            # FOR UPDATE is a no-op on dialects without row locks
            # (SQLite); the advisory lock covers MySQL/MariaDB.
            last = (
                db.query(AuditLog)
                .order_by(AuditLog.id.desc())
                .limit(1)
                .with_for_update()
                .first()
            )
            prev_hash = last.entry_hash if last else None
            # Hash and store second granularity: MySQL/MariaDB
            # ``datetime`` columns have no fractional-seconds precision,
            # so a hash over microseconds could never be recomputed
            # from the stored row. Ordering comes from the id anyway.
            created_at = datetime.now(timezone.utc).replace(microsecond=0)
            entry_hash = compute_entry_hash(
                actor_id=actor_id,
                actor_role=actor_role,
                action=action,
                target_type=target_type,
                target_id=target_id,
                summary=summary,
                meta=meta,
                ip_hash=ip_hash,
                created_at=created_at,
                prev_hash=prev_hash,
            )
            entry = AuditLog(
                actor_id=actor_id,
                actor_role=actor_role,
                action=action,
                target_type=target_type,
                target_id=target_id,
                summary=summary,
                meta=meta,
                ip_hash=ip_hash,
                prev_hash=prev_hash,
                entry_hash=entry_hash,
                created_at=created_at,
            )
            db.add(entry)
            db.commit()
            db.refresh(entry)
            return entry
        finally:
            if locked:
                self._release_lock(db)

    def verify_chain(
        self,
        db: Session,
        from_id: Optional[int] = None,
        to_id: Optional[int] = None,
    ) -> ChainReport:
        """Recompute every link in a range and report the first break.

        A row is broken when its stored ``entry_hash`` does not match
        the recomputed hash (content tampering) or when its
        ``prev_hash`` does not match the previous row's ``entry_hash``
        (deletion, insertion or reordering).
        """
        query = db.query(AuditLog).order_by(AuditLog.id.asc())
        if from_id is not None:
            query = query.filter(AuditLog.id >= from_id)
        if to_id is not None:
            query = query.filter(AuditLog.id <= to_id)
        rows = query.all()

        report = ChainReport(checked=len(rows))

        # A range that starts mid-chain must still chain to the entry
        # before ``from_id``; seed the linkage from that predecessor.
        previous_hash: Optional[str] = None
        if from_id is not None:
            predecessor = (
                db.query(AuditLog)
                .filter(AuditLog.id < from_id)
                .order_by(AuditLog.id.desc())
                .first()
            )
            previous_hash = predecessor.entry_hash if predecessor else None
        for row in rows:
            recomputed = compute_entry_hash(
                actor_id=row.actor_id,
                actor_role=row.actor_role,
                action=row.action,
                target_type=row.target_type,
                target_id=row.target_id,
                summary=row.summary,
                meta=row.meta,
                ip_hash=row.ip_hash,
                created_at=_ensure_utc(row.created_at),
                prev_hash=row.prev_hash,
            )
            if recomputed != row.entry_hash:
                report.valid = False
                report.broken_at_id = row.id
                report.errors.append(
                    f"entry {row.id}: content hash mismatch (tampered)"
                )
                break
            if row.prev_hash != previous_hash:
                report.valid = False
                report.broken_at_id = row.id
                report.errors.append(
                    f"entry {row.id}: prev_hash does not chain to previous entry"
                )
                break
            previous_hash = row.entry_hash
        return report

    def entries_for_subject(
        self,
        db: Session,
        target_type: str,
        target_id: str,
        limit: int = 100,
    ) -> List[AuditLog]:
        """Return recent audit entries for one evidence subject."""
        return (
            db.query(AuditLog)
            .filter(
                AuditLog.target_type == target_type,
                AuditLog.target_id == str(target_id),
            )
            .order_by(AuditLog.id.desc())
            .limit(limit)
            .all()
        )

    # -- internals -------------------------------------------------------

    def _acquire_lock(self, db: Session) -> bool:
        """Take the chain advisory lock on MySQL/MariaDB.

        Returns False (no lock) on dialects without ``GET_LOCK``; the
        caller then appends without serialization, which is safe only
        for single-writer setups (tests).
        """
        if db.bind.dialect.name != "mysql":
            return False
        result = db.execute(
            text("SELECT GET_LOCK(:name, :timeout)"),
            {"name": _CHAIN_LOCK_NAME, "timeout": _CHAIN_LOCK_TIMEOUT_SECONDS},
        ).scalar()
        if result != 1:
            raise AuditChainError(
                "could not acquire the audit chain lock; "
                "refusing to append an unserialized entry"
            )
        return True

    def _release_lock(self, db: Session) -> None:
        try:
            db.execute(text("SELECT RELEASE_LOCK(:name)"), {"name": _CHAIN_LOCK_NAME})
        except Exception:
            logger.warning("audit chain lock release failed", exc_info=True)


__all__ = [
    "AuditChainError",
    "AuditChainService",
    "ChainReport",
    "canonical_bytes",
    "compute_entry_hash",
]

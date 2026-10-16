"""Forensic record model (four-layer fingerprint, design doc §9).

Each record anchors one piece of evidence (a message, media file, diary
entry, or audit action) with:

- a content fingerprint (SHA-256, plus a perceptual hash for media) --
  only hashes are stored, never raw content;
- an RFC 3161 trusted-timestamp token proving *when* the hash existed
  (``tsa_token`` holds the raw DER bytes; ``tsa_status`` tracks the
  signing lifecycle and stays ``pending`` when no TSA is configured --
  absence is never forged);
- chain-anchor references for tamper-evidence;
- a custody log (append-only JSON entries: operator, time, object hash,
  action, before/after redacted snapshots) for chain-of-custody.

The ``verified`` flag records dual-person verification of the custody
process (design doc §10.1).
"""

from datetime import datetime, timezone
from typing import Any, Optional

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    Index,
    JSON,
    LargeBinary,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class ForensicRecord(Base):
    """A four-layer fingerprint record for one evidence subject."""

    __tablename__ = "forensic_records"

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True, index=True
    )
    subject_type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        index=True,
        comment="Evidence kind: message | media | diary | audit",
    )
    subject_id: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        comment="Identifier of the evidence subject",
    )
    content_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        comment="SHA-256 hex digest of the subject content",
    )
    hash_algorithm: Mapped[str] = mapped_column(
        String(20),
        default="sha256",
        nullable=False,
        comment="Digest algorithm used for content_hash",
    )
    perceptual_hash: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
        comment="Perceptual hash for media subjects (near-duplicate matching)",
    )
    tsa_token: Mapped[Optional[bytes]] = mapped_column(
        LargeBinary,
        nullable=True,
        comment="RFC 3161 TimeStampToken (DER); NULL while unsigned",
    )
    tsa_status: Mapped[str] = mapped_column(
        String(20),
        default="pending",
        nullable=False,
        comment="pending | signed | failed | unavailable",
    )
    tsa_requested_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    tsa_signed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    chain_anchor: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="External anchor reference (consortium chain / public chain tx)",
    )
    custody_log: Mapped[Optional[list[dict[str, Any]]]] = mapped_column(
        JSON,
        nullable=True,
        comment="Append-only custody entries (operator, time, action, snapshots)",
    )
    verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        comment="Whether custody was verified by two authorized people",
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

    __table_args__ = (
        Index("ix_forensic_records_subject", "subject_type", "subject_id"),
        Index("ix_forensic_records_tsa_status", "tsa_status"),
    )

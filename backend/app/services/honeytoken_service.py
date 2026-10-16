"""Honeytoken service: planted decoy credentials (design doc §5.5).

Honeytokens are fake credentials deployed where an attacker would
probe: decoy admin sessions, decoy API keys, decoy password-reset
links. Only the SHA-256 of a token is stored; any presentation of a
matching token is proof of compromise and raises a critical event.
Honeytokens are never valid for any real operation.

The service is deliberately dependency-free: recording a hit updates
counters in its own transaction and never raises, so callers on the
authentication hot path can check tokens without risking the request.
Event emission and edge blocking are the caller's concern (the decoy
router and the auth dependency), keeping this module testable in
isolation.
"""

import hashlib
import logging
import secrets
from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy.orm import Session

from app.models import Honeytoken
from app.utils.security import hash_ip

logger = logging.getLogger(__name__)

# Decoy categories an operator can plant.
TOKEN_TYPES = ("admin_session", "api_key", "reset_link")

# Length of the generated plaintext token (URL-safe, ~256 bits).
_TOKEN_BYTES = 32


def hash_token(token: str) -> str:
    """Return the SHA-256 hex digest used to look a token up.

    Unsalted on purpose: honeytokens are high-entropy random values,
    and the lookup must work without a per-row salt.
    """
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


class HoneytokenService:
    """Plant, look up and account for decoy credentials."""

    def plant(
        self,
        db: Session,
        *,
        token_type: str,
        label: Optional[str] = None,
        planted_by: Optional[int] = None,
    ) -> str:
        """Plant a new decoy and return its plaintext (shown once).

        Raises ``ValueError`` for an unknown token type; the caller is
        expected to validate before reaching this point.
        """
        if token_type not in TOKEN_TYPES:
            raise ValueError(
                f"unknown honeytoken type: {token_type}; "
                f"expected one of: {', '.join(TOKEN_TYPES)}"
            )
        plaintext = secrets.token_urlsafe(_TOKEN_BYTES)
        honeytoken = Honeytoken(
            token_hash=hash_token(plaintext),
            token_type=token_type,
            label=label,
            planted_by=planted_by,
        )
        db.add(honeytoken)
        db.commit()
        db.refresh(honeytoken)
        return plaintext

    def lookup(self, db: Session, token: str) -> Optional[Honeytoken]:
        """Return the active honeytoken matching ``token``, if any."""
        if not token:
            return None
        try:
            return (
                db.query(Honeytoken)
                .filter_by(token_hash=hash_token(token), active=True)
                .first()
            )
        except Exception:
            logger.warning("honeytoken lookup failed", exc_info=True)
            return None

    def register_hit(
        self, db: Session, honeytoken: Honeytoken, client_ip: str
    ) -> None:
        """Account for one presentation of a decoy credential.

        Commits on its own and never raises: a counter failure must
        not surface on the authentication path.
        """
        try:
            honeytoken.hit_count += 1
            honeytoken.last_hit_at = datetime.now(timezone.utc)
            honeytoken.last_hit_ip_hash = hash_ip(client_ip)
            db.commit()
        except Exception:
            db.rollback()
            logger.warning(
                "honeytoken hit accounting failed for %s",
                honeytoken.id,
                exc_info=True,
            )

    def revoke(self, db: Session, token_id: int) -> bool:
        """Deactivate a decoy; returns False when it does not exist."""
        honeytoken = db.get(Honeytoken, token_id)
        if honeytoken is None:
            return False
        honeytoken.active = False
        db.commit()
        return True

    def list_active(self, db: Session) -> List[Honeytoken]:
        """Return the currently deployed decoys (for the admin surface)."""
        return (
            db.query(Honeytoken)
            .filter_by(active=True)
            .order_by(Honeytoken.id.desc())
            .all()
        )


honeytoken_service = HoneytokenService()

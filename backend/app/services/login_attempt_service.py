"""Login attempt recording (behavior analysis input).

Every login attempt is recorded with a keyed, non-reversible hash of
the client IP so later behavior analysis can group and correlate
attempts without keeping raw addresses. Recording is best-effort:
failures are swallowed so a broken audit write never blocks login.
"""

import logging
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.models import LoginAttempt
from app.utils.security import hash_ip

logger = logging.getLogger(__name__)

# Reasons recorded on failed attempts.
REASON_BAD_CREDENTIALS = "bad_credentials"
REASON_UNKNOWN_USER = "unknown_user"


class LoginAttemptService:
    """Persist login attempts for behavior analysis and forensics."""

    def record(
        self,
        db: Session,
        email: str,
        ip: str,
        success: bool,
        user_id: Optional[int] = None,
        failure_reason: Optional[str] = None,
    ) -> None:
        """Record one attempt; never raises to the caller."""
        try:
            attempt = LoginAttempt(
                user_id=user_id,
                email=email,
                ip_hash=hash_ip(ip),
                success=success,
                failure_reason=failure_reason,
                created_at=datetime.now(timezone.utc),
            )
            db.add(attempt)
            db.commit()
        except SQLAlchemyError:
            db.rollback()
            logger.warning("login attempt recording failed", exc_info=True)


login_attempt_service = LoginAttemptService()

"""Security event recording service (lite profile).

The sink is defensive by design: recording a security event must never
break the business operation that triggered it, so every failure path
is swallowed and logged. Each event commits on its own so audit
evidence survives even when the triggering business operation is
rejected or rolled back afterwards.
"""

import logging
from typing import Optional

from sqlalchemy.orm import Session

from app.models import SecurityEvent

logger = logging.getLogger(__name__)


class SecurityEventService:
    """Persist security events to the security_events table."""

    def emit(
        self,
        db: Session,
        event_type: str,
        severity: str = "info",
        user_id: Optional[int] = None,
        detail: Optional[str] = None,
        meta: Optional[dict] = None,
    ) -> None:
        """Record a security event; never raises to business code.

        Events are committed on their own so audit evidence survives
        even when the triggering business operation is rejected or
        rolled back afterwards.
        """
        try:
            event = SecurityEvent(
                event_type=event_type,
                severity=severity,
                user_id=user_id,
                detail=detail,
                meta=meta,
            )
            db.add(event)
            db.commit()
        except Exception:
            db.rollback()
            # Audit recording is best-effort: a failure here must not
            # surface to the caller as a business error.
            logger.warning(
                "security event recording failed: type=%s severity=%s",
                event_type,
                severity,
                exc_info=True,
            )

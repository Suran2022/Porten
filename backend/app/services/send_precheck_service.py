"""Send-time pre-check orchestration (Pass 1, synchronous).

Implements the architecture doc's synchronous pre-check contract:

* Confirmed-level violations are blocked before the message is
  persisted (hard block, millisecond budget).
* If the checker itself fails, requests are rejected for the first
  ``FAIL_CLOSED_WINDOW_SECONDS`` ("security check in progress"); after
  that the check degrades to record-and-review so a prolonged security
  malfunction can never block communication.
* Blocked content and detected help signals are recorded as security
  events (metadata only -- raw content is never persisted).
"""

import logging
import threading
import time
from typing import Optional

from sqlalchemy.orm import Session

from app.schemas.security import ModerationDecision, ModerationResult
from app.security.protocols import ContentModerator, SecurityEventSink
from app.security.singleton import get_security_capabilities

logger = logging.getLogger(__name__)

# Requests are rejected while the checker keeps failing for this long;
# afterwards the pre-check degrades to record-and-review so a prolonged
# security malfunction can never block communication.
FAIL_CLOSED_WINDOW_SECONDS = 30


class PrecheckUnavailable(Exception):
    """Raised while the pre-check is failing inside the fail-closed window."""


class SendPrecheckService:
    """Orchestrate the synchronous send-time pre-check."""

    def __init__(
        self,
        content_moderator: ContentModerator,
        event_sink: SecurityEventSink,
    ) -> None:
        # Depends on the capability protocols only, so profile swaps
        # need no change here.
        self._content_moderator = content_moderator
        self._event_sink = event_sink
        self._first_failure_at: Optional[float] = None
        self._lock = threading.Lock()

    def precheck(
        self,
        db: Session,
        user_id: int,
        content: str,
        message_type: str,
    ) -> ModerationResult:
        """Run the synchronous pre-check for one outgoing message.

        Returns the moderation result when a decision was reached.
        Raises :class:`PrecheckUnavailable` while the checker keeps
        failing inside the fail-closed window.
        """
        try:
            result = self._content_moderator.check(
                content, message_type
            )
        except Exception as exc:
            logger.warning("send pre-check failed", exc_info=True)
            return self._handle_failure(db, user_id, message_type, exc)

        self._note_success()

        if result.decision == ModerationDecision.BLOCK:
            self._event_sink.emit(
                db,
                event_type="message_blocked",
                severity="warning",
                user_id=user_id,
                detail=f"blocked category: {result.category}",
                meta={
                    "category": result.category,
                    "message_type": message_type,
                },
            )
        elif result.category == "help_signal":
            # Never blocked; recorded so care resources can follow up.
            self._event_sink.emit(
                db,
                event_type="help_signal_detected",
                severity="info",
                user_id=user_id,
                detail="help signal detected in outgoing message",
                meta={"message_type": message_type},
            )

        return result

    def _handle_failure(
        self,
        db: Session,
        user_id: int,
        message_type: str,
        exc: Exception,
    ) -> ModerationResult:
        """Apply the fail-closed window, then degrade to record-and-review."""
        now = time.monotonic()
        with self._lock:
            if self._first_failure_at is None:
                self._first_failure_at = now
            first_failure = self._first_failure_at
            elapsed = now - first_failure

        if elapsed < FAIL_CLOSED_WINDOW_SECONDS:
            raise PrecheckUnavailable(
                "security check unavailable; fail-closed window active"
            ) from exc

        # Degraded mode: allow the message and queue it for later review.
        self._event_sink.emit(
            db,
            event_type="precheck_degraded",
            severity="warning",
            user_id=user_id,
            detail="pre-check failed; message allowed for later review",
            meta={"message_type": message_type},
        )
        return ModerationResult(
            decision=ModerationDecision.ALLOW,
            category="precheck_degraded",
            reason="pre-check unavailable; routed to asynchronous review",
        )

    def _note_success(self) -> None:
        """Reset the failure window after a successful check."""
        with self._lock:
            self._first_failure_at = None


_capabilities = get_security_capabilities()
send_precheck_service = SendPrecheckService(
    _capabilities.content_moderator,
    _capabilities.event_sink,
)

"""Behavior analysis service (standard profile, UEBA layer 1).

Three detection layers, mirroring the architecture doc:

1. **Individual baseline** -- today's activity against the user's own
   trailing history (mean +/- sigma); catches accounts that suddenly
   behave unlike themselves.
2. **Cohort comparison** -- recipient-side crowding: many accounts
   whose *first ever* message in a conversation falls inside the same
   window, the classic scam-funnel shape.
3. **Absolute hard limits** -- fixed ceilings no baseline can excuse.

Layers combine into a 0..1 risk score; callers decide what to do with
it (record, route to review, restrict). Nothing here blocks sending:
assessment runs asynchronously after the message is stored.
"""

import logging
import statistics
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import Message

logger = logging.getLogger(__name__)


class BehaviorAnalyzer:
    """Risk assessment for user actions."""

    # Individual baseline
    BASELINE_DAYS = 28
    BASELINE_SIGMA = 3.0
    BASELINE_MIN_SAMPLE = 5
    # Cohort comparison
    COHORT_WINDOW_HOURS = 24
    COHORT_NEW_SENDER_THRESHOLD = 3
    # Absolute hard limits
    HARD_LIMIT_MESSAGES_PER_HOUR = 500
    # Scoring
    SIGNAL_WEIGHTS = {
        "baseline_spike": 0.4,
        "cohort_crowding": 0.4,
        "hard_limit": 0.6,
    }
    ALERT_THRESHOLD = 0.7

    def assess(
        self,
        db: Session,
        user_id: int,
        action: str,
        context: Optional[dict] = None,
    ) -> Optional[dict]:
        """Return a risk assessment dict, or None when nothing notable."""
        if action != "message_send":
            return None

        signals: list[str] = []
        signals.extend(self._baseline_signals(db, user_id))
        signals.extend(self._cohort_signals(db, user_id, context))
        signals.extend(self._hard_limit_signals(db, user_id))

        if not signals:
            return None

        score = min(
            1.0, sum(self.SIGNAL_WEIGHTS.get(name, 0.2) for name in signals)
        )
        if score >= self.ALERT_THRESHOLD:
            level = "high"
        elif score >= 0.4:
            level = "medium"
        else:
            level = "low"

        return {
            "score": round(score, 2),
            "level": level,
            "signals": signals,
        }

    def _baseline_signals(self, db: Session, user_id: int) -> list[str]:
        """Flag activity far above the user's own trailing history.

        Today's bucket is compared against the historical buckets only:
        including the spike in the distribution would inflate the
        deviation and make single-day spikes undetectable.
        """
        since = datetime.now(timezone.utc) - timedelta(days=self.BASELINE_DAYS)
        rows = (
            db.query(
                func.date(Message.created_at).label("day"),
                func.count().label("count"),
            )
            .filter(Message.sender_id == user_id, Message.created_at >= since)
            .group_by(func.date(Message.created_at))
            .order_by(func.date(Message.created_at))
            .all()
        )
        if len(rows) < 2:
            return []

        history = [row.count for row in rows[:-1]]
        latest = rows[-1].count
        if len(history) < self.BASELINE_MIN_SAMPLE:
            return []

        mean = statistics.mean(history)
        stdev = statistics.pstdev(history) or 1.0
        if latest > mean + self.BASELINE_SIGMA * stdev and latest > 2 * mean:
            return ["baseline_spike"]
        return []

    def _cohort_signals(
        self, db: Session, user_id: int, context: Optional[dict]
    ) -> list[str]:
        """Flag crowding: many first-time senders converging at once.

        "First-time" means the sender's earliest message in the
        conversation falls inside the window, so the time filter must
        not be applied before grouping -- the HAVING clause does the
        first-message test.
        """
        conversation_id = (context or {}).get("conversation_id")
        if not conversation_id:
            return []

        since = datetime.now(timezone.utc) - timedelta(
            hours=self.COHORT_WINDOW_HOURS
        )
        new_senders = (
            db.query(Message.sender_id)
            .filter(Message.conversation_id == conversation_id)
            .group_by(Message.sender_id)
            .having(func.min(Message.created_at) >= since)
            .all()
        )
        sender_ids = {row.sender_id for row in new_senders}
        if len(sender_ids) >= self.COHORT_NEW_SENDER_THRESHOLD and (
            user_id in sender_ids
        ):
            return ["cohort_crowding"]
        return []

    def _hard_limit_signals(self, db: Session, user_id: int) -> list[str]:
        """Flag volumes no legitimate baseline can explain."""
        since = datetime.now(timezone.utc) - timedelta(hours=1)
        count = (
            db.query(func.count())
            .filter(Message.sender_id == user_id, Message.created_at >= since)
            .scalar()
        )
        if count and count > self.HARD_LIMIT_MESSAGES_PER_HOUR:
            return ["hard_limit"]
        return []

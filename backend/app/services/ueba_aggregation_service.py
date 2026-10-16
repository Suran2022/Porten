"""UEBA aggregation service (design doc §5.3.2, advanced profile).

Periodically rolls up metadata-only per-entity risk signals into the
``ueba_entity_scores`` table for the admin triage queue:

* **security events** -- severity-weighted count of recorded events;
* **message burst** -- volume and distinct conversations against hard
  ceilings (the low-false-positive layer);
* **new-conversation ratio** -- conversations first messaged in the
  window versus the trailing history (scam-funnel shape);
* **failed logins** -- failed authentication attempts.

Scores combine additively into 0-100 with a four-level mapping
(low / medium / high / critical, the 观察/挑战/降级/冻结待审 tiers).
No message content is ever read or stored: every query touches ids,
counts and timestamps only.

Windows are aligned to fixed boundaries and rows are upserted per
(entity, window) via the unique constraint, so re-running an
aggregation is idempotent. The job never blocks the business path:
it runs in its own background task and swallows iteration failures.
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.config import get_settings
from app.database import SessionLocal
from app.models import LoginAttempt, Message, SecurityEvent, UebaEntityScore

logger = logging.getLogger(__name__)


class UebaAggregationService:
    """Windowed roll-up of per-user risk signals."""

    # Severity weights for recorded security events.
    SEVERITY_WEIGHTS = {"info": 2, "warning": 6, "critical": 18}
    # Hard ceilings (the absolute-limits layer): message volume and
    # distinct conversation spread inside one window.
    BURST_MESSAGES = 200
    BURST_CONVERSATIONS = 50
    # Failed logins before the signal starts contributing.
    FAILED_LOGIN_FLOOR = 3
    # Per-signal caps (sums are clamped to 100 anyway).
    EVENT_CAP = 40
    BURST_CAP = 35
    NEW_CONVERSATION_CAP = 20
    LOGIN_CAP = 25
    # Trailing history used for the new-conversation ratio.
    HISTORY_DAYS = 28
    # Level thresholds.
    LEVEL_MEDIUM = 30
    LEVEL_HIGH = 60
    LEVEL_CRITICAL = 85

    def aggregate_recent(self, db: Session) -> int:
        """Aggregate the current window; returns the rows written.

        The window is aligned to a fixed boundary so repeated runs
        update the same rows instead of growing the table.
        """
        settings = get_settings()
        window_minutes = settings.security_ueba_window_minutes
        now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
        # Floor ``now`` to the window boundary, then score the window
        # that just completed: aggregating a partially elapsed window
        # would churn scores that are still moving.
        end = now - (now - datetime.min.replace(tzinfo=timezone.utc)) % timedelta(
            minutes=window_minutes
        )
        start = end - timedelta(minutes=window_minutes)
        return self.aggregate_window(db, start, end)

    def aggregate_window(
        self, db: Session, window_start: datetime, window_end: datetime
    ) -> int:
        """Score every active entity over one window (idempotent)."""
        if window_end <= window_start:
            raise ValueError("window_end must be after window_start")

        event_points, event_detail = self._event_signals(db, window_start, window_end)
        burst_points, burst_detail = self._burst_signals(db, window_start, window_end)
        new_points, new_detail = self._new_conversation_signals(
            db, window_start, window_end
        )
        login_points, login_detail = self._login_signals(db, window_start, window_end)

        candidates: dict[int, dict] = {}
        for user_id in (
            set(event_detail)
            | set(burst_detail)
            | set(new_detail)
            | set(login_detail)
        ):
            signals = {
                "security_events": event_points.get(user_id, 0),
                "message_burst": burst_points.get(user_id, 0),
                "new_conversations": new_points.get(user_id, 0),
                "failed_logins": login_points.get(user_id, 0),
            }
            details = {
                "security_events": event_detail.get(user_id),
                "message_burst": burst_detail.get(user_id),
                "new_conversations": new_detail.get(user_id),
                "failed_logins": login_detail.get(user_id),
            }
            score = min(100, sum(signals.values()))
            candidates[user_id] = {
                "score": score,
                "level": self._level(score),
                "signals": signals,
                "top_reasons": self._top_reasons(signals, details),
            }

        written = 0
        for user_id, payload in candidates.items():
            self._upsert(db, "user", str(user_id), window_start, window_end, payload)
            written += 1
        db.commit()
        return written

    def latest_scores(
        self, db: Session, *, level: Optional[str] = None, limit: int = 50
    ) -> list:
        """Recent scores for the admin triage queue (newest first)."""
        query = db.query(UebaEntityScore).order_by(
            UebaEntityScore.window_start.desc(), UebaEntityScore.score.desc()
        )
        if level is not None:
            query = query.filter_by(level=level)
        return query.limit(limit).all()

    # -- signal sources -----------------------------------------------------

    def _event_signals(self, db: Session, start: datetime, end: datetime):
        """Severity-weighted security events per user."""
        rows = (
            db.query(
                SecurityEvent.user_id,
                SecurityEvent.severity,
                func.count(SecurityEvent.id),
            )
            .filter(
                SecurityEvent.created_at >= start,
                SecurityEvent.created_at < end,
                SecurityEvent.user_id.isnot(None),
            )
            .group_by(SecurityEvent.user_id, SecurityEvent.severity)
            .all()
        )
        points: dict[int, int] = {}
        detail: dict[int, dict] = {}
        for user_id, severity, count in rows:
            weight = self.SEVERITY_WEIGHTS.get(severity, 2)
            points[user_id] = points.get(user_id, 0) + weight * count
            per_type = detail.setdefault(user_id, {})
            per_type[severity] = per_type.get(severity, 0) + count
        return {
            user_id: min(self.EVENT_CAP, value) for user_id, value in points.items()
        }, detail

    def _burst_signals(self, db: Session, start: datetime, end: datetime):
        """Message volume and conversation spread against hard ceilings."""
        rows = (
            db.query(
                Message.sender_id,
                func.count(Message.id),
                func.count(func.distinct(Message.conversation_id)),
            )
            .filter(Message.created_at >= start, Message.created_at < end)
            .group_by(Message.sender_id)
            .all()
        )
        points: dict[int, int] = {}
        detail: dict[int, dict] = {}
        for user_id, messages, conversations in rows:
            detail[user_id] = {"messages": messages, "conversations": conversations}
            value = 0
            if messages > self.BURST_MESSAGES:
                value += min(25, int((messages - self.BURST_MESSAGES) / 10))
            if conversations > self.BURST_CONVERSATIONS:
                value += min(10, (conversations - self.BURST_CONVERSATIONS) // 2)
            points[user_id] = min(self.BURST_CAP, value)
        return points, detail

    def _new_conversation_signals(
        self, db: Session, start: datetime, end: datetime
    ):
        """Conversations first messaged in the window vs trailing history."""
        window_pairs = (
            db.query(Message.sender_id, Message.conversation_id)
            .filter(Message.created_at >= start, Message.created_at < end)
            .distinct()
            .all()
        )
        senders = list({sender for sender, _ in window_pairs})
        history_start = start - timedelta(days=self.HISTORY_DAYS)
        known: dict[int, set] = {}
        if senders:
            history_pairs = (
                db.query(Message.sender_id, Message.conversation_id)
                .filter(
                    Message.created_at >= history_start,
                    Message.created_at < start,
                    Message.sender_id.in_(senders),
                )
                .distinct()
                .all()
            )
            for sender, conversation_id in history_pairs:
                known.setdefault(sender, set()).add(conversation_id)

        points: dict[int, int] = {}
        detail: dict[int, dict] = {}
        conversations_by_sender: dict[int, set] = {}
        for sender, conversation_id in window_pairs:
            conversations_by_sender.setdefault(sender, set()).add(conversation_id)
        for user_id, conversations in conversations_by_sender.items():
            seen = known.get(user_id, set())
            new_count = len(conversations - seen)
            detail[user_id] = {
                "conversations": len(conversations),
                "previously_seen": len(conversations) - new_count,
            }
            if not seen and len(conversations) <= 10:
                # A brand-new account has no history: the observation
                # period records but does not punish.
                points[user_id] = 0
            else:
                ratio = new_count / len(conversations) if conversations else 0.0
                points[user_id] = min(
                    self.NEW_CONVERSATION_CAP, int(ratio * self.NEW_CONVERSATION_CAP)
                )
        return points, detail

    def _login_signals(self, db: Session, start: datetime, end: datetime):
        """Failed login attempts per account."""
        rows = (
            db.query(LoginAttempt.user_id, func.count(LoginAttempt.id))
            .filter(
                LoginAttempt.created_at >= start,
                LoginAttempt.created_at < end,
                LoginAttempt.user_id.isnot(None),
                LoginAttempt.success.is_(False),
            )
            .group_by(LoginAttempt.user_id)
            .all()
        )
        points: dict[int, int] = {}
        detail: dict[int, dict] = {}
        for user_id, failures in rows:
            detail[user_id] = {"failures": failures}
            if failures >= self.FAILED_LOGIN_FLOOR:
                points[user_id] = min(
                    self.LOGIN_CAP,
                    (failures - self.FAILED_LOGIN_FLOOR + 1) * 5,
                )
        return points, detail

    # -- scoring helpers ------------------------------------------------------

    def _level(self, score: int) -> str:
        if score >= self.LEVEL_CRITICAL:
            return "critical"
        if score >= self.LEVEL_HIGH:
            return "high"
        if score >= self.LEVEL_MEDIUM:
            return "medium"
        return "low"

    def _top_reasons(self, signals: dict, details: dict) -> list:
        """Top contributing signals as redacted, non-content reasons."""
        contributing = sorted(
            (item for item in signals.items() if item[1] > 0),
            key=lambda item: item[1],
            reverse=True,
        )
        reasons = []
        for name, value in contributing[:3]:
            reasons.append(
                {"signal": name, "points": value, "detail": details.get(name)}
            )
        return reasons

    def _upsert(
        self,
        db: Session,
        entity_type: str,
        entity_id: str,
        window_start: datetime,
        window_end: datetime,
        payload: dict,
    ) -> None:
        """Write one score row; re-runs replace the same window."""
        row = (
            db.query(UebaEntityScore)
            .filter_by(
                entity_type=entity_type,
                entity_id=entity_id,
                window_start=window_start,
            )
            .first()
        )
        if row is None:
            row = UebaEntityScore(
                entity_type=entity_type,
                entity_id=entity_id,
                window_start=window_start,
                window_end=window_end,
            )
            db.add(row)
        row.score = payload["score"]
        row.level = payload["level"]
        row.signals = payload["signals"]
        row.top_reasons = payload["top_reasons"]


async def ueba_aggregation_task(
    service: UebaAggregationService, interval_seconds: int
) -> None:
    """Background loop: aggregate windows until the process shuts down.

    Every iteration failure is swallowed so the loop can never die on
    a transient database problem.
    """
    while True:
        try:
            db = SessionLocal()
            try:
                aggregated = service.aggregate_recent(db)
                if aggregated:
                    logger.info("ueba aggregated %d entities", aggregated)
            finally:
                db.close()
        except Exception:
            logger.warning("ueba aggregation iteration failed", exc_info=True)
        await asyncio.sleep(interval_seconds)


ueba_aggregation_service = UebaAggregationService()

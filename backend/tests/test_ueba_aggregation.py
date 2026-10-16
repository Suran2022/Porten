"""Tests for the UEBA aggregation service (design doc §5.3.2).

Signals are exercised through in-memory SQLite: security events,
message volume, conversation spread, failed logins and the composite
scoring/idempotency contract.
"""

import asyncio
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import Integer, create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import get_settings
from app.models import (
    LoginAttempt,
    Message,
    SecurityEvent,
    UebaEntityScore,
)
from app.services.ueba_aggregation_service import (
    UebaAggregationService,
    ueba_aggregation_task,
)


@pytest.fixture(autouse=True)
def _restore_settings():
    """Snapshot the settings keys touched by this module."""
    settings = get_settings()
    keys = ("security_ueba_window_minutes",)
    snapshot = {key: getattr(settings, key) for key in keys}
    yield
    for key, value in snapshot.items():
        setattr(settings, key, value)


@pytest.fixture()
def settings():
    return get_settings()


@pytest.fixture()
def db_session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    # BigInteger primary keys do not autoincrement on SQLite (rowid
    # alias); production MySQL is unaffected by the temporary retype.
    swapped = []
    for table in (
        LoginAttempt.__table__,
        Message.__table__,
        SecurityEvent.__table__,
        UebaEntityScore.__table__,
    ):
        column = table.c["id"]
        swapped.append((column, column.type))
        column.type = Integer()
    for table in (
        LoginAttempt.__table__,
        Message.__table__,
        SecurityEvent.__table__,
        UebaEntityScore.__table__,
    ):
        table.create(engine)
    for column, original in swapped:
        column.type = original
    factory = sessionmaker(bind=engine)
    session = factory()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture()
def service():
    return UebaAggregationService()


def _window():
    start = datetime(2026, 10, 15, 12, 0, tzinfo=timezone.utc)
    return start, start + timedelta(minutes=60)


def _msg(user_id, conversation_id, created_at):
    return Message(
        sender_id=user_id,
        conversation_id=conversation_id,
        content="x",
        message_type="text",
        created_at=created_at,
    )


class TestEventSignals:
    """Severity-weighted security events."""

    def test_severity_weights_and_cap(self, db_session, service):
        start, end = _window()
        for _ in range(3):
            db_session.add(
                SecurityEvent(
                    event_type="login_failed",
                    severity="warning",
                    user_id=1,
                    created_at=start + timedelta(minutes=5),
                )
            )
        # 6 * 3 + 18 = 36 points, below the cap.
        db_session.add(
            SecurityEvent(
                event_type="honeypot_honeytoken_presented",
                severity="critical",
                user_id=1,
                created_at=start + timedelta(minutes=6),
            )
        )
        db_session.commit()

        points, detail = service._event_signals(db_session, start, end)
        assert points[1] == 3 * service.SEVERITY_WEIGHTS["warning"] + service.SEVERITY_WEIGHTS["critical"]
        assert detail[1] == {"warning": 3, "critical": 1}

    def test_events_without_user_are_ignored(self, db_session, service):
        start, end = _window()
        db_session.add(
            SecurityEvent(
                event_type="honeypot_endpoint_hit",
                severity="high",
                user_id=None,
                created_at=start,
            )
        )
        db_session.commit()
        points, _ = service._event_signals(db_session, start, end)
        assert points == {}


class TestBurstSignals:
    """Message volume and conversation spread against hard ceilings."""

    def test_below_ceiling_scores_zero(self, db_session, service):
        start, end = _window()
        for index in range(30):
            db_session.add(_msg(1, index + 1, start + timedelta(minutes=index % 60)))
        db_session.commit()
        points, detail = service._burst_signals(db_session, start, end)
        assert points[1] == 0
        assert detail[1] == {"messages": 30, "conversations": 30}

    def test_volume_burst_contributes(self, db_session, service):
        start, end = _window()
        for index in range(260):  # 60 over the ceiling
            db_session.add(_msg(1, 1, start + timedelta(seconds=index)))
        db_session.commit()
        points, detail = service._burst_signals(db_session, start, end)
        # 60 extra messages / 10 = 6 points.
        assert points[1] == 6
        assert detail[1]["messages"] == 260

    def test_conversation_spread_contributes(self, db_session, service):
        start, end = _window()
        for index in range(60):  # 10 conversations over the ceiling
            db_session.add(_msg(1, index + 1, start))
        db_session.commit()
        points, _ = service._burst_signals(db_session, start, end)
        assert points[1] == 5  # (60 - 50) // 2

    def test_burst_points_are_capped(self, db_session, service):
        start, end = _window()
        for index in range(1500):
            db_session.add(_msg(1, index + 1, start))
        db_session.commit()
        points, _ = service._burst_signals(db_session, start, end)
        assert points[1] == service.BURST_CAP


class TestNewConversationSignals:
    """Conversations first messaged in the window vs trailing history."""

    def test_quiet_new_account_is_not_punished(self, db_session, service):
        start, end = _window()
        # No history at all, small volume: observation period rule.
        for index in range(5):
            db_session.add(_msg(1, index + 1, start))
        db_session.commit()
        points, detail = service._new_conversation_signals(db_session, start, end)
        assert points[1] == 0
        assert detail[1] == {"conversations": 5, "previously_seen": 0}

    def test_history_reduces_the_ratio(self, db_session, service):
        start, end = _window()
        history_start = start - timedelta(days=service.HISTORY_DAYS)
        for index in range(40):
            db_session.add(_msg(1, index + 1, history_start + timedelta(days=1)))
        # 40 known conversations, 10 new ones in the window.
        for index in range(50):
            db_session.add(_msg(1, index + 1, start + timedelta(minutes=1)))
        db_session.commit()
        points, detail = service._new_conversation_signals(db_session, start, end)
        assert detail[1] == {"conversations": 50, "previously_seen": 40}
        assert points[1] == int(0.2 * service.NEW_CONVERSATION_CAP)

    def test_pure_scam_funnel_scores_max(self, db_session, service):
        start, end = _window()
        # One known conversation in history, then ten brand-new ones:
        # a 100% new-conversation ratio.
        db_session.add(_msg(1, 1, start - timedelta(days=10)))
        for index in range(11, 21):
            db_session.add(_msg(1, index, start + timedelta(minutes=1)))
        db_session.commit()
        points, _ = service._new_conversation_signals(db_session, start, end)
        assert points[1] == service.NEW_CONVERSATION_CAP


class TestLoginSignals:
    """Failed logins contribute above the floor only."""

    def test_below_floor_scores_zero(self, db_session, service):
        start, end = _window()
        for _ in range(2):
            db_session.add(
                LoginAttempt(
                    user_id=1,
                    email="a@x.test",
                    ip_hash="h",
                    success=False,
                    created_at=start,
                )
            )
        db_session.commit()
        points, _ = service._login_signals(db_session, start, end)
        assert points == {}

    def test_failures_scale_and_cap(self, db_session, service):
        start, end = _window()
        for _ in range(8):
            db_session.add(
                LoginAttempt(
                    user_id=1,
                    email="a@x.test",
                    ip_hash="h",
                    success=False,
                    created_at=start,
                )
            )
        db_session.commit()
        points, detail = service._login_signals(db_session, start, end)
        expected = min(
            service.LOGIN_CAP, (8 - service.FAILED_LOGIN_FLOOR + 1) * 5
        )
        assert points[1] == expected
        assert detail[1] == {"failures": 8}


class TestAggregation:
    """Window roll-up, idempotency and scoring composition."""

    def test_composite_score_and_level(self, db_session, service):
        start, end = _window()
        db_session.add(
            SecurityEvent(
                event_type="waf_block",
                severity="critical",
                user_id=1,
                created_at=start,
            )
        )
        for _ in range(6):
            db_session.add(
                LoginAttempt(
                    user_id=1,
                    email="a@x.test",
                    ip_hash="h",
                    success=False,
                    created_at=start,
                )
            )
        db_session.commit()

        assert service.aggregate_window(db_session, start, end) == 1
        row = db_session.query(UebaEntityScore).one()
        assert row.entity_type == "user"
        assert row.entity_id == "1"
        expected = min(100, service.SEVERITY_WEIGHTS["critical"] + 20)
        assert row.score == expected
        assert row.level == service._level(expected)
        assert set(row.signals) == {
            "security_events",
            "message_burst",
            "new_conversations",
            "failed_logins",
        }
        assert row.top_reasons[0]["signal"] == "failed_logins"
        # SQLite drops the tzinfo on read-back; the instant is UTC.
        stored_end = row.window_end
        if stored_end.tzinfo is None:
            stored_end = stored_end.replace(tzinfo=timezone.utc)
        assert stored_end == end

    def test_rerun_is_idempotent(self, db_session, service):
        start, end = _window()
        db_session.add(
            SecurityEvent(
                event_type="x", severity="info", user_id=1, created_at=start
            )
        )
        db_session.commit()
        assert service.aggregate_window(db_session, start, end) == 1
        assert service.aggregate_window(db_session, start, end) == 1
        assert db_session.query(UebaEntityScore).count() == 1

    def test_quiet_users_are_not_scored(self, db_session, service):
        start, end = _window()
        assert service.aggregate_window(db_session, start, end) == 0
        assert db_session.query(UebaEntityScore).count() == 0

    def test_reversed_window_raises(self, db_session, service):
        start, end = _window()
        with pytest.raises(ValueError):
            service.aggregate_window(db_session, end, start)

    def test_latest_scores_filter(self, db_session, service):
        start, end = _window()
        db_session.add(
            SecurityEvent(
                event_type="x", severity="critical", user_id=1, created_at=start
            )
        )
        service.aggregate_window(db_session, start, end)
        assert len(service.latest_scores(db_session)) == 1
        assert service.latest_scores(db_session, level="critical") == []
        assert (
            len(service.latest_scores(db_session, level=service._level(
                service.SEVERITY_WEIGHTS["critical"]
            )))
            == 1
        )

    def test_aggregate_recent_uses_aligned_windows(self, db_session, service, settings):
        settings.security_ueba_window_minutes = 60
        # No data: the run writes nothing but must not raise.
        assert service.aggregate_recent(db_session) == 0


class TestAggregationTask:
    """The background loop survives iteration failures."""

    def test_loop_runs_iterations_and_survives_errors(self):
        calls = []

        class _Stub:
            def aggregate_recent(self, db):
                calls.append(1)
                if len(calls) == 1:
                    raise RuntimeError("boom")
                return 1

        async def _run():
            task = asyncio.create_task(
                ueba_aggregation_task(_Stub(), interval_seconds=0.01)
            )
            await asyncio.sleep(0.08)
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass

        asyncio.run(_run())
        assert len(calls) >= 2

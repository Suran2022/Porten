"""Tests for the schedule / trip / note services.

In-memory SQLite carries the users + feature tables; MySQL-only column
types are temporarily retyped (same pattern as test_approval.py).
"""

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import Integer, Text, create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.models import Friendship, Note, Schedule, Trip, User
from app.schemas.note import NoteCreate, NoteUpdate
from app.schemas.schedule import ScheduleCreate, ScheduleUpdate
from app.schemas.trip import TripCreate
from app.services import NoteService, ScheduleService, TripService


@pytest.fixture()
def db_session():
    """In-memory SQLite with users/schedules/trips/notes tables."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    swapped = []
    for table in (
        User.__table__,
        Friendship.__table__,
        Schedule.__table__,
        Trip.__table__,
        Note.__table__,
    ):
        column = table.c["id"]
        swapped.append((column, column.type))
        column.type = Integer()
    for name in ("avatar_url", "background_url"):
        column = User.__table__.c[name]
        swapped.append((column, column.type))
        column.type = Text()
    for table in (
        User.__table__,
        Friendship.__table__,
        Schedule.__table__,
        Trip.__table__,
        Note.__table__,
    ):
        table.create(engine)
    for column, original in swapped:
        column.type = original

    session = sessionmaker(bind=engine)()
    user = User(
        porten_id="PB0001",
        email="tester@porten.app",
        nickname="测试",
        password_hash="x",
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    yield session
    session.close()


# ---------------------------------------------------------------- schedules


def test_schedule_response_has_exactly_mock_fields(db_session: Session):
    user = db_session.query(User).first()
    schedule = ScheduleService().create_schedule(
        db_session,
        user=user,
        payload=ScheduleCreate(
            date="2026-10-20",
            start_time="09:30",
            end_time="10:30",
            title="体检",
            detail="空腹",
            category="daily",
            place="市医院",
            participant_ids=[1003, 1005],
            source="form",
        ),
    )
    assert set(schedule.model_dump().keys()) == {
        "id",
        "date",
        "start_time",
        "end_time",
        "title",
        "detail",
        "category",
        "related_type",
        "related_id",
        "place",
        "participant_ids",
        "color",
        "source",
    }
    assert schedule.color in {"pink", "coffee", "blue"}
    assert schedule.participant_ids == [1003, 1005]


def test_schedule_update_only_overwrites_provided_fields(db_session: Session):
    user = db_session.query(User).first()
    service = ScheduleService()
    created = service.create_schedule(
        db_session,
        user=user,
        payload=ScheduleCreate(
            date="2026-10-20", start_time="09:30", source="form"
        ),
    )
    updated = service.update_schedule(
        db_session, user=user, schedule_id=created.id, payload=ScheduleUpdate(title="复检")
    )
    assert updated.title == "复检"
    assert updated.start_time == "09:30"
    assert updated.source == "form"


def test_schedule_update_missing_raises(db_session: Session):
    user = db_session.query(User).first()
    with pytest.raises(ValueError):
        ScheduleService().update_schedule(
            db_session, user=user, schedule_id=999, payload=ScheduleUpdate(title="x")
        )


def test_schedule_related_candidates_shape(db_session: Session):
    user = db_session.query(User).first()
    related = ScheduleService().related_candidates(db_session, user=user)
    assert related.trips == []
    assert related.agreements == []
    assert related.comrades == []


# -------------------------------------------------------------------- trips


def _create_trip(db_session: Session, user: User, hours_ahead: float) -> object:
    return TripService().create_trip(
        db_session,
        user=user,
        payload=TripCreate(
            departure_city="广州",
            departure_airport="白云机场",
            departure_at=datetime.now(timezone.utc) + timedelta(hours=hours_ahead),
            arrival_city="大连",
            arrival_airport="周水子机场",
            airline="四川航空",
        ),
    )


def test_trip_response_has_exactly_mock_fields(db_session: Session):
    user = db_session.query(User).first()
    trip = _create_trip(db_session, user, hours_ahead=50)
    assert set(trip.model_dump().keys()) == {
        "title",
        "departure_city",
        "departure_airport",
        "departure_time",
        "arrival_city",
        "arrival_airport",
        "arrival_time",
        "transfer_type",
        "airline",
        "airline_icon",
        "tips",
    }
    assert trip.transfer_type == "直达"
    assert trip.airline_icon == "assets/icons/airline-sichuan.svg"
    assert len(trip.departure_time) == 5  # HH:mm
    assert trip.arrival_time is None


def test_trip_title_and_countdown_templates(db_session: Session):
    user = db_session.query(User).first()
    trip = _create_trip(db_session, user, hours_ahead=50)
    assert trip.title == "2天后将前往大连"
    assert trip.tips == "还有2天飞往大连"

    near = _create_trip(db_session, user, hours_ahead=2)
    assert near.title == "今天将前往大连"
    assert near.tips == "还有2小时飞往大连"


def test_trip_assistant_card(db_session: Session):
    user = db_session.query(User).first()
    empty = TripService().assistant_card(db_session, user=user)
    assert empty.count == 0
    assert empty.last_message is None

    _create_trip(db_session, user, hours_ahead=30)
    card = TripService().assistant_card(db_session, user=user)
    assert card.count == 1
    assert "大连" in card.last_message


# -------------------------------------------------------------------- notes


def test_note_response_has_exactly_mock_fields(db_session: Session):
    user = db_session.query(User).first()
    note = NoteService().create_note(
        db_session, user=user, payload=NoteCreate(content="内容", tags=[])
    )
    assert set(note.model_dump().keys()) == {
        "id",
        "content",
        "time",
        "tags",
        "archived",
    }
    assert note.tags == ["随记"]
    assert note.archived is False
    assert note.time.startswith("今天")


def test_note_tag_normalization(db_session: Session):
    user = db_session.query(User).first()
    service = NoteService()
    note = service.create_note(
        db_session,
        user=user,
        payload=NoteCreate(content="内容", tags=["工作, 灵感", "工作", "设计", "产品", "阅读"]),
    )
    assert note.tags == ["工作", "灵感", "设计", "产品"]

    cleared = service.update_note(
        db_session, user=user, note_id=note.id, payload=NoteUpdate(tags=[])
    )
    assert cleared.tags == []


def test_note_delete(db_session: Session):
    user = db_session.query(User).first()
    service = NoteService()
    note = service.create_note(
        db_session, user=user, payload=NoteCreate(content="内容")
    )
    service.delete_note(db_session, user=user, note_id=note.id)
    assert service.list_notes(db_session, user=user) == []

    with pytest.raises(ValueError):
        service.delete_note(db_session, user=user, note_id=note.id)

"""Schedule business logic service."""

import random

from sqlalchemy.orm import Session

from app.models import Schedule, ScheduleColor, Trip, User
from app.models.contact import Friendship
from app.schemas.schedule import (
    ScheduleCreate,
    ScheduleRelatedResponse,
    ScheduleResponse,
    ScheduleUpdate,
)
from app.utils.timezone import to_local


class ScheduleService:
    """Service for listing, creating and updating personal schedules."""

    def _response(self, schedule: Schedule) -> ScheduleResponse:
        """Build a response with exactly the mock model fields."""
        return ScheduleResponse(
            id=schedule.id,
            date=schedule.date,
            start_time=schedule.start_time,
            end_time=schedule.end_time,
            title=schedule.title,
            detail=schedule.detail,
            category=schedule.category,
            related_type=schedule.related_type,
            related_id=schedule.related_id,
            place=schedule.place,
            participant_ids=schedule.participant_ids or [],
            color=schedule.color,
            source=schedule.source,
        )

    def list_schedules(self, db: Session, user: User) -> list[ScheduleResponse]:
        """Return the user's schedules ordered by date then start time."""
        schedules = (
            db.query(Schedule)
            .filter_by(user_id=user.id)
            .order_by(Schedule.date.asc(), Schedule.start_time.asc())
            .all()
        )
        return [self._response(item) for item in schedules]

    def related_candidates(self, db: Session, user: User) -> ScheduleRelatedResponse:
        """Return related trip/agreement candidates and comrade candidates.

        Agreements have no backing model yet, so that list stays empty
        until the agreement feature lands; trips come from the user's
        journeys and comrades from the friend list.
        """
        trips = (
            db.query(Trip)
            .filter_by(user_id=user.id)
            .order_by(Trip.departure_at.asc())
            .all()
        )
        trip_items = [
            {
                "id": trip.id,
                "label": (
                    f"{trip.departure_city} → {trip.arrival_city} · "
                    f"{to_local(trip.departure_at).month}月"
                    f"{to_local(trip.departure_at).day}日"
                ),
            }
            for trip in trips
        ]

        friendships = (
            db.query(Friendship).filter_by(user_id=user.id).all()
        )
        comrade_items = []
        for friendship in friendships:
            friend = db.query(User).filter_by(id=friendship.friend_id).first()
            if friend is None:
                continue
            comrade_items.append(
                {
                    "id": friend.id,
                    "nickname": friend.nickname,
                    "avatar": friend.avatar_url,
                }
            )

        return ScheduleRelatedResponse(
            trips=trip_items,
            agreements=[],
            comrades=comrade_items,
        )

    def create_schedule(
        self, db: Session, user: User, payload: ScheduleCreate
    ) -> ScheduleResponse:
        """Create a schedule with a randomly assigned card color."""
        schedule = Schedule(
            user_id=user.id,
            date=payload.date,
            start_time=payload.start_time,
            end_time=payload.end_time,
            title=payload.title,
            detail=payload.detail,
            category=payload.category,
            related_type=payload.related_type,
            related_id=payload.related_id,
            place=payload.place,
            participant_ids=payload.participant_ids,
            color=random.choice(
                [
                    ScheduleColor.PINK.value,
                    ScheduleColor.COFFEE.value,
                    ScheduleColor.BLUE.value,
                ]
            ),
            source=payload.source,
        )
        db.add(schedule)
        db.commit()
        db.refresh(schedule)
        return self._response(schedule)

    def update_schedule(
        self, db: Session, user: User, schedule_id: int, payload: ScheduleUpdate
    ) -> ScheduleResponse:
        """Update a schedule; provided fields overwrite existing values."""
        schedule = (
            db.query(Schedule)
            .filter_by(id=schedule_id, user_id=user.id)
            .first()
        )
        if schedule is None:
            raise ValueError("schedule not found")

        updates = payload.model_dump(exclude_unset=True)
        for field, value in updates.items():
            setattr(schedule, field, value)

        db.commit()
        db.refresh(schedule)
        return self._response(schedule)

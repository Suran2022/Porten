"""Schedule model for personal schedule entries."""

from enum import Enum as PyEnum
from typing import List, Optional

from sqlalchemy import JSON, BigInteger, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class ScheduleCategory(str, PyEnum):
    """Schedule category values."""

    TRAVEL = "travel"
    DATE = "date"
    VISIT = "visit"
    WORK = "work"
    DAILY = "daily"
    STUDY = "study"
    OTHER = "other"


class ScheduleRelatedType(str, PyEnum):
    """Related object types a schedule can be linked to."""

    TRIP = "trip"
    AGREEMENT = "agreement"


class ScheduleColor(str, PyEnum):
    """Card colors randomly assigned on creation."""

    PINK = "pink"
    COFFEE = "coffee"
    BLUE = "blue"


class ScheduleSource(str, PyEnum):
    """How the schedule was created."""

    FORM = "form"
    QUICK = "quick"


class Schedule(Base, TimestampMixin):
    """A personal schedule entry owned by a user."""

    __tablename__ = "schedules"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Owner of the schedule",
    )
    date: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
        index=True,
        comment="Schedule date, YYYY-MM-DD",
    )
    start_time: Mapped[str] = mapped_column(
        String(5),
        nullable=False,
        comment="Start time, HH:mm",
    )
    end_time: Mapped[Optional[str]] = mapped_column(
        String(5),
        nullable=True,
        comment="End time, HH:mm; optional",
    )
    title: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="Schedule title; optional",
    )
    detail: Mapped[Optional[str]] = mapped_column(
        String(1000),
        nullable=True,
        comment="Schedule detail; optional",
    )
    category: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="travel/date/visit/work/daily/study/other; optional",
    )
    related_type: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="trip or agreement; optional",
    )
    related_id: Mapped[Optional[int]] = mapped_column(
        BigInteger,
        nullable=True,
        comment="Id of the related trip or agreement; optional",
    )
    place: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="Location; optional",
    )
    participant_ids: Mapped[Optional[List[int]]] = mapped_column(
        JSON,
        nullable=True,
        default=list,
        comment="User ids of participating comrades",
    )
    color: Mapped[str] = mapped_column(
        String(10),
        default=ScheduleColor.PINK.value,
        nullable=False,
        comment="pink/coffee/blue; randomly assigned on creation",
    )
    source: Mapped[str] = mapped_column(
        String(10),
        default=ScheduleSource.FORM.value,
        nullable=False,
        comment="form or quick",
    )

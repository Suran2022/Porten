"""Trip (journey) model for flight itineraries created by users."""

from datetime import datetime
from enum import Enum as PyEnum
from typing import Optional

from sqlalchemy import BigInteger, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class TransferType(str, PyEnum):
    """Flight segment type shown above the plane icon on the card."""

    DIRECT = "直达"
    TRANSFER = "中转"


class Trip(Base, TimestampMixin):
    """A flight journey from a departure city to an arrival city."""

    __tablename__ = "trips"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Owner of the trip",
    )
    title: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="Card title, e.g. '2天后将前往大连'",
    )
    departure_city: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Departure city name",
    )
    departure_airport: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="Departure airport name",
    )
    departure_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="Departure date and time (UTC)",
    )
    arrival_city: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Arrival city name",
    )
    arrival_airport: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="Arrival airport name",
    )
    arrival_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Arrival date and time (UTC); optional",
    )
    transfer_type: Mapped[str] = mapped_column(
        String(10),
        default=TransferType.DIRECT.value,
        nullable=False,
        comment="直达 or 中转",
    )
    airline: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Carrier airline name",
    )
    tips: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
        comment="Reminder text under the card (countdown + weather); optional",
    )

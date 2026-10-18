"""Trip (journey) business logic service.

Card fields mirror the mock model exactly. On creation the server
derives the card title and the reminder text (``tips``); reminders are
recomputed on read so the countdown and weather stay fresh.
"""

import math
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import Trip, User
from app.schemas.trip import TripAssistantResponse, TripCreate, TripResponse
from app.services.weather_service import WeatherInfo, get_weather_provider
from app.utils.timezone import (
    as_utc,
    format_day_offset,
    format_hm,
    local_now,
    to_local,
)

#: Carrier name -> local asset path used by both the Web and App clients.
AIRLINE_ICONS: dict[str, str] = {
    "四川航空": "assets/icons/airline-sichuan.svg",
    "东方航空": "assets/icons/airline-eastern.svg",
    "中国航空": "assets/icons/airline-china.svg",
    "瑞丽航空": "assets/icons/airline-ruili.svg",
    "南方航空": "assets/icons/airline-southern.svg",
    "法国航空": "assets/icons/airline-france.svg",
    "厦门航空": "assets/icons/airline-xiamen.svg",
    "春秋航空": "assets/icons/airline-spring.svg",
    "吉祥航空": "assets/icons/airline-juneyao.svg",
    "大韩航空": "assets/icons/airline-korean.svg",
    "山东航空": "assets/icons/airline-shandong.svg",
}


class TripService:
    """Service for creating journeys and building card payloads."""

    def _build_title(self, departure_at: datetime, arrival_city: str) -> str:
        """Build the card title, e.g. '2天后将前往大连'."""
        local = to_local(departure_at)
        days = (local.date() - local_now().date()).days
        return f"{format_day_offset(days)}将前往{arrival_city}"

    def _countdown_text(self, departure_at: datetime, arrival_city: str) -> Optional[str]:
        """Build the departure countdown sentence, e.g. '您还有2小时飞往大连'."""
        settings = get_settings()
        departure = as_utc(departure_at)
        delta = departure - datetime.now(timezone.utc)
        if delta.total_seconds() <= 0:
            return None

        local = to_local(departure_at)
        days = (local.date() - local_now().date()).days
        if days >= 1:
            return settings.trip_reminder_days_template.format(
                days=days, arrival_city=arrival_city
            )
        hours = max(1, math.ceil(delta.total_seconds() / 3600))
        return settings.trip_reminder_hours_template.format(
            hours=hours, arrival_city=arrival_city
        )

    def _weather_text(
        self, departure_city: str, arrival_city: str
    ) -> Optional[str]:
        """Build the weather sentence from the configured provider.

        With no provider configured the weather part is simply absent,
        so the reminder degrades to the countdown only.
        """
        settings = get_settings()
        provider = get_weather_provider()
        origin: Optional[WeatherInfo] = provider.current(departure_city)
        destination: Optional[WeatherInfo] = provider.current(arrival_city)
        if origin is None or destination is None:
            return None

        if (
            origin.temperature is not None
            and destination.temperature is not None
            and destination.temperature
            <= origin.temperature - settings.weather_temp_drop_threshold
        ):
            return settings.trip_reminder_weather_cool_template.format(
                origin_text=origin.text, arrival_city=arrival_city
            )
        return settings.trip_reminder_weather_template.format(
            origin_text=origin.text,
            arrival_city=arrival_city,
            arrival_text=destination.text,
            origin_temp=origin.temperature,
            arrival_temp=destination.temperature,
        )

    def build_tips(
        self, departure_at: datetime, departure_city: str, arrival_city: str
    ) -> Optional[str]:
        """Build the full reminder: countdown first, weather appended."""
        parts = [
            part
            for part in (
                self._countdown_text(departure_at, arrival_city),
                self._weather_text(departure_city, arrival_city),
            )
            if part
        ]
        return "，".join(parts) if parts else None

    def _response(self, trip: Trip, tips: Optional[str] = None) -> TripResponse:
        """Build a card payload with exactly the mock model fields."""
        return TripResponse(
            title=trip.title,
            departure_city=trip.departure_city,
            departure_airport=trip.departure_airport,
            departure_time=format_hm(trip.departure_at),
            arrival_city=trip.arrival_city,
            arrival_airport=trip.arrival_airport,
            arrival_time=format_hm(trip.arrival_at),
            transfer_type=trip.transfer_type,
            airline=trip.airline,
            airline_icon=AIRLINE_ICONS.get(trip.airline, ""),
            tips=tips if tips is not None else trip.tips,
        )

    def create_trip(
        self, db: Session, user: User, payload: TripCreate
    ) -> TripResponse:
        """Create a journey, deriving title and reminder on the server."""
        trip = Trip(
            user_id=user.id,
            title=self._build_title(payload.departure_at, payload.arrival_city),
            departure_city=payload.departure_city,
            departure_airport=payload.departure_airport,
            departure_at=payload.departure_at,
            arrival_city=payload.arrival_city,
            arrival_airport=payload.arrival_airport,
            arrival_at=payload.arrival_at,
            transfer_type=payload.transfer_type,
            airline=payload.airline,
            tips=self.build_tips(
                payload.departure_at, payload.departure_city, payload.arrival_city
            ),
        )
        db.add(trip)
        db.commit()
        db.refresh(trip)
        return self._response(trip)

    def list_trips(self, db: Session, user: User) -> list[TripResponse]:
        """Return the user's journeys ordered by departure time.

        Reminders are recomputed per read so countdown and weather
        reflect the current moment.
        """
        trips = (
            db.query(Trip)
            .filter_by(user_id=user.id)
            .order_by(Trip.departure_at.asc())
            .all()
        )
        return [
            self._response(
                trip,
                tips=self.build_tips(
                    trip.departure_at, trip.departure_city, trip.arrival_city
                ),
            )
            for trip in trips
        ]

    def assistant_card(self, db: Session, user: User) -> TripAssistantResponse:
        """Build the my-journey entry card payload for the message list.

        ``count`` counts upcoming journeys; ``last_message`` summarizes
        the nearest one (the frontend prepends the '[行程助手]：' prefix).
        """
        now = datetime.now(timezone.utc)
        upcoming = (
            db.query(Trip)
            .filter_by(user_id=user.id)
            .filter(Trip.departure_at >= now)
            .order_by(Trip.departure_at.asc())
            .all()
        )
        if not upcoming:
            return TripAssistantResponse(count=0, last_message=None)

        nearest = upcoming[0]
        local = to_local(nearest.departure_at)
        days = (local.date() - local_now().date()).days
        return TripAssistantResponse(
            count=len(upcoming),
            last_message=(
                f"您有一条在{format_day_offset(days)}前往{nearest.arrival_city}的旅程"
            ),
        )

"""Trip (journey) related schemas.

Field names mirror the mock model (frontend TripItem) exactly:
one field neither more nor less.
"""

from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field

TransferTypeValue = Literal["直达", "中转"]


class TripCreate(BaseModel):
    """Request to create a trip (create-journey form fields)."""

    departure_city: str = Field(..., min_length=1, max_length=50)
    departure_airport: str = Field(..., min_length=1, max_length=100)
    arrival_city: str = Field(..., min_length=1, max_length=50)
    arrival_airport: str = Field(..., min_length=1, max_length=100)
    departure_at: datetime
    arrival_at: Optional[datetime] = None
    transfer_type: TransferTypeValue = "直达"
    airline: str = Field(..., min_length=1, max_length=50)


class TripResponse(BaseModel):
    """Trip card response; identical to the mock model fields."""

    title: str
    departure_city: str
    departure_airport: str
    departure_time: str
    arrival_city: str
    arrival_airport: str
    arrival_time: Optional[str]
    transfer_type: str
    airline: str
    airline_icon: str
    tips: Optional[str]

    class Config:
        from_attributes = True


class TripListResponse(BaseModel):
    """Trip list response."""

    items: List[TripResponse]


class TripAssistantResponse(BaseModel):
    """My-journey entry card on the message list.

    ``last_message`` is the newest journey summary (the frontend prepends
    the ``[行程助手]：`` prefix, matching the mock).
    """

    count: int
    last_message: Optional[str]

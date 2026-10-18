"""Schedule related schemas.

Field names mirror the mock model (frontend MockSchedule / ScheduleItem)
exactly: one field neither more nor less.
"""

from typing import List, Literal, Optional

from pydantic import BaseModel, Field

ScheduleCategoryValue = Literal[
    "travel",
    "date",
    "visit",
    "work",
    "daily",
    "study",
    "other",
]
ScheduleRelatedTypeValue = Literal["trip", "agreement"]
ScheduleColorValue = Literal["pink", "coffee", "blue"]
ScheduleSourceValue = Literal["form", "quick"]


class ScheduleCreate(BaseModel):
    """Request to create a schedule entry."""

    date: str = Field(..., pattern=r"^\d{4}-\d{2}-\d{2}$")
    start_time: str = Field(..., pattern=r"^\d{2}:\d{2}$")
    end_time: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    title: Optional[str] = Field(None, max_length=100)
    detail: Optional[str] = Field(None, max_length=1000)
    category: Optional[ScheduleCategoryValue] = None
    related_type: Optional[ScheduleRelatedTypeValue] = None
    related_id: Optional[int] = None
    place: Optional[str] = Field(None, max_length=255)
    participant_ids: List[int] = Field(default_factory=list)
    source: ScheduleSourceValue = "form"


class ScheduleUpdate(BaseModel):
    """Request to update a schedule entry; provided fields are overwritten."""

    date: Optional[str] = Field(None, pattern=r"^\d{4}-\d{2}-\d{2}$")
    start_time: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    end_time: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    title: Optional[str] = Field(None, max_length=100)
    detail: Optional[str] = Field(None, max_length=1000)
    category: Optional[ScheduleCategoryValue] = None
    related_type: Optional[ScheduleRelatedTypeValue] = None
    related_id: Optional[int] = None
    place: Optional[str] = Field(None, max_length=255)
    participant_ids: Optional[List[int]] = None
    source: Optional[ScheduleSourceValue] = None


class ScheduleResponse(BaseModel):
    """Schedule entry response; identical to the mock model fields."""

    id: int
    date: str
    start_time: str
    end_time: Optional[str]
    title: Optional[str]
    detail: Optional[str]
    category: Optional[str]
    related_type: Optional[str]
    related_id: Optional[int]
    place: Optional[str]
    participant_ids: List[int]
    color: str
    source: str

    class Config:
        from_attributes = True


class ScheduleListResponse(BaseModel):
    """Schedule list response."""

    items: List[ScheduleResponse]


class ScheduleRelatedItem(BaseModel):
    """A related-object candidate (trip or agreement)."""

    id: int
    label: str


class ScheduleComradeItem(BaseModel):
    """A participating-comrade candidate."""

    id: int
    nickname: str
    avatar: Optional[str]


class ScheduleRelatedResponse(BaseModel):
    """Related candidates for the schedule form."""

    trips: List[ScheduleRelatedItem]
    agreements: List[ScheduleRelatedItem]
    comrades: List[ScheduleComradeItem]

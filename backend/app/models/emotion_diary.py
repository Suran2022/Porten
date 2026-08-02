"""Emotion diary models."""

from enum import Enum as PyEnum
from typing import Optional

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin, utc_now


class MoodTag(str, PyEnum):
    """Built-in mood tags selectable when writing a diary entry."""

    HAPPY = "happy"
    CALM = "calm"
    SAD = "sad"
    ANXIOUS = "anxious"
    ANGRY = "angry"
    TIRED = "tired"
    GRATEFUL = "grateful"
    LONELY = "lonely"
    HOPEFUL = "hopeful"
    CONFUSED = "confused"


MOOD_LABELS: dict[str, str] = {
    MoodTag.HAPPY.value: "开心",
    MoodTag.CALM.value: "平静",
    MoodTag.SAD.value: "难过",
    MoodTag.ANXIOUS.value: "焦虑",
    MoodTag.ANGRY.value: "愤怒",
    MoodTag.TIRED.value: "疲惫",
    MoodTag.GRATEFUL.value: "感恩",
    MoodTag.LONELY.value: "孤独",
    MoodTag.HOPEFUL.value: "充满希望",
    MoodTag.CONFUSED.value: "迷茫",
}


class EmotionDiary(Base, TimestampMixin):
    """A single mood / emotion diary entry written by a user."""

    __tablename__ = "emotion_diaries"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    content: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="Diary body text",
    )
    mood: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        comment="Mood tag enum value, e.g. happy/sad/anxious",
    )
    is_public: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        comment="Whether this entry is publicly viewable; private reserved",
    )
    is_current: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        index=True,
        comment="True if this is the author's current (latest) entry; "
        "older entries are kept as history with is_current=false",
    )

    author: Mapped["User"] = relationship(
        "User", foreign_keys=[user_id], lazy="selectin"
    )
    views: Mapped[list["EmotionDiaryView"]] = relationship(
        "EmotionDiaryView",
        back_populates="diary",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class EmotionDiaryView(Base):
    """Records that a user has viewed a specific diary entry."""

    __tablename__ = "emotion_diary_views"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    diary_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("emotion_diaries.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    viewer_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    viewed_at: Mapped[DateTime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint("diary_id", "viewer_id", name="uq_emotion_diary_view"),
    )

    diary: Mapped["EmotionDiary"] = relationship(
        "EmotionDiary", back_populates="views"
    )
    viewer: Mapped["User"] = relationship(
        "User", foreign_keys=[viewer_id], lazy="selectin"
    )

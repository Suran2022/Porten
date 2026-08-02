"""Emotion diary service."""

from typing import List, Optional, Tuple

from sqlalchemy import desc
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.models import EmotionDiary, EmotionDiaryView, User
from app.models.emotion_diary import MoodTag


class EmotionDiaryService:
    """Business logic for emotion diary entries and their views."""

    DEFAULT_PAGE_SIZE = 20
    MAX_PAGE_SIZE = 50

    @staticmethod
    def _normalize_mood(mood: str) -> str:
        """Normalize and validate the mood tag enum value."""
        normalized = (mood or "").strip().lower()
        valid = {m.value for m in MoodTag}
        if normalized not in valid:
            raise ValueError(f"invalid mood: {mood}")
        return normalized

    @staticmethod
    def _sync_user_latest(
        db: Session, user: User, diary: EmotionDiary
    ) -> None:
        """Sync the cached latest_diary + mood columns on the user row."""
        user.latest_diary = diary.content
        user.mood = diary.mood
        db.add(user)
        db.flush()

    def _demote_previous_current(
        self, db: Session, user_id: int
    ) -> None:
        """Mark the previous current row as not current."""
        db.query(EmotionDiary).filter(
            EmotionDiary.user_id == user_id,
            EmotionDiary.is_current.is_(True),
        ).update({EmotionDiary.is_current: False})

    def _create_entry(
        self,
        db: Session,
        *,
        user: User,
        content: str,
        mood: str,
        is_public: bool = True,
    ) -> EmotionDiary:
        """Insert a new row, demoting the previous current row if any."""
        normalized_mood = self._normalize_mood(mood)
        self._demote_previous_current(db, user.id)
        diary = EmotionDiary(
            user_id=user.id,
            content=content.strip(),
            mood=normalized_mood,
            is_public=bool(is_public),
            is_current=True,
        )
        db.add(diary)
        db.flush()
        self._sync_user_latest(db, user, diary)
        db.commit()
        db.refresh(diary)
        return diary

    def create_diary(
        self,
        db: Session,
        *,
        user: User,
        content: str,
        mood: str,
        is_public: bool = True,
    ) -> EmotionDiary:
        """Create a new (initial) diary entry for the given user."""
        return self._create_entry(
            db, user=user, content=content, mood=mood, is_public=is_public
        )

    def update_diary(
        self,
        db: Session,
        *,
        user: User,
        content: str,
        mood: str,
        is_public: bool = True,
    ) -> EmotionDiary:
        """Save a new version of the diary for the given user.

        The previously current row is demoted and retained as history; a
        new row is inserted and marked is_current=true. The user's cached
        latest_diary + mood are updated to reflect the new current.
        """
        return self._create_entry(
            db, user=user, content=content, mood=mood, is_public=is_public
        )

    def get_diary(
        self, db: Session, diary_id: int
    ) -> Optional[EmotionDiary]:
        """Fetch a single diary by id with author preloaded."""
        return (
            db.query(EmotionDiary)
            .options(joinedload(EmotionDiary.author))
            .filter(EmotionDiary.id == diary_id)
            .first()
        )

    def get_current_diary(
        self, db: Session, user_id: int
    ) -> Optional[EmotionDiary]:
        """Return the current (latest) diary for the given user."""
        return (
            db.query(EmotionDiary)
            .options(joinedload(EmotionDiary.author))
            .filter(
                EmotionDiary.user_id == user_id,
                EmotionDiary.is_current.is_(True),
            )
            .first()
        )

    def list_history(
        self,
        db: Session,
        *,
        user_id: int,
        cursor: Optional[int] = None,
        limit: int = 50,
    ) -> Tuple[List[EmotionDiary], int]:
        """List all diary entries for the user, newest first."""
        limit = max(1, min(limit, self.MAX_PAGE_SIZE))
        query = (
            db.query(EmotionDiary)
            .options(joinedload(EmotionDiary.author))
            .filter(EmotionDiary.user_id == user_id)
        )
        if cursor is not None:
            query = query.filter(EmotionDiary.id < cursor)
        items = query.order_by(desc(EmotionDiary.id)).limit(limit).all()
        total = (
            db.query(EmotionDiary)
            .filter(EmotionDiary.user_id == user_id)
            .count()
        )
        return items, total

    def delete_diary(
        self, db: Session, diary: EmotionDiary
    ) -> None:
        """Delete a diary entry (and cascade its views)."""
        db.delete(diary)
        db.commit()

    def record_view(
        self,
        db: Session,
        *,
        diary: EmotionDiary,
        viewer: User,
    ) -> EmotionDiaryView:
        """Record that a viewer has seen this diary. Idempotent per (diary, viewer)."""
        existing = (
            db.query(EmotionDiaryView)
            .filter_by(diary_id=diary.id, viewer_id=viewer.id)
            .first()
        )
        if existing:
            return existing
        view = EmotionDiaryView(diary_id=diary.id, viewer_id=viewer.id)
        db.add(view)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            view = (
                db.query(EmotionDiaryView)
                .filter_by(diary_id=diary.id, viewer_id=viewer.id)
                .first()
            )
        db.refresh(view)
        return view

    def list_viewers(
        self,
        db: Session,
        *,
        diary: EmotionDiary,
        cursor: Optional[int] = None,
        limit: int = 50,
    ) -> Tuple[List[EmotionDiaryView], int]:
        """List viewers for a diary, newest first."""
        limit = max(1, min(limit, self.MAX_PAGE_SIZE))
        query = (
            db.query(EmotionDiaryView)
            .options(joinedload(EmotionDiaryView.viewer))
            .filter(EmotionDiaryView.diary_id == diary.id)
        )
        if cursor is not None:
            query = query.filter(EmotionDiaryView.id < cursor)
        items = query.order_by(desc(EmotionDiaryView.id)).limit(limit).all()
        total = (
            db.query(EmotionDiaryView)
            .filter(EmotionDiaryView.diary_id == diary.id)
            .count()
        )
        return items, total

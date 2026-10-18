"""Note business logic service."""

import re
from typing import Optional

from sqlalchemy.orm import Session

from app.models import Note, User
from app.schemas.note import NoteCreate, NoteResponse, NoteUpdate
from app.utils.timezone import format_note_time

_TAG_SPLIT = re.compile(r"[、,，\s]+")
_MAX_TAGS = 4


class NoteService:
    """Service for listing, creating, updating and deleting notes."""

    def _normalize_tags(
        self, tags: list[str], fallback: bool
    ) -> list[str]:
        """Split/trim tags the same way the web client does.

        ``fallback`` mirrors the web save branches: new notes without
        tags fall back to ['随记'], edits may clear tags entirely.
        """
        normalized: list[str] = []
        for tag in tags:
            for part in _TAG_SPLIT.split(tag):
                part = part.strip()
                if part and part not in normalized:
                    normalized.append(part)
        normalized = normalized[:_MAX_TAGS]
        if fallback and not normalized:
            return ["随记"]
        return normalized

    def _response(self, note: Note) -> NoteResponse:
        """Build a response with exactly the mock model fields."""
        return NoteResponse(
            id=note.id,
            content=note.content,
            time=format_note_time(note.updated_at),
            tags=note.tags or [],
            archived=note.archived,
        )

    def list_notes(self, db: Session, user: User) -> list[NoteResponse]:
        """Return the user's notes, newest first."""
        notes = (
            db.query(Note)
            .filter_by(user_id=user.id)
            .order_by(Note.updated_at.desc())
            .all()
        )
        return [self._response(note) for note in notes]

    def create_note(
        self, db: Session, user: User, payload: NoteCreate
    ) -> NoteResponse:
        """Create a note; empty tags fall back to ['随记']."""
        note = Note(
            user_id=user.id,
            content=payload.content,
            tags=self._normalize_tags(payload.tags, fallback=True),
            archived=False,
        )
        db.add(note)
        db.commit()
        db.refresh(note)
        return self._response(note)

    def update_note(
        self, db: Session, user: User, note_id: int, payload: NoteUpdate
    ) -> NoteResponse:
        """Update a note; provided fields overwrite existing values."""
        note = db.query(Note).filter_by(id=note_id, user_id=user.id).first()
        if note is None:
            raise ValueError("note not found")

        updates = payload.model_dump(exclude_unset=True)
        tags = updates.pop("tags", None)
        if tags is not None:
            note.tags = self._normalize_tags(tags, fallback=False)
        for field, value in updates.items():
            setattr(note, field, value)

        db.commit()
        db.refresh(note)
        return self._response(note)

    def delete_note(self, db: Session, user: User, note_id: int) -> None:
        """Delete a note owned by the user."""
        note = db.query(Note).filter_by(id=note_id, user_id=user.id).first()
        if note is None:
            raise ValueError("note not found")
        db.delete(note)
        db.commit()

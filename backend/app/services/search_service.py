"""Global search service (同胞 / 营地 / 文件 / 知识 / 图片)."""

from __future__ import annotations

import os
from datetime import datetime
from typing import Optional

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models.group import Group
from app.models.media_file import MediaFile
from app.models.user import User
from app.schemas.search import (
    SearchCampItem,
    SearchComradeItem,
    SearchFileItem,
    SearchImageItem,
    SearchKnowledgeItem,
)


SEARCH_TYPE_ALL = "all"
SEARCH_TYPE_COMRADE = "comrade"
SEARCH_TYPE_CAMP = "camp"
SEARCH_TYPE_FILE = "file"
SEARCH_TYPE_KNOWLEDGE = "knowledge"
SEARCH_TYPE_IMAGE = "image"

ALL_SEARCH_TYPES = (
    SEARCH_TYPE_COMRADE,
    SEARCH_TYPE_CAMP,
    SEARCH_TYPE_FILE,
    SEARCH_TYPE_KNOWLEDGE,
    SEARCH_TYPE_IMAGE,
)


def _is_blank(value: Optional[str]) -> bool:
    return value is None or not str(value).strip()


def _escape_like(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("%", "\\%")
        .replace("_", "\\_")
    )


class SearchService:
    """Encapsulates global search across the Porten knowledge graph."""

    DEFAULT_LIMIT = 20

    # ----- single-type searchers -----

    def search_comrades(
        self, db: Session, *, query: str, limit: int = DEFAULT_LIMIT
    ) -> list[SearchComradeItem]:
        """Search active users whose nickname or Porten ID matches the query."""
        if _is_blank(query):
            return []
        pattern = f"%{_escape_like(query.strip())}%"
        stmt = (
            select(User)
            .where(User.is_active.is_(True))
            .where(
                or_(
                    User.nickname.ilike(pattern),
                    User.porten_id.ilike(pattern),
                )
            )
            .order_by(User.nickname.asc())
            .limit(limit)
        )
        users = db.execute(stmt).scalars().all()
        return [
            SearchComradeItem(
                id=u.id,
                porten_id=u.porten_id,
                nickname=u.nickname or "",
                avatar_url=u.avatar_url,
            )
            for u in users
        ]

    def search_camps(
        self, db: Session, *, query: str, limit: int = DEFAULT_LIMIT
    ) -> list[SearchCampItem]:
        """Search groups (camps) whose name, camp_id, or description matches."""
        if _is_blank(query):
            return []
        pattern = f"%{_escape_like(query.strip())}%"
        stmt = (
            select(Group)
            .where(Group.searchable_by_name.is_(True))
            .where(
                or_(
                    Group.name.ilike(pattern),
                    Group.camp_id.ilike(pattern),
                    Group.description.ilike(pattern),
                )
            )
            .order_by(Group.member_count.desc(), Group.name.asc())
            .limit(limit)
        )
        groups = db.execute(stmt).scalars().all()
        return [
            SearchCampItem(
                id=g.id,
                name=g.name or "",
                avatar_url=g.avatar_url,
                member_count=g.member_count or 0,
                tags=g.tags or [],
                group_type=g.group_type,
                camp_id=g.camp_id,
                description=g.description,
            )
            for g in groups
        ]

    def _user_nickname(self, db: Session, uploader_id: Optional[int]) -> Optional[str]:
        if not uploader_id:
            return None
        user = db.get(User, uploader_id)
        return user.nickname if user else None

    def search_files(
        self, db: Session, *, query: str, limit: int = DEFAULT_LIMIT
    ) -> list[SearchFileItem]:
        """Search media files of type 'file' by original name or storage path."""
        if _is_blank(query):
            return []
        pattern = f"%{_escape_like(query.strip())}%"
        stmt = (
            select(MediaFile)
            .where(
                or_(
                    MediaFile.file_type == "file",
                    MediaFile.file_type == "document",
                )
            )
            .where(
                or_(
                    MediaFile.original_name.ilike(pattern),
                    MediaFile.file_path.ilike(pattern),
                )
            )
            .order_by(MediaFile.created_at.desc())
            .limit(limit)
        )
        media = db.execute(stmt).scalars().all()
        results: list[SearchFileItem] = []
        for m in media:
            results.append(
                SearchFileItem(
                    id=m.id,
                    name=m.original_name or os.path.basename(m.file_path or ""),
                    url=m.file_path or "",
                    size=m.file_size,
                    uploader_id=m.uploader_id,
                    uploader_nickname=self._user_nickname(db, m.uploader_id),
                    created_at=m.created_at,
                )
            )
        return results

    def search_images(
        self, db: Session, *, query: str, limit: int = DEFAULT_LIMIT
    ) -> list[SearchImageItem]:
        """Search media files of type 'image' by original name or storage path."""
        if _is_blank(query):
            return []
        pattern = f"%{_escape_like(query.strip())}%"
        stmt = (
            select(MediaFile)
            .where(MediaFile.file_type == "image")
            .where(
                or_(
                    MediaFile.original_name.ilike(pattern),
                    MediaFile.file_path.ilike(pattern),
                )
            )
            .order_by(MediaFile.created_at.desc())
            .limit(limit)
        )
        media = db.execute(stmt).scalars().all()
        results: list[SearchImageItem] = []
        for m in media:
            results.append(
                SearchImageItem(
                    id=m.id,
                    name=m.original_name or os.path.basename(m.file_path or ""),
                    url=m.file_path or "",
                    size=m.file_size,
                    uploader_id=m.uploader_id,
                    uploader_nickname=self._user_nickname(db, m.uploader_id),
                    created_at=m.created_at,
                )
            )
        return results

    def search_knowledge(
        self, *, query: str, limit: int = DEFAULT_LIMIT
    ) -> list[SearchKnowledgeItem]:
        """Knowledge backend is not yet implemented; returns an empty list."""
        return []

    # ----- public entry points -----

    def search(
        self,
        db: Session,
        *,
        query: str,
        search_type: str = SEARCH_TYPE_ALL,
        limit: int = DEFAULT_LIMIT,
    ):
        if search_type == SEARCH_TYPE_COMRADE:
            return self.search_comrades(db, query=query, limit=limit)
        if search_type == SEARCH_TYPE_CAMP:
            return self.search_camps(db, query=query, limit=limit)
        if search_type == SEARCH_TYPE_FILE:
            return self.search_files(db, query=query, limit=limit)
        if search_type == SEARCH_TYPE_IMAGE:
            return self.search_images(db, query=query, limit=limit)
        if search_type == SEARCH_TYPE_KNOWLEDGE:
            return self.search_knowledge(query=query, limit=limit)
        # SEARCH_TYPE_ALL
        return {
            "comrade": self.search_comrades(db, query=query, limit=limit),
            "camp": self.search_camps(db, query=query, limit=limit),
            "file": self.search_files(db, query=query, limit=limit),
            "knowledge": self.search_knowledge(query=query, limit=limit),
            "image": self.search_images(db, query=query, limit=limit),
        }


search_service = SearchService()

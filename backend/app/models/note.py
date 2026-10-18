"""Note model for the personal notebook feature."""

from typing import List, Optional

from sqlalchemy import JSON, BigInteger, Boolean, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class Note(Base, TimestampMixin):
    """A personal note written by a user."""

    __tablename__ = "notes"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Owner of the note",
    )
    content: Mapped[str] = mapped_column(
        String(2000),
        nullable=False,
        comment="Note body text",
    )
    tags: Mapped[Optional[List[str]]] = mapped_column(
        JSON,
        nullable=True,
        default=list,
        comment="Up to 4 tags; defaults to ['随记'] when omitted",
    )
    archived: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        comment="Whether the note is archived",
    )

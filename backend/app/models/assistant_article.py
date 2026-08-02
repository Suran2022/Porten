"""Assistant article model.

每个 Porten 助手（assistant）可以下发多篇文章，文章正文以 Markdown
文件存放在后端 `app/data/articles/{slug}.md`，数据库只保存元信息
（标题、概要、发布时间、发布人等）。
"""
from typing import Optional

from sqlalchemy import BigInteger, Boolean, DateTime, Index, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class AssistantArticle(Base, TimestampMixin):
    """一篇助手下发的文章。"""

    __tablename__ = "assistant_articles"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    # 助手 ID 字符串，例如 "qin_xiaoxu"
    assistant_id: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        index=True,
        comment="Assistant identifier, e.g. qin_xiaoxu",
    )
    # 用于在文件系统定位 markdown 文件的短链
    slug: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
        comment="Markdown file slug, e.g. 001-talk-to-family",
    )
    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Article title shown on the card",
    )
    summary: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        default="",
        comment="One-line summary used by the card preview",
    )
    publish_time: Mapped[DateTime] = mapped_column(  # type: ignore[valid-type]
        DateTime(timezone=True),
        nullable=False,
        index=True,
        comment="Publish time, ordered desc by default",
    )
    publisher: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
        default="Porten 官方",
        comment="Publisher label shown on the card",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        comment="Soft delete flag",
    )

    __table_args__ = (
        Index(
            "ix_assistant_articles_assistant_slug",
            "assistant_id",
            "slug",
            unique=True,
        ),
    )


class UserAssistantArticleRead(Base, TimestampMixin):
    """Per-user read state for an assistant article."""

    __tablename__ = "user_assistant_article_reads"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        nullable=False,
        index=True,
    )
    article_id: Mapped[int] = mapped_column(
        BigInteger,
        nullable=False,
        index=True,
    )
    is_read: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    read_at: Mapped[Optional[DateTime]] = mapped_column(  # type: ignore[valid-type]
        DateTime(timezone=True),
        nullable=True,
    )

    __table_args__ = (
        Index(
            "ix_user_assistant_article_user_article",
            "user_id",
            "article_id",
            unique=True,
        ),
    )

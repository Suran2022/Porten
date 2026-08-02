"""Add assistant articles and per-user read state.

Revision ID: 0014
Revises: 0013
Create Date: 2026-07-22 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0014"
down_revision: Union[str, None] = "0013"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "assistant_articles",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("assistant_id", sa.String(64), nullable=False),
        sa.Column("slug", sa.String(120), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("summary", sa.String(500), nullable=False, server_default=""),
        sa.Column("publish_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("publisher", sa.String(120), nullable=False, server_default="Porten 官方"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("1")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            onupdate=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("assistant_id", "slug", name="ix_assistant_articles_assistant_slug"),
    )
    op.create_index(
        "ix_assistant_articles_assistant_id",
        "assistant_articles",
        ["assistant_id"],
        unique=False,
    )
    op.create_index(
        "ix_assistant_articles_publish_time",
        "assistant_articles",
        ["publish_time"],
        unique=False,
    )

    op.create_table(
        "user_assistant_article_reads",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("article_id", sa.BigInteger(), nullable=False),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default=sa.text("0")),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            onupdate=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["article_id"], ["assistant_articles.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "article_id", name="ix_user_assistant_article_user_article"),
    )
    op.create_index(
        "ix_user_assistant_article_user_id",
        "user_assistant_article_reads",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_assistant_article_article_id",
        "user_assistant_article_reads",
        ["article_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_user_assistant_article_article_id", table_name="user_assistant_article_reads")
    op.drop_index("ix_user_assistant_article_user_id", table_name="user_assistant_article_reads")
    op.drop_table("user_assistant_article_reads")
    op.drop_index("ix_assistant_articles_publish_time", table_name="assistant_articles")
    op.drop_index("ix_assistant_articles_assistant_id", table_name="assistant_articles")
    op.drop_table("assistant_articles")

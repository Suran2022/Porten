"""Add emotion diary tables.

Revision ID: 0012
Revises: 0011
Create Date: 2026-07-21 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0012"
down_revision: Union[str, None] = "0011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "emotion_diaries",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column(
            "user_id",
            sa.BigInteger,
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("content", sa.Text, nullable=False),
        sa.Column("mood", sa.String(20), nullable=False),
        sa.Column(
            "is_public",
            sa.Boolean,
            nullable=False,
            server_default=sa.text("1"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_emotion_diaries_user_id", "emotion_diaries", ["user_id"]
    )

    op.create_table(
        "emotion_diary_views",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column(
            "diary_id",
            sa.BigInteger,
            sa.ForeignKey("emotion_diaries.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "viewer_id",
            sa.BigInteger,
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "viewed_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "diary_id", "viewer_id", name="uq_emotion_diary_view"
        ),
    )
    op.create_index(
        "ix_emotion_diary_views_diary_id",
        "emotion_diary_views",
        ["diary_id"],
    )
    op.create_index(
        "ix_emotion_diary_views_viewer_id",
        "emotion_diary_views",
        ["viewer_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_emotion_diary_views_viewer_id", table_name="emotion_diary_views"
    )
    op.drop_index(
        "ix_emotion_diary_views_diary_id", table_name="emotion_diary_views"
    )
    op.drop_table("emotion_diary_views")
    op.drop_index("ix_emotion_diaries_user_id", table_name="emotion_diaries")
    op.drop_table("emotion_diaries")

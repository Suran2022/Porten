"""Add is_current to emotion_diaries and latest_diary/mood to users.

Revision ID: 0013
Revises: 0012
Create Date: 2026-07-21 02:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.mysql import LONGTEXT

# revision identifiers, used by Alembic.
revision: str = "0013"
down_revision: Union[str, None] = "0012"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # emotion_diaries: add is_current column
    op.add_column(
        "emotion_diaries",
        sa.Column(
            "is_current",
            sa.Boolean,
            nullable=False,
            server_default=sa.text("1"),
        ),
    )
    op.create_index(
        "ix_emotion_diaries_user_current",
        "emotion_diaries",
        ["user_id", "is_current"],
    )

    # Backfill is_current = false for any older rows that should not be the
    # current version. We mark only the latest row per user as current so the
    # post-deploy state is consistent with the application logic.
    op.execute(
        """
        UPDATE emotion_diaries ed
        JOIN (
            SELECT user_id, MAX(id) AS max_id
            FROM emotion_diaries
            GROUP BY user_id
        ) latest ON latest.user_id = ed.user_id
        SET ed.is_current = (ed.id = latest.max_id)
        """
    )

    # users: add latest_diary + mood cached from current emotion diary
    op.add_column(
        "users",
        sa.Column("latest_diary", LONGTEXT, nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("mood", sa.String(20), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "mood")
    op.drop_column("users", "latest_diary")
    op.drop_index(
        "ix_emotion_diaries_user_current", table_name="emotion_diaries"
    )
    op.drop_column("emotion_diaries", "is_current")

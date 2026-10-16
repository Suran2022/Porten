"""Add ueba_entity_scores table for aggregated risk scores.

Revision ID: 0028
Revises: 0027
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0028"
down_revision: Union[str, None] = "0027"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "ueba_entity_scores",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column(
            "entity_type",
            sa.String(length=20),
            server_default=sa.text("'user'"),
            nullable=False,
        ),
        sa.Column("entity_id", sa.String(length=64), nullable=False),
        sa.Column("window_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("window_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("level", sa.String(length=20), nullable=False),
        sa.Column("signals", sa.JSON(), nullable=True),
        sa.Column("top_reasons", sa.JSON(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "entity_type",
            "entity_id",
            "window_start",
            name="uq_ueba_entity_window",
        ),
    )
    op.create_index(
        "ix_ueba_entity_scores_id", "ueba_entity_scores", ["id"], unique=False
    )
    op.create_index(
        "ix_ueba_entity_scores_level", "ueba_entity_scores", ["level"], unique=False
    )
    op.create_index(
        "ix_ueba_entity_scores_created_at",
        "ueba_entity_scores",
        ["created_at"],
        unique=False,
    )
    op.create_index(
        "ix_ueba_entity_scores_entity",
        "ueba_entity_scores",
        ["entity_type", "entity_id"],
        unique=False,
    )
    op.create_index(
        "ix_ueba_entity_scores_level_created",
        "ueba_entity_scores",
        ["level", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_ueba_entity_scores_level_created", table_name="ueba_entity_scores"
    )
    op.drop_index("ix_ueba_entity_scores_entity", table_name="ueba_entity_scores")
    op.drop_index(
        "ix_ueba_entity_scores_created_at", table_name="ueba_entity_scores"
    )
    op.drop_index("ix_ueba_entity_scores_level", table_name="ueba_entity_scores")
    op.drop_index("ix_ueba_entity_scores_id", table_name="ueba_entity_scores")
    op.drop_table("ueba_entity_scores")

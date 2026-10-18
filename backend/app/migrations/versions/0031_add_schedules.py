"""Add schedules table for personal schedule entries.

Revision ID: 0031
Revises: 0030
Create Date: 2026-10-17 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0031"
down_revision: Union[str, None] = "0030"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "schedules",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column(
            "user_id",
            sa.BigInteger(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            comment="Owner of the schedule",
        ),
        sa.Column(
            "date",
            sa.String(length=10),
            nullable=False,
            comment="Schedule date, YYYY-MM-DD",
        ),
        sa.Column(
            "start_time",
            sa.String(length=5),
            nullable=False,
            comment="Start time, HH:mm",
        ),
        sa.Column(
            "end_time",
            sa.String(length=5),
            nullable=True,
            comment="End time, HH:mm; optional",
        ),
        sa.Column(
            "title",
            sa.String(length=100),
            nullable=True,
            comment="Schedule title; optional",
        ),
        sa.Column(
            "detail",
            sa.String(length=1000),
            nullable=True,
            comment="Schedule detail; optional",
        ),
        sa.Column(
            "category",
            sa.String(length=20),
            nullable=True,
            comment="travel/date/visit/work/daily/study/other; optional",
        ),
        sa.Column(
            "related_type",
            sa.String(length=20),
            nullable=True,
            comment="trip or agreement; optional",
        ),
        sa.Column(
            "related_id",
            sa.BigInteger(),
            nullable=True,
            comment="Id of the related trip or agreement; optional",
        ),
        sa.Column(
            "place",
            sa.String(length=255),
            nullable=True,
            comment="Location; optional",
        ),
        sa.Column(
            "participant_ids",
            sa.JSON(),
            nullable=True,
            comment="User ids of participating comrades",
        ),
        sa.Column(
            "color",
            sa.String(length=10),
            server_default=sa.text("'pink'"),
            nullable=False,
            comment="pink/coffee/blue; randomly assigned on creation",
        ),
        sa.Column(
            "source",
            sa.String(length=10),
            server_default=sa.text("'form'"),
            nullable=False,
            comment="form or quick",
        ),
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
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_schedules_user_id", "schedules", ["user_id"], unique=False
    )
    op.create_index("ix_schedules_date", "schedules", ["date"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_schedules_date", table_name="schedules")
    op.drop_index("ix_schedules_user_id", table_name="schedules")
    op.drop_table("schedules")

"""Add security_events table.

Revision ID: 0016
Revises: 0015
Create Date: 2026-07-22 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0016"
down_revision: Union[str, None] = "0015"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "security_events",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("event_type", sa.String(length=50), nullable=False),
        sa.Column("severity", sa.String(length=20), nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=True),
        sa.Column("detail", sa.Text(), nullable=True),
        sa.Column("meta", sa.JSON(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_security_events_id", "security_events", ["id"], unique=False
    )
    op.create_index(
        "ix_security_events_event_type",
        "security_events",
        ["event_type"],
        unique=False,
    )
    op.create_index(
        "ix_security_events_user_id", "security_events", ["user_id"], unique=False
    )
    op.create_index(
        "ix_security_events_created_at",
        "security_events",
        ["created_at"],
        unique=False,
    )
    op.create_index(
        "ix_security_events_type_created",
        "security_events",
        ["event_type", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_security_events_type_created", table_name="security_events")
    op.drop_index("ix_security_events_created_at", table_name="security_events")
    op.drop_index("ix_security_events_user_id", table_name="security_events")
    op.drop_index("ix_security_events_event_type", table_name="security_events")
    op.drop_index("ix_security_events_id", table_name="security_events")
    op.drop_table("security_events")

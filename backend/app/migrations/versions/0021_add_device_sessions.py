"""Add device_sessions table for token-device binding.

Revision ID: 0021
Revises: 0020
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0021"
down_revision: Union[str, None] = "0020"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "device_sessions",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("device_id", sa.String(length=64), nullable=False),
        sa.Column("device_name", sa.String(length=100), nullable=True),
        sa.Column("platform", sa.String(length=30), nullable=True),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "revoked",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("0"),
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
            onupdate=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id", "device_id", name="uq_device_sessions_user_device"
        ),
    )
    op.create_index(
        "ix_device_sessions_id", "device_sessions", ["id"], unique=False
    )
    op.create_index(
        "ix_device_sessions_user_id", "device_sessions", ["user_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_device_sessions_user_id", table_name="device_sessions")
    op.drop_index("ix_device_sessions_id", table_name="device_sessions")
    op.drop_table("device_sessions")

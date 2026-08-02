"""Add system messages and per-user read state.

Revision ID: 0006
Revises: 0005
Create Date: 2026-07-12 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0006"
down_revision: Union[str, None] = "0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "system_messages",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("version", sa.String(20), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("message_type", sa.String(20), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
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
        sa.UniqueConstraint("version"),
    )
    op.create_index("ix_system_messages_version", "system_messages", ["version"], unique=True)

    op.create_table(
        "user_system_message_reads",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("system_message_id", sa.BigInteger(), nullable=False),
        sa.Column("is_read", sa.Boolean(), nullable=False),
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
        sa.ForeignKeyConstraint(["system_message_id"], ["system_messages.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "system_message_id", name="uq_user_system_message_user_message"),
    )
    op.create_index(
        "ix_user_system_message_user_id",
        "user_system_message_reads",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_system_message_message_id",
        "user_system_message_reads",
        ["system_message_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_system_message_user_message",
        "user_system_message_reads",
        ["user_id", "system_message_id"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ix_user_system_message_user_message", table_name="user_system_message_reads")
    op.drop_index("ix_user_system_message_message_id", table_name="user_system_message_reads")
    op.drop_index("ix_user_system_message_user_id", table_name="user_system_message_reads")
    op.drop_table("user_system_message_reads")
    op.drop_index("ix_system_messages_version", table_name="system_messages")
    op.drop_table("system_messages")

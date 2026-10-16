"""Add approval_tickets table for two-person/two-key authorization.

Revision ID: 0026
Revises: 0025
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0026"
down_revision: Union[str, None] = "0025"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "approval_tickets",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("action", sa.String(length=50), nullable=False),
        sa.Column("target_type", sa.String(length=50), nullable=True),
        sa.Column("target_id", sa.String(length=64), nullable=True),
        sa.Column("request_payload", sa.JSON(), nullable=True),
        sa.Column("primary_user_id", sa.BigInteger(), nullable=False),
        sa.Column("reviewer_user_id", sa.BigInteger(), nullable=True),
        sa.Column(
            "status",
            sa.String(length=20),
            server_default=sa.text("'pending'"),
            nullable=False,
        ),
        sa.Column("challenge_nonce", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("primary_credential_id", sa.String(length=255), nullable=True),
        sa.Column("reviewer_credential_id", sa.String(length=255), nullable=True),
        sa.Column("primary_authorized_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewer_authorized_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("decision_note", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["primary_user_id"], ["users.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["reviewer_user_id"], ["users.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_approval_tickets_id", "approval_tickets", ["id"], unique=False
    )
    op.create_index(
        "ix_approval_tickets_primary_user_id",
        "approval_tickets",
        ["primary_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_approval_tickets_status", "approval_tickets", ["status"], unique=False
    )
    op.create_index(
        "ix_approval_tickets_expires_at",
        "approval_tickets",
        ["expires_at"],
        unique=False,
    )
    op.create_index(
        "ix_approval_tickets_created_at",
        "approval_tickets",
        ["created_at"],
        unique=False,
    )
    op.create_index(
        "ix_approval_tickets_status_expires",
        "approval_tickets",
        ["status", "expires_at"],
        unique=False,
    )
    op.create_index(
        "ix_approval_tickets_target",
        "approval_tickets",
        ["target_type", "target_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_approval_tickets_target", table_name="approval_tickets")
    op.drop_index(
        "ix_approval_tickets_status_expires", table_name="approval_tickets"
    )
    op.drop_index("ix_approval_tickets_created_at", table_name="approval_tickets")
    op.drop_index("ix_approval_tickets_expires_at", table_name="approval_tickets")
    op.drop_index("ix_approval_tickets_status", table_name="approval_tickets")
    op.drop_index(
        "ix_approval_tickets_primary_user_id", table_name="approval_tickets"
    )
    op.drop_index("ix_approval_tickets_id", table_name="approval_tickets")
    op.drop_table("approval_tickets")

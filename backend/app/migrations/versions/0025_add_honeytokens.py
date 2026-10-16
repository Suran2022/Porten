"""Add honeytokens table for decoy credentials.

Revision ID: 0025
Revises: 0024
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0025"
down_revision: Union[str, None] = "0024"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "honeytokens",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("token_type", sa.String(length=30), nullable=False),
        sa.Column("label", sa.String(length=100), nullable=True),
        sa.Column("planted_by", sa.BigInteger(), nullable=True),
        sa.Column(
            "hit_count", sa.Integer(), server_default=sa.text("0"), nullable=False
        ),
        sa.Column("last_hit_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_hit_ip_hash", sa.String(length=64), nullable=True),
        sa.Column(
            "active",
            sa.Boolean(),
            server_default=sa.text("1"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["planted_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_honeytokens_id", "honeytokens", ["id"], unique=False)
    op.create_index(
        "ix_honeytokens_token_hash", "honeytokens", ["token_hash"], unique=True
    )
    op.create_index(
        "ix_honeytokens_created_at", "honeytokens", ["created_at"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_honeytokens_created_at", table_name="honeytokens")
    op.drop_index("ix_honeytokens_token_hash", table_name="honeytokens")
    op.drop_index("ix_honeytokens_id", table_name="honeytokens")
    op.drop_table("honeytokens")

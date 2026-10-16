"""Add url_reputations table for threat-intel lookups.

Revision ID: 0020
Revises: 0019
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0020"
down_revision: Union[str, None] = "0019"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "url_reputations",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("host", sa.String(length=255), nullable=False),
        sa.Column("level", sa.String(length=20), nullable=False),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column(
            "source",
            sa.String(length=50),
            nullable=False,
            comment="seed | report | review | intel",
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
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
        sa.UniqueConstraint("host", name="uq_url_reputations_host"),
    )
    op.create_index(
        "ix_url_reputations_id", "url_reputations", ["id"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_url_reputations_id", table_name="url_reputations")
    op.drop_table("url_reputations")

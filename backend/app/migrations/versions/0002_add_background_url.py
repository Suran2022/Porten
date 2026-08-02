"""Add background_url to users table.

Revision ID: 0002
Revises: 0001
Create Date: 2026-07-06 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "background_url",
            sa.Text,
            nullable=True,
            comment="Profile background image URL or base64 data URI",
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "background_url")

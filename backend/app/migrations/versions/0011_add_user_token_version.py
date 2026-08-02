"""Add token_version column to users.

Revision ID: 0011
Revises: 0010
Create Date: 2026-07-16 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0011"
down_revision: Union[str, None] = "0010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "token_version",
            sa.Integer,
            nullable=False,
            server_default="0",
            comment="Token version; incremented on logout to invalidate tokens",
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "token_version")

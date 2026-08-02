"""Add gender column to users.

Revision ID: 0010
Revises: 0009
Create Date: 2026-07-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0010"
down_revision: Union[str, None] = "0009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "gender",
            sa.String(50),
            nullable=True,
            comment="User gender identity",
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "gender")

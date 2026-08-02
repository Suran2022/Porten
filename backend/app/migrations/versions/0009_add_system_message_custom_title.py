"""Add custom title flag to system messages.

Revision ID: 0009
Revises: 0008
Create Date: 2026-07-13 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "system_messages",
        sa.Column(
            "is_custom_title",
            sa.Boolean,
            nullable=False,
            server_default=sa.text("0"),
            comment="Whether to display title instead of version label",
        ),
    )


def downgrade() -> None:
    op.drop_column("system_messages", "is_custom_title")

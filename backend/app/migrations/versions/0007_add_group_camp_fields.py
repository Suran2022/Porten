"""Add camp-specific fields to groups.

Revision ID: 0007
Revises: 0006
Create Date: 2026-07-13 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0007"
down_revision: Union[str, None] = "0006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "groups",
        sa.Column(
            "discoverable_by",
            sa.String(50),
            nullable=True,
            comment="How the group can be discovered: name, id, none",
        ),
    )
    op.add_column(
        "groups",
        sa.Column(
            "max_members",
            sa.BigInteger(),
            nullable=True,
            comment="Maximum member limit for the camp",
        ),
    )


def downgrade() -> None:
    op.drop_column("groups", "max_members")
    op.drop_column("groups", "discoverable_by")

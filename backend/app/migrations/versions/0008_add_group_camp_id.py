"""Add unique camp id to groups.

Revision ID: 0008
Revises: 0007
Create Date: 2026-07-13 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "groups",
        sa.Column(
            "camp_id",
            sa.String(20),
            nullable=True,
            comment="Unique camp identifier, e.g. yd123456789",
        ),
    )
    op.create_index("ix_groups_camp_id", "groups", ["camp_id"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_groups_camp_id", table_name="groups")
    op.drop_column("groups", "camp_id")

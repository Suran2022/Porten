"""Add attempts counter to verification_codes.

Revision ID: 0017
Revises: 0016
Create Date: 2026-07-22 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0017"
down_revision: Union[str, None] = "0016"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "verification_codes",
        sa.Column(
            "attempts",
            sa.Integer(),
            nullable=False,
            server_default=sa.text("0"),
            comment="Failed verification attempts against this code",
        ),
    )


def downgrade() -> None:
    op.drop_column("verification_codes", "attempts")

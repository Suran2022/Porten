"""Alter avatar_url to Text to support base64 data URIs.

Revision ID: 0003
Revises: 0002
Create Date: 2026-07-06 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "users",
        "avatar_url",
        existing_type=sa.String(500),
        type_=sa.Text,
        existing_nullable=True,
        existing_comment="Avatar image URL",
        comment="Avatar image URL or base64 data URI",
    )


def downgrade() -> None:
    op.alter_column(
        "users",
        "avatar_url",
        existing_type=sa.Text,
        type_=sa.String(500),
        existing_nullable=True,
        existing_comment="Avatar image URL or base64 data URI",
        comment="Avatar image URL",
    )

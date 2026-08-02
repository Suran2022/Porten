"""Alter avatar_url and background_url to LONGTEXT for large base64 images.

Revision ID: 0004
Revises: 0003
Create Date: 2026-07-06 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "users",
        "avatar_url",
        existing_type=sa.Text,
        type_=mysql.LONGTEXT,
        existing_nullable=True,
        existing_comment="Avatar image URL or base64 data URI",
        comment="Avatar image URL or base64 data URI",
    )
    op.alter_column(
        "users",
        "background_url",
        existing_type=sa.Text,
        type_=mysql.LONGTEXT,
        existing_nullable=True,
        existing_comment="Profile background image URL or base64 data URI",
        comment="Profile background image URL or base64 data URI",
    )


def downgrade() -> None:
    op.alter_column(
        "users",
        "avatar_url",
        existing_type=mysql.LONGTEXT,
        type_=sa.Text,
        existing_nullable=True,
        existing_comment="Avatar image URL or base64 data URI",
        comment="Avatar image URL or base64 data URI",
    )
    op.alter_column(
        "users",
        "background_url",
        existing_type=mysql.LONGTEXT,
        type_=sa.Text,
        existing_nullable=True,
        existing_comment="Profile background image URL or base64 data URI",
        comment="Profile background image URL or base64 data URI",
    )

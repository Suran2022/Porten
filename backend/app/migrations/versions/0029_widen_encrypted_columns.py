"""Widen encrypted columns to LONGTEXT for envelope storage.

Field encryption (design doc §5.4.2) stores AES-256-GCM envelopes,
which are longer than the plaintext they protect. These four columns
hold P0 content or derived content previews and are widened so the
envelope overhead never truncates a value.

Revision ID: 0029
Revises: 0028
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.mysql import LONGTEXT

# revision identifiers, used by Alembic.
revision: str = "0029"
down_revision: Union[str, None] = "0028"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "messages",
        "content",
        existing_type=sa.Text(),
        type_=LONGTEXT(),
        existing_nullable=False,
    )
    op.alter_column(
        "emotion_diaries",
        "content",
        existing_type=sa.Text(),
        type_=LONGTEXT(),
        existing_nullable=False,
    )
    op.alter_column(
        "users",
        "gender",
        existing_type=sa.String(length=50),
        type_=LONGTEXT(),
        existing_nullable=True,
    )
    op.alter_column(
        "conversations",
        "last_message_text",
        existing_type=sa.String(length=500),
        type_=LONGTEXT(),
        existing_nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "conversations",
        "last_message_text",
        existing_type=LONGTEXT(),
        type_=sa.String(length=500),
        existing_nullable=True,
    )
    op.alter_column(
        "users",
        "gender",
        existing_type=LONGTEXT(),
        type_=sa.String(length=50),
        existing_nullable=True,
    )
    op.alter_column(
        "emotion_diaries",
        "content",
        existing_type=LONGTEXT(),
        type_=sa.Text(),
        existing_nullable=False,
    )
    op.alter_column(
        "messages",
        "content",
        existing_type=LONGTEXT(),
        type_=sa.Text(),
        existing_nullable=False,
    )

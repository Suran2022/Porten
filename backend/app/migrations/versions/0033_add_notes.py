"""Add notes table for the personal notebook feature.

Revision ID: 0033
Revises: 0032
Create Date: 2026-10-17 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0033"
down_revision: Union[str, None] = "0032"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "notes",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column(
            "user_id",
            sa.BigInteger(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            comment="Owner of the note",
        ),
        sa.Column(
            "content",
            sa.String(length=2000),
            nullable=False,
            comment="Note body text",
        ),
        sa.Column(
            "tags",
            sa.JSON(),
            nullable=True,
            comment="Up to 4 tags; defaults to ['随记'] when omitted",
        ),
        sa.Column(
            "archived",
            sa.Boolean(),
            server_default=sa.text("0"),
            nullable=False,
            comment="Whether the note is archived",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_notes_user_id", "notes", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_notes_user_id", table_name="notes")
    op.drop_table("notes")

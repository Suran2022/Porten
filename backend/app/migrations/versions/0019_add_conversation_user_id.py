"""Add user_id to conversations (aligns schema with the model).

Revision ID: 0019
Revises: 0018
Create Date: 2026-10-15 00:00:00.000000

The Conversation model carries user_id (one participant of a friend
conversation), but no migration ever added the column. create_all
cannot ALTER an existing table, so databases built from migrations
alone are missing it; this migration closes that gap.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0019"
down_revision: Union[str, None] = "0018"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "conversations",
        sa.Column(
            "user_id",
            sa.BigInteger(),
            nullable=True,
            comment="For friend conversations: one participant id",
        ),
    )
    op.create_index(
        "ix_conversations_user_id", "conversations", ["user_id"], unique=False
    )
    op.create_foreign_key(
        "fk_conversations_user_id",
        "conversations",
        "users",
        ["user_id"],
        ["id"],
        ondelete="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_conversations_user_id", "conversations", type_="foreignkey"
    )
    op.drop_index("ix_conversations_user_id", table_name="conversations")
    op.drop_column("conversations", "user_id")

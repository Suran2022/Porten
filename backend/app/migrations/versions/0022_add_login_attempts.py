"""Add login_attempts table for behavior analysis.

Revision ID: 0022
Revises: 0021
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0022"
down_revision: Union[str, None] = "0021"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "login_attempts",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=True),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("ip_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "success",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("0"),
        ),
        sa.Column("failure_reason", sa.String(length=50), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_login_attempts_id", "login_attempts", ["id"], unique=False)
    op.create_index(
        "ix_login_attempts_user_id", "login_attempts", ["user_id"], unique=False
    )
    op.create_index(
        "ix_login_attempts_email", "login_attempts", ["email"], unique=False
    )
    op.create_index(
        "ix_login_attempts_created_at", "login_attempts", ["created_at"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_login_attempts_created_at", table_name="login_attempts")
    op.drop_index("ix_login_attempts_email", table_name="login_attempts")
    op.drop_index("ix_login_attempts_user_id", table_name="login_attempts")
    op.drop_index("ix_login_attempts_id", table_name="login_attempts")
    op.drop_table("login_attempts")

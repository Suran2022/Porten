"""Add moderation_rule_versions table for admin-managed rule sets.

Revision ID: 0030
Revises: 0029
Create Date: 2026-10-16 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0030"
down_revision: Union[str, None] = "0029"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "moderation_rule_versions",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("patterns", sa.JSON(), nullable=True),
        sa.Column(
            "enabled",
            sa.Boolean(),
            server_default=sa.text("1"),
            nullable=False,
        ),
        sa.Column("created_by", sa.BigInteger(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name", "version", name="uq_rule_name_version"),
        sa.ForeignKeyConstraint(
            ["created_by"], ["users.id"], ondelete="SET NULL"
        ),
    )
    op.create_index(
        "ix_moderation_rule_versions_id",
        "moderation_rule_versions",
        ["id"],
        unique=False,
    )
    op.create_index(
        "ix_moderation_rule_versions_created_at",
        "moderation_rule_versions",
        ["created_at"],
        unique=False,
    )
    op.create_index(
        "ix_rule_name_latest",
        "moderation_rule_versions",
        ["name", "version"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_rule_name_latest", table_name="moderation_rule_versions")
    op.drop_index(
        "ix_moderation_rule_versions_created_at",
        table_name="moderation_rule_versions",
    )
    op.drop_index(
        "ix_moderation_rule_versions_id", table_name="moderation_rule_versions"
    )
    op.drop_table("moderation_rule_versions")

"""Add forensic_records table for four-layer fingerprints.

Revision ID: 0024
Revises: 0023
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0024"
down_revision: Union[str, None] = "0023"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "forensic_records",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("subject_type", sa.String(length=30), nullable=False),
        sa.Column("subject_id", sa.String(length=64), nullable=False),
        sa.Column("content_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "hash_algorithm",
            sa.String(length=20),
            server_default=sa.text("'sha256'"),
            nullable=False,
        ),
        sa.Column("perceptual_hash", sa.String(length=64), nullable=True),
        sa.Column("tsa_token", sa.LargeBinary(), nullable=True),
        sa.Column(
            "tsa_status",
            sa.String(length=20),
            server_default=sa.text("'pending'"),
            nullable=False,
        ),
        sa.Column("tsa_requested_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("tsa_signed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("chain_anchor", sa.String(length=255), nullable=True),
        sa.Column("custody_log", sa.JSON(), nullable=True),
        sa.Column(
            "verified",
            sa.Boolean(),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_forensic_records_id", "forensic_records", ["id"], unique=False
    )
    op.create_index(
        "ix_forensic_records_subject_type",
        "forensic_records",
        ["subject_type"],
        unique=False,
    )
    op.create_index(
        "ix_forensic_records_created_at",
        "forensic_records",
        ["created_at"],
        unique=False,
    )
    op.create_index(
        "ix_forensic_records_subject",
        "forensic_records",
        ["subject_type", "subject_id"],
        unique=False,
    )
    op.create_index(
        "ix_forensic_records_tsa_status",
        "forensic_records",
        ["tsa_status"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_forensic_records_tsa_status", table_name="forensic_records")
    op.drop_index("ix_forensic_records_subject", table_name="forensic_records")
    op.drop_index("ix_forensic_records_created_at", table_name="forensic_records")
    op.drop_index("ix_forensic_records_subject_type", table_name="forensic_records")
    op.drop_index("ix_forensic_records_id", table_name="forensic_records")
    op.drop_table("forensic_records")

"""Add webauthn_credentials table for FIDO2 hardware keys.

Revision ID: 0027
Revises: 0026
Create Date: 2026-10-15 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0027"
down_revision: Union[str, None] = "0026"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "webauthn_credentials",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.BigInteger(), nullable=False),
        sa.Column("credential_id", sa.LargeBinary(length=1024), nullable=False),
        sa.Column("public_key", sa.LargeBinary(), nullable=False),
        sa.Column(
            "sign_count", sa.Integer(), server_default=sa.text("0"), nullable=False
        ),
        sa.Column("aaguid", sa.String(length=36), nullable=True),
        sa.Column("attestation_format", sa.String(length=30), nullable=True),
        sa.Column("transports", sa.JSON(), nullable=True),
        sa.Column("nickname", sa.String(length=100), nullable=True),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "revoked",
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
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("credential_id", name="uq_webauthn_credentials_credential_id"),
    )
    op.create_index(
        "ix_webauthn_credentials_id", "webauthn_credentials", ["id"], unique=False
    )
    op.create_index(
        "ix_webauthn_credentials_user_id",
        "webauthn_credentials",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_webauthn_credentials_created_at",
        "webauthn_credentials",
        ["created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_webauthn_credentials_created_at", table_name="webauthn_credentials"
    )
    op.drop_index(
        "ix_webauthn_credentials_user_id", table_name="webauthn_credentials"
    )
    op.drop_index("ix_webauthn_credentials_id", table_name="webauthn_credentials")
    op.drop_table("webauthn_credentials")

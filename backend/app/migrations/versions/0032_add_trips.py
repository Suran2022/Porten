"""Add trips table for flight journeys created by users.

Revision ID: 0032
Revises: 0031
Create Date: 2026-10-17 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0032"
down_revision: Union[str, None] = "0031"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "trips",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column(
            "user_id",
            sa.BigInteger(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            comment="Owner of the trip",
        ),
        sa.Column(
            "title",
            sa.String(length=100),
            nullable=False,
            comment="Card title, e.g. '2天后将前往大连'",
        ),
        sa.Column(
            "departure_city",
            sa.String(length=50),
            nullable=False,
            comment="Departure city name",
        ),
        sa.Column(
            "departure_airport",
            sa.String(length=100),
            nullable=False,
            comment="Departure airport name",
        ),
        sa.Column(
            "departure_at",
            sa.DateTime(timezone=True),
            nullable=False,
            comment="Departure date and time (UTC)",
        ),
        sa.Column(
            "arrival_city",
            sa.String(length=50),
            nullable=False,
            comment="Arrival city name",
        ),
        sa.Column(
            "arrival_airport",
            sa.String(length=100),
            nullable=False,
            comment="Arrival airport name",
        ),
        sa.Column(
            "arrival_at",
            sa.DateTime(timezone=True),
            nullable=True,
            comment="Arrival date and time (UTC); optional",
        ),
        sa.Column(
            "transfer_type",
            sa.String(length=10),
            server_default=sa.text("'直达'"),
            nullable=False,
            comment="直达 or 中转",
        ),
        sa.Column(
            "airline",
            sa.String(length=50),
            nullable=False,
            comment="Carrier airline name",
        ),
        sa.Column(
            "tips",
            sa.String(length=500),
            nullable=True,
            comment="Reminder text under the card (countdown + weather); optional",
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
    op.create_index("ix_trips_user_id", "trips", ["user_id"], unique=False)
    op.create_index(
        "ix_trips_departure_at", "trips", ["departure_at"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_trips_departure_at", table_name="trips")
    op.drop_index("ix_trips_user_id", table_name="trips")
    op.drop_table("trips")

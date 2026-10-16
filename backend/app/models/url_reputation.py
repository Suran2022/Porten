"""URL reputation model for threat-intel lookups.

Reputation is tracked per host (domain or IP literal, without path) so
one verdict covers all links to that host. Sources: seed list, user
reports, manual review, or an external intel feed.
"""

from datetime import datetime
from typing import Optional

from sqlalchemy import BigInteger, DateTime, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class UrlReputation(Base):
    """Current reputation verdict for a URL host."""

    __tablename__ = "url_reputations"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    host: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        unique=True,
        comment="Domain or IP literal without path",
    )
    level: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        comment="safe | suspicious | malicious",
    )
    reason: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="Human-readable justification for the verdict",
    )
    source: Mapped[str] = mapped_column(
        String(50),
        default="review",
        nullable=False,
        comment="seed | report | review | intel",
    )
    expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Verdict expiry; null means permanent",
    )

    __table_args__ = (UniqueConstraint("host", name="uq_url_reputations_host"),)

"""User-side retention policy model (dual-layer retention).

The user layer lets each user choose how long their own content stays
available; the platform compliance layer (audit retention) is separate
and configured on the operations side. See the security architecture
doc's retention design.
"""

from sqlalchemy import BigInteger, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class RetentionPolicy(Base):
    """Per-user content retention preference."""

    __tablename__ = "retention_policies"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        comment="Owner of this retention policy",
    )
    retention_days: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="User-chosen retention window in days (90-730)",
    )

    __table_args__ = (
        UniqueConstraint("user_id", name="uq_retention_policies_user"),
    )

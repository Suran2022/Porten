"""User-side retention policy service (dual-layer retention, user layer).

The user layer controls how long the user's own content remains
available. Bounds follow the product decision: 3 months minimum,
2 years maximum, 1 year default. The platform compliance layer is
independent and configured on the operations side.
"""

from sqlalchemy.orm import Session

from app.models import RetentionPolicy, User


class RetentionService:
    """Service for per-user content retention preferences."""

    MIN_RETENTION_DAYS = 90
    MAX_RETENTION_DAYS = 730
    DEFAULT_RETENTION_DAYS = 365

    def get_retention_days(self, db: Session, user: User) -> int:
        """Return the effective retention window for a user."""
        policy = db.query(RetentionPolicy).filter_by(user_id=user.id).first()
        if not policy:
            return self.DEFAULT_RETENTION_DAYS
        return policy.retention_days

    def set_retention_days(self, db: Session, user: User, retention_days: int) -> RetentionPolicy:
        """Set the user's retention window.

        Raises:
            ValueError: If retention_days is outside the allowed bounds.
        """
        if not self.MIN_RETENTION_DAYS <= retention_days <= self.MAX_RETENTION_DAYS:
            raise ValueError(
                f"retention_days must be between {self.MIN_RETENTION_DAYS} "
                f"and {self.MAX_RETENTION_DAYS}"
            )

        policy = db.query(RetentionPolicy).filter_by(user_id=user.id).first()
        if policy:
            policy.retention_days = retention_days
        else:
            policy = RetentionPolicy(
                user_id=user.id,
                retention_days=retention_days,
            )
            db.add(policy)
        db.commit()
        db.refresh(policy)
        return policy

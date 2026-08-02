"""Porten account number generation service."""

import random
from typing import Optional

from sqlalchemy.orm import Session

from app.models import User


class PortenIdService:
    """Service for generating unique Porten account numbers."""

    # Digits allowed in a Porten ID (0-9 excluding 4)
    ALLOWED_DIGITS = [str(d) for d in range(10) if d != 4]

    def __init__(self, max_attempts: int = 100):
        self.max_attempts = max_attempts

    def generate(self, length: Optional[int] = None) -> str:
        """
        Generate a random Porten ID.

        Rules:
        - 6 to 12 digits
        - Only digits 0-9 excluding 4
        """
        if length is None:
            length = random.randint(6, 12)
        if not (6 <= length <= 12):
            raise ValueError("Porten ID length must be between 6 and 12")
        return "".join(random.choices(self.ALLOWED_DIGITS, k=length))

    def generate_unique(self, db: Session) -> str:
        """Generate a unique Porten ID that does not exist in the database."""
        for _ in range(self.max_attempts):
            candidate = self.generate()
            exists = db.query(User).filter_by(porten_id=candidate).first() is not None
            if not exists:
                return candidate
        raise RuntimeError("Unable to generate a unique Porten ID")

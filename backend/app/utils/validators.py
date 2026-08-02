"""Input validators."""

import re


EMAIL_REGEX = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")


def validate_password(password: str) -> None:
    """
    Validate password strength.

    Rules:
    - At least one letter
    - At least one digit
    """
    if not re.search(r"[A-Za-z]", password):
        raise ValueError("password must contain at least one letter")
    if not re.search(r"\d", password):
        raise ValueError("password must contain at least one digit")


def validate_porten_id(porten_id: str) -> bool:
    """Validate Porten account number format."""
    if not (6 <= len(porten_id) <= 12):
        return False
    if not porten_id.isdigit():
        return False
    if "4" in porten_id:
        return False
    return True

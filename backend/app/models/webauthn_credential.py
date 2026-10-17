"""WebAuthn credential model (FIDO2 hardware keys, design doc §10.1).

Stores registered FIDO2 credentials used for the two-person / two-key
approval flow (and any future strong-authentication needs). The public
key and signature counter are kept per credential so assertion
verification is stateless; the private key never leaves the hardware
token.

The carrier is abstracted at the service layer: this table is the
default FIDO2/WebAuthn implementation, with national-cipher USB keys
reserved as an alternative implementation behind the same interface.
"""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    LargeBinary,
    String,
)
from sqlalchemy.dialects.mysql import VARBINARY
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class WebauthnCredential(Base):
    """A registered FIDO2 hardware key bound to one user."""

    __tablename__ = "webauthn_credentials"

    id: Mapped[int] = mapped_column(
        BigInteger, primary_key=True, autoincrement=True, index=True
    )
    user_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Owner of the credential",
    )
    # VARBINARY (not BLOB) so the UNIQUE constraint works on MySQL:
    # BLOB/TEXT columns cannot be indexed without a key length there.
    credential_id: Mapped[bytes] = mapped_column(
        VARBINARY(1024),
        nullable=False,
        unique=True,
        comment="Raw credential id bytes issued by the authenticator",
    )
    public_key: Mapped[bytes] = mapped_column(
        LargeBinary,
        nullable=False,
        comment="COSE public key bytes for assertion verification",
    )
    sign_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
        comment="Signature counter for clone detection",
    )
    aaguid: Mapped[Optional[str]] = mapped_column(
        String(36),
        nullable=True,
        comment="Authenticator model identifier",
    )
    attestation_format: Mapped[Optional[str]] = mapped_column(
        String(30),
        nullable=True,
        comment="Attestation statement format seen at registration",
    )
    transports: Mapped[Optional[list[str]]] = mapped_column(
        JSON,
        nullable=True,
        comment="Hints for how to reach the key, e.g. [usb, nfc]",
    )
    nickname: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="Operator-assigned label, e.g. primary-key-1",
    )
    last_used_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    revoked: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        comment="Whether the credential has been revoked (lost key etc.)",
    )
    created_at: Mapped[datetime] = mapped_column(
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,
    )

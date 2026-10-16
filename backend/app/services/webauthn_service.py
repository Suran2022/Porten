"""FIDO2/WebAuthn key carrier (design doc §10.1).

Default implementation of the :class:`~app.security.protocols.KeyCarrier`
abstraction: hardware keys are enrolled with a registration ceremony
(attestation) and later prove possession with an assertion ceremony
(signature over the server challenge). Only the public key and the
signature counter are stored; private keys never leave the token.

Phishing resistance comes from the origin binding: assertions are only
accepted for the configured admin origin, so a decoy site cannot
relay a key press.

The approval flow passes the ticket nonce as the assertion challenge
(durable, server-side), so approval ceremonies need no extra state;
standalone ceremonies use a short-lived in-process challenge store.
National-cipher USB keys are reserved as an alternative carrier behind
the same protocol and are intentionally not implemented here.
"""

import json
import logging
import secrets
import threading
import time
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session
from webauthn import (
    generate_authentication_options,
    generate_registration_options,
    options_to_json,
    verify_authentication_response,
    verify_registration_response,
)
from webauthn.helpers import base64url_to_bytes, bytes_to_base64url
from webauthn.helpers.structs import (
    AuthenticatorSelectionCriteria,
    PublicKeyCredentialDescriptor,
    ResidentKeyRequirement,
    UserVerificationRequirement,
)

from app.config import get_settings
from app.models import User, WebauthnCredential

logger = logging.getLogger(__name__)

# Ceremony timeout advertised to the client (milliseconds).
_CEREMONY_TIMEOUT_MS = 60000


class KeyCarrierError(RuntimeError):
    """Raised when a key ceremony fails verification.

    Callers treat this as a plain rejection: the message never
    contains key material or internal state.
    """


class _ChallengeStore:
    """Short-lived server-side WebAuthn challenges (in-process).

    Challenges are single-use and expire after the configured TTL. The
    admin plane is an internal, low-concurrency surface, so an
    in-process store is sufficient; a multi-region deployment can move
    this to Redis without touching the carrier API.
    """

    def __init__(self, ttl_seconds: int) -> None:
        self._ttl_seconds = ttl_seconds
        self._lock = threading.Lock()
        self._entries: dict = {}

    def put(self, key: str, challenge: bytes) -> None:
        with self._lock:
            self._purge()
            self._entries[key] = (challenge, time.monotonic() + self._ttl_seconds)

    def pop(self, key: str) -> Optional[bytes]:
        """Remove and return the challenge for ``key``, if still valid."""
        with self._lock:
            self._purge()
            entry = self._entries.pop(key, None)
            return entry[0] if entry else None

    def _purge(self) -> None:
        now = time.monotonic()
        expired = [key for key, (_, exp) in self._entries.items() if exp <= now]
        for key in expired:
            del self._entries[key]


class Fido2KeyCarrier:
    """FIDO2/WebAuthn carrier: enrollment and key-press verification."""

    def __init__(
        self,
        *,
        rp_id: Optional[str] = None,
        rp_name: Optional[str] = None,
        origin: Optional[str] = None,
        challenge_ttl_seconds: Optional[int] = None,
    ) -> None:
        settings = get_settings()
        self._rp_id = rp_id or settings.webauthn_rp_id
        self._rp_name = rp_name or settings.webauthn_rp_name
        self._origin = origin or settings.webauthn_origin
        ttl = (
            challenge_ttl_seconds
            if challenge_ttl_seconds is not None
            else settings.webauthn_challenge_ttl_seconds
        )
        self._challenges = _ChallengeStore(ttl)

    # -- enrollment ---------------------------------------------------------

    def begin_registration(self, db: Session, user_id: int) -> dict:
        """Start key enrollment; returns the client options dict."""
        user = db.get(User, user_id)
        if user is None:
            raise KeyCarrierError("unknown user")
        options = generate_registration_options(
            rp_id=self._rp_id,
            rp_name=self._rp_name,
            user_id=str(user_id).encode("utf-8"),
            user_name=user.email,
            user_display_name=user.nickname or user.email,
            challenge=secrets.token_bytes(32),
            timeout=_CEREMONY_TIMEOUT_MS,
            authenticator_selection=AuthenticatorSelectionCriteria(
                resident_key=ResidentKeyRequirement.PREFERRED,
                user_verification=UserVerificationRequirement.PREFERRED,
            ),
            exclude_credentials=self._active_descriptors(db, user_id),
        )
        self._challenges.put(f"reg:{user_id}", options.challenge)
        return json.loads(options_to_json(options))

    def complete_registration(
        self, db: Session, user_id: int, credential: dict
    ) -> str:
        """Finish enrollment; returns the stored credential id (base64url)."""
        challenge = self._challenges.pop(f"reg:{user_id}")
        if challenge is None:
            raise KeyCarrierError("registration challenge expired or unknown")
        try:
            verification = verify_registration_response(
                credential=credential,
                expected_challenge=challenge,
                expected_rp_id=self._rp_id,
                expected_origin=self._origin,
            )
        except Exception as exc:
            raise KeyCarrierError(f"registration verification failed: {exc}") from exc
        existing = (
            db.query(WebauthnCredential)
            .filter_by(credential_id=verification.credential_id)
            .first()
        )
        if existing is not None:
            raise KeyCarrierError("credential already registered")
        row = WebauthnCredential(
            user_id=user_id,
            credential_id=verification.credential_id,
            public_key=verification.credential_public_key,
            sign_count=verification.sign_count,
            aaguid=str(verification.aaguid),
            attestation_format=str(verification.fmt),
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        return bytes_to_base64url(verification.credential_id)

    # -- key press ----------------------------------------------------------

    def begin_assertion(
        self, db: Session, user_id: int, challenge: Optional[bytes] = None
    ) -> dict:
        """Start a key-press ceremony; returns the client options dict.

        With ``challenge`` given (approval flow: the ticket nonce) it
        is used verbatim; otherwise a short-lived challenge is stored.
        """
        if db.get(User, user_id) is None:
            raise KeyCarrierError("unknown user")
        if challenge is None:
            challenge = secrets.token_bytes(32)
            self._challenges.put(f"auth:{user_id}", challenge)
        options = generate_authentication_options(
            rp_id=self._rp_id,
            challenge=challenge,
            timeout=_CEREMONY_TIMEOUT_MS,
            allow_credentials=self._active_descriptors(db, user_id),
            user_verification=UserVerificationRequirement.REQUIRED,
        )
        return json.loads(options_to_json(options))

    def verify_assertion(
        self,
        db: Session,
        user_id: int,
        credential: dict,
        challenge: Optional[bytes] = None,
    ) -> str:
        """Verify one key press; returns the credential id used."""
        raw_id = credential.get("id") or credential.get("rawId")
        if not raw_id:
            raise KeyCarrierError("missing credential id")
        try:
            credential_bytes = base64url_to_bytes(raw_id)
        except Exception as exc:
            raise KeyCarrierError("malformed credential id") from exc
        row = (
            db.query(WebauthnCredential)
            .filter_by(credential_id=credential_bytes)
            .first()
        )
        if row is None or row.user_id != user_id or row.revoked:
            # Unknown, foreign or revoked keys are rejected identically.
            raise KeyCarrierError("credential not usable")
        expected = challenge
        if expected is None:
            expected = self._challenges.pop(f"auth:{user_id}")
            if expected is None:
                raise KeyCarrierError("assertion challenge expired or unknown")
        try:
            verification = verify_authentication_response(
                credential=credential,
                expected_challenge=expected,
                expected_rp_id=self._rp_id,
                expected_origin=self._origin,
                credential_public_key=row.public_key,
                credential_current_sign_count=row.sign_count,
                require_user_verification=True,
            )
        except Exception as exc:
            raise KeyCarrierError(f"assertion verification failed: {exc}") from exc
        row.sign_count = verification.new_sign_count
        row.last_used_at = datetime.now(timezone.utc)
        db.commit()
        return bytes_to_base64url(credential_bytes)

    # -- lifecycle ----------------------------------------------------------

    def revoke(self, db: Session, credential_id: str) -> bool:
        """Deactivate a credential (lost key); False when unknown."""
        try:
            credential_bytes = base64url_to_bytes(credential_id)
        except Exception:
            return False
        row = (
            db.query(WebauthnCredential)
            .filter_by(credential_id=credential_bytes)
            .first()
        )
        if row is None or row.revoked:
            return False
        row.revoked = True
        db.commit()
        return True

    def list_credentials(
        self, db: Session, user_id: int, include_revoked: bool = False
    ) -> list:
        """List enrolled keys for the admin surface (public data only)."""
        query = db.query(WebauthnCredential).filter_by(user_id=user_id)
        if not include_revoked:
            query = query.filter_by(revoked=False)
        return query.order_by(WebauthnCredential.id.desc()).all()

    # -- internals ----------------------------------------------------------

    def _active_descriptors(
        self, db: Session, user_id: int
    ) -> list:
        """Credential descriptors offered to the client during ceremonies."""
        rows = (
            db.query(WebauthnCredential)
            .filter_by(user_id=user_id, revoked=False)
            .all()
        )
        return [
            PublicKeyCredentialDescriptor(id=row.credential_id)
            for row in rows
        ]


fido2_key_carrier = Fido2KeyCarrier()

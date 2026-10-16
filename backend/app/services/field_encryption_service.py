"""Application-layer field encryption for P0 fields (design doc §5.4.2).

Envelope encryption (AES-256-GCM):

* every value is sealed with a fresh data key (DEK);
* the DEK is wrapped with a key-encryption key (KEK) whose source is
  the environment (all profiles) or a KMS (standard/advanced);
* the stored envelope is ``pfx1.<kid>.<wrapped_dek>.<payload>`` with
  base64url segments, so key rotation never requires rewriting data.

Failure policy: when encryption is enabled but no key resolves, values
pass through unchanged and a warning is logged (set
``SECURITY_FIELD_ENCRYPTION_REQUIRED`` to fail startup instead). A
cryptographic failure on an actual envelope (wrong key, tampering)
raises :class:`EnvelopeError` instead of silently returning garbage.
Legacy plaintext rows (written before encryption was enabled) are
detected by the missing envelope prefix and returned unchanged.
"""

import base64
import logging
import os
import threading
import time
from typing import Optional

import httpx
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.config import get_settings
from app.security.protocols import FieldEncryptor, KeyProvider

logger = logging.getLogger(__name__)

settings = get_settings()

# Envelope format: pfx1.<kid>.<wrapped_dek_b64url>.<payload_b64url>
ENVELOPE_VERSION = "pfx1"
ENVELOPE_SEGMENTS = 4
KEY_SIZE = 32  # AES-256
NONCE_SIZE = 12  # GCM standard nonce
TAG_SIZE = 16
WRAPPED_DEK_SIZE = NONCE_SIZE + KEY_SIZE + TAG_SIZE
MIN_PAYLOAD_SIZE = NONCE_SIZE + TAG_SIZE
_KEK_AAD = b"porten-field-kek-v1"


class EnvelopeError(ValueError):
    """Raised when an envelope cannot be produced or opened."""


def _b64u_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64u_decode(encoded: str) -> Optional[bytes]:
    """Decode base64url without padding, returning None on malformed input."""
    padding = "=" * (-len(encoded) % 4)
    try:
        return base64.urlsafe_b64decode(encoded + padding)
    except (ValueError, TypeError):
        return None


def _decode_kek(encoded: str) -> Optional[bytes]:
    """Decode and validate a base64-encoded 256-bit KEK.

    Accepts both standard and URL-safe alphabets, with or without
    padding, and tolerates surrounding whitespace (``openssl rand
    -base64 32`` output). Returns None for anything that is not a
    32-byte key.
    """
    cleaned = "".join(str(encoded).split())
    if not cleaned:
        return None
    raw = _b64u_decode(cleaned) or _b64u_std_decode(cleaned)
    if raw is None or len(raw) != KEY_SIZE:
        return None
    return raw


def _b64u_std_decode(encoded: str) -> Optional[bytes]:
    try:
        return base64.b64decode(encoded, validate=True)
    except (ValueError, TypeError):
        return None


class EnvKeyProvider:
    """Key provider reading KEKs from configuration (all profiles).

    Supports a rotation window: the previous key stays resolvable for
    decryption while new values are encrypted under the active key.
    """

    def __init__(
        self,
        *,
        kek: Optional[str] = None,
        kid: Optional[str] = None,
        previous_kek: Optional[str] = None,
        previous_kid: Optional[str] = None,
    ) -> None:
        active_kek = settings.security_field_kek if kek is None else kek
        active_kid = settings.security_field_kek_kid if kid is None else kid
        old_kek = (
            settings.security_field_kek_previous
            if previous_kek is None
            else previous_kek
        )
        old_kid = (
            settings.security_field_kek_previous_kid
            if previous_kid is None
            else previous_kid
        )

        self._keys: dict[str, bytes] = {}
        self._active_kid: Optional[str] = None
        if active_kek:
            decoded = _decode_kek(active_kek)
            if decoded is None:
                logger.error(
                    "security_field_kek is not a valid base64 32-byte key; "
                    "field encryption stays inactive"
                )
            else:
                self._keys[active_kid] = decoded
                self._active_kid = active_kid
        if old_kek and old_kid and old_kid != active_kid:
            decoded = _decode_kek(old_kek)
            if decoded is None:
                logger.error(
                    "security_field_kek_previous is not a valid base64 "
                    "32-byte key; rotation window ignores it"
                )
            else:
                self._keys[old_kid] = decoded

    def active_kid(self) -> Optional[str]:
        """Return the key id new values are encrypted under, if any."""
        return self._active_kid

    def resolve(self, kid: str) -> Optional[bytes]:
        """Return the raw KEK bytes for a key id, or None if unknown."""
        return self._keys.get(kid)


class KmsKeyProvider:
    """Key provider backed by a remote KMS (standard/advanced).

    KEKs are fetched over HTTPS and cached in memory for a bounded TTL;
    the plaintext key never touches disk. Degradation contract: when the
    KMS is unreachable the fallback provider (environment key) is used,
    so a KMS outage degrades key sourcing instead of failing writes.
    """

    def __init__(
        self,
        *,
        fallback: EnvKeyProvider,
        client: Optional[httpx.Client] = None,
    ) -> None:
        self._base_url = settings.security_kms_url.rstrip("/")
        self._key_id = settings.security_kms_key_id
        self._cache_seconds = settings.security_kms_cache_seconds
        self._fallback = fallback
        self._client = client or httpx.Client(
            base_url=self._base_url,
            timeout=settings.security_kms_timeout_seconds,
        )
        self._cache: dict[str, tuple[bytes, float]] = {}
        self._lock = threading.Lock()

    def active_kid(self) -> Optional[str]:
        """Return the KMS key id, falling back to the env key id."""
        return self._key_id or self._fallback.active_kid()

    def resolve(self, kid: str) -> Optional[bytes]:
        """Return the KEK for a key id, or None when unavailable."""
        cached = self._cached(kid)
        if cached is not None:
            return cached
        try:
            response = self._client.get(f"{self._base_url}/v1/keys/{kid}")
            response.raise_for_status()
            key = _decode_kek(str(response.json().get("key", "")))
            if key is None:
                logger.error("kms returned an invalid key for kid=%s", kid)
            else:
                self._remember(kid, key)
                return key
        except Exception:
            logger.warning(
                "kms unreachable while resolving kid=%s; "
                "falling back to the environment key",
                kid,
                exc_info=True,
            )
        return self._fallback.resolve(kid)

    def _cached(self, kid: str) -> Optional[bytes]:
        with self._lock:
            entry = self._cache.get(kid)
            if entry is None:
                return None
            key, fetched_at = entry
            if time.monotonic() - fetched_at > self._cache_seconds:
                del self._cache[kid]
                return None
            return key

    def _remember(self, kid: str, key: bytes) -> None:
        with self._lock:
            self._cache[kid] = (key, time.monotonic())


class FieldEncryptor:
    """AES-256-GCM envelope encryptor for P0 fields.

    Layout (dot-separated, base64url segments without padding)::

        pfx1.<kid>.<wrapped_dek>.<payload>

    ``wrapped_dek`` is the per-value data key sealed with the KEK
    (AAD binds it to the scheme); ``payload`` is the plaintext sealed
    with the DEK (AAD binds it to the version and key id).
    """

    def __init__(self, provider: KeyProvider, *, enabled: bool = True) -> None:
        self._provider = provider
        self._enabled = enabled

    @property
    def available(self) -> bool:
        """True when encryption is on and a key source is configured."""
        return self._enabled and self._provider.active_kid() is not None

    def describe(self) -> dict:
        """Return diagnostics for the admin surface and startup logs."""
        return {
            "enabled": self._enabled,
            "available": self.available,
            "active_kid": self._provider.active_kid(),
            "provider": type(self._provider).__name__,
        }

    def encrypt(self, plaintext: str) -> str:
        """Return the envelope for a plaintext value.

        Falls back to the plaintext when encryption is not configured;
        raises :class:`EnvelopeError` when it is configured but the key
        cannot be resolved or sealing fails (fail-closed).
        """
        if not self.available:
            return plaintext
        kid = self._provider.active_kid()
        assert kid is not None
        kek = self._provider.resolve(kid)
        if kek is None:
            raise EnvelopeError(
                f"field encryption key {kid!r} is unavailable"
            )
        dek = os.urandom(KEY_SIZE)
        wrapped_dek = self._wrap(kek, dek)
        payload = self._seal(dek, plaintext, self._payload_aad(kid))
        return ".".join(
            (
                ENVELOPE_VERSION,
                kid,
                _b64u_encode(wrapped_dek),
                _b64u_encode(payload),
            )
        )

    def decrypt(self, value: str) -> str:
        """Return the plaintext for a stored value.

        Non-envelope values (legacy plaintext rows) pass through
        unchanged; structurally valid envelopes that fail to open raise
        :class:`EnvelopeError`.
        """
        parsed = self._parse(value)
        if parsed is None:
            return value
        kid, wrapped_dek, payload = parsed
        kek = self._provider.resolve(kid)
        if kek is None:
            raise EnvelopeError(f"unknown field encryption key id {kid!r}")
        dek = self._unwrap(kek, wrapped_dek)
        return self._open(dek, payload, self._payload_aad(kid))

    @staticmethod
    def _payload_aad(kid: str) -> bytes:
        return f"{ENVELOPE_VERSION}.{kid}".encode("ascii")

    @staticmethod
    def _wrap(kek: bytes, dek: bytes) -> bytes:
        nonce = os.urandom(NONCE_SIZE)
        sealed = AESGCM(kek).encrypt(nonce, dek, _KEK_AAD)
        return nonce + sealed

    @staticmethod
    def _unwrap(kek: bytes, wrapped: bytes) -> bytes:
        try:
            nonce, sealed = wrapped[:NONCE_SIZE], wrapped[NONCE_SIZE:]
            return AESGCM(kek).decrypt(nonce, sealed, _KEK_AAD)
        except InvalidTag as exc:
            raise EnvelopeError("field encryption key unwrap failed") from exc

    @staticmethod
    def _seal(dek: bytes, plaintext: str, aad: bytes) -> bytes:
        nonce = os.urandom(NONCE_SIZE)
        sealed = AESGCM(dek).encrypt(nonce, plaintext.encode("utf-8"), aad)
        return nonce + sealed

    @staticmethod
    def _open(dek: bytes, payload: bytes, aad: bytes) -> str:
        try:
            nonce, sealed = payload[:NONCE_SIZE], payload[NONCE_SIZE:]
            plaintext = AESGCM(dek).decrypt(nonce, sealed, aad)
        except InvalidTag as exc:
            raise EnvelopeError("field envelope failed to open") from exc
        return plaintext.decode("utf-8")

    @classmethod
    def _parse(cls, value: str) -> Optional[tuple[str, bytes, bytes]]:
        """Parse an envelope, returning None for non-envelope values."""
        if not value.startswith(ENVELOPE_VERSION + "."):
            return None
        parts = value.split(".")
        if len(parts) != ENVELOPE_SEGMENTS:
            return None
        _, kid, wrapped_b64, payload_b64 = parts
        if not kid:
            return None
        wrapped = _b64u_decode(wrapped_b64)
        payload = _b64u_decode(payload_b64)
        if wrapped is None or payload is None:
            return None
        if len(wrapped) != WRAPPED_DEK_SIZE or len(payload) < MIN_PAYLOAD_SIZE:
            return None
        return kid, wrapped, payload


_encryptors: dict[str, FieldEncryptor] = {}
_encryptors_lock = threading.Lock()


def build_field_encryptor(profile: Optional[str] = None) -> FieldEncryptor:
    """Assemble the field encryptor for the given or configured profile.

    lite always uses the environment key; standard/advanced use the KMS
    when configured (with the environment key as degradation fallback).
    """
    active = profile or settings.security_profile
    env_provider = EnvKeyProvider()
    provider: KeyProvider = env_provider
    if settings.security_kms_url and active != "lite":
        provider = KmsKeyProvider(fallback=env_provider)
    elif settings.security_kms_url:
        logger.warning(
            "lite profile ignores security_kms_url; "
            "using the environment field-encryption key"
        )

    encryptor = FieldEncryptor(
        provider, enabled=settings.security_field_encryption_enabled
    )
    if settings.security_field_encryption_required and not encryptor.available:
        raise RuntimeError(
            "field encryption is required but no key resolves "
            f"(profile={active}, provider={type(provider).__name__})"
        )
    if settings.security_field_encryption_required and active != "lite":
        # Fail fast on an unreachable KMS instead of at first write.
        kid = provider.active_kid()
        assert kid is not None
        if provider.resolve(kid) is None:
            raise RuntimeError(
                f"field encryption key {kid!r} is unreachable "
                f"(kms={settings.security_kms_url})"
            )
    if not encryptor.available and settings.security_field_encryption_enabled:
        logger.warning(
            "field encryption is enabled but no key is configured; "
            "P0 fields are stored in plaintext until a key is provided"
        )
    return encryptor


def get_field_encryptor(profile: Optional[str] = None) -> FieldEncryptor:
    """Return the process-wide field encryptor for a profile (cached)."""
    key = profile or settings.security_profile
    with _encryptors_lock:
        encryptor = _encryptors.get(key)
        if encryptor is None:
            encryptor = build_field_encryptor(key)
            _encryptors[key] = encryptor
        return encryptor


def reset_field_encryptors() -> None:
    """Drop cached encryptors (test hook for settings changes)."""
    with _encryptors_lock:
        _encryptors.clear()

"""Security capability protocols shared by all profiles.

Business code consumes security capabilities through these protocols only.
Concrete implementations are assembled by the profile factory, so switching
between lite/standard/advanced requires no business-code changes.
"""

from typing import Optional, Protocol, runtime_checkable

from sqlalchemy.orm import Session

from app.schemas.security import FetchResult, ModerationResult, UrlVerdict


@runtime_checkable
class RateLimiter(Protocol):
    """Sliding-window rate limiter capability."""

    def allow(self, key: str, limit: int, window_seconds: int) -> bool:
        """Return True if the request identified by key is within quota."""
        ...


@runtime_checkable
class UrlScanner(Protocol):
    """Chat URL reputation capability."""

    def scan(self, url: str) -> UrlVerdict:
        """Return the reputation verdict for a single URL."""
        ...


@runtime_checkable
class ContentModerator(Protocol):
    """Synchronous send-time content moderation capability."""

    def check(self, content: str, message_type: str) -> ModerationResult:
        """Return the allow/block decision for confirmed-level violations."""
        ...


@runtime_checkable
class SecurityEventSink(Protocol):
    """Security event recording capability."""

    def emit(
        self,
        db: Session,
        event_type: str,
        severity: str = "info",
        user_id: Optional[int] = None,
        detail: Optional[str] = None,
    ) -> None:
        """Persist a security event."""
        ...


@runtime_checkable
class EventQueuePublisher(Protocol):
    """Asynchronous security event queue capability (standard+)."""

    def publish(self, event_type: str, payload: dict) -> None:
        """Enqueue an event for asynchronous review processing."""
        ...


@runtime_checkable
class WafRuleProvider(Protocol):
    """Versioned WAF rule set with hot-reload capability."""

    def current_version(self) -> str:
        """Return the version identifier of the active rule set."""
        ...

    def matches(self, path: str, query: str) -> Optional[str]:
        """Return the matched rule name for a request, or None."""
        ...


@runtime_checkable
class FileSanitizer(Protocol):
    """Uploaded file sanitization capability."""

    def sanitize(self, file_path: str, declared_type: str) -> str:
        """Return the sanitized file path, or raise on refusal."""
        ...


@runtime_checkable
class EdgeBlocklist(Protocol):
    """Runtime-updatable request blocklist (standard+)."""

    def is_blocked(self, ip: str) -> bool:
        """Return True when the client IP is currently blocked."""
        ...


@runtime_checkable
class BehaviorAnalyzer(Protocol):
    """User behavior analysis capability (UEBA)."""

    def assess(
        self,
        db: Session,
        user_id: int,
        action: str,
        context: Optional[dict] = None,
    ) -> Optional[dict]:
        """Return a risk assessment dict, or None when nothing notable."""
        ...


@runtime_checkable
class FieldEncryptor(Protocol):
    """Application-layer field encryption capability (design doc §5.4.2)."""

    def encrypt(self, plaintext: str) -> str:
        """Return an opaque envelope for the given plaintext."""
        ...

    def decrypt(self, envelope: str) -> str:
        """Return the plaintext for a stored envelope.

        Values that are not envelopes (legacy plaintext rows) are
        returned unchanged.
        """
        ...


@runtime_checkable
class KeyProvider(Protocol):
    """Source of key-encryption keys (KEK) for envelope encryption."""

    def active_kid(self) -> Optional[str]:
        """Return the key id new values are encrypted under, if any."""
        ...

    def resolve(self, kid: str) -> Optional[bytes]:
        """Return the raw KEK bytes for a key id, or None if unknown."""
        ...


@runtime_checkable
class UrlFetchSandbox(Protocol):
    """SSRF-hardened URL fetch capability (design doc §5.5)."""

    def fetch(self, url: str) -> FetchResult:
        """Fetch a URL under the sandbox policy.

        Never raises for network-level failures: they are reported in
        the returned FetchResult so callers can stay fail-open.
        """
        ...


@runtime_checkable
class KeyCarrier(Protocol):
    """Hardware key carrier for the two-person rule (design doc §10.1).

    Sensitive operations require two hardware keys pressed in sequence.
    This protocol abstracts the key carrier so the compliance-driven
    switch between carriers never touches business code:

    * the default implementation is FIDO2/WebAuthn (phishing-resistant,
      mature Python ecosystem);
    * national-cipher (SM) USB keys are reserved as an alternative
      implementation behind this same interface -- the vendor SDKs are
      closed, so the carrier is only added when a compliance audit
      actually requires it.

    Implementations verify key ownership cryptographically and return
    the credential id that was used; every failure raises
    :class:`KeyCarrierError` so callers can reject uniformly.
    """

    def begin_registration(self, db: Session, user_id: int) -> dict:
        """Start a key-enrollment ceremony; returns client options.

        The challenge is kept server-side (short-lived) and must be
        presented back by the client in ``complete_registration``.
        """
        ...

    def complete_registration(
        self, db: Session, user_id: int, credential: dict
    ) -> str:
        """Finish enrollment; returns the stored credential id.

        Verifies the attestation against the server-side challenge and
        persists the public key for later assertion checks.
        """
        ...

    def begin_assertion(
        self, db: Session, user_id: int, challenge: Optional[bytes] = None
    ) -> dict:
        """Start a key-press ceremony; returns client options.

        When ``challenge`` is given (the approval flow passes the
        ticket nonce) it is used verbatim instead of a freshly stored
        one, keeping the ceremony bound to a durable server-side
        value; otherwise a short-lived challenge is stored.
        """
        ...

    def verify_assertion(
        self,
        db: Session,
        user_id: int,
        credential: dict,
        challenge: Optional[bytes] = None,
    ) -> str:
        """Verify one key press; returns the credential id used.

        The signature is checked against the stored public key of a
        credential owned by ``user_id``; the signature counter and
        last-used timestamp are refreshed on success.
        """
        ...

    def revoke(self, db: Session, credential_id: str) -> bool:
        """Deactivate a credential (lost key); False when unknown."""
        ...

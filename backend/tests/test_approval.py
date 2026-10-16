"""Tests for the two-person / two-key approval flow (design doc §10.1).

The key carrier is exercised against a virtual software authenticator
with real cryptography (P-256/ES256, ``none`` attestation), so the
FIDO2/WebAuthn verification path runs the production code end to end.
Approval state-machine and audit-trail assertions run against
in-memory SQLite with the real hash-chained audit service.
"""

import asyncio
import hashlib
import json
import secrets
from datetime import datetime, timedelta, timezone

import cbor2
import pytest
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from sqlalchemy import Integer, Text, create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from webauthn.helpers import base64url_to_bytes, bytes_to_base64url

from app.models import ApprovalTicket, AuditLog, User, WebauthnCredential
from app.security.protocols import KeyCarrier
from app.services.audit_chain_service import AuditChainError
from app.services.approval_service import (
    ApprovalError,
    ApprovalService,
    approval_expiry_task,
)
from app.services.webauthn_service import Fido2KeyCarrier, KeyCarrierError

RP_ID = "admin.porten.test"
ORIGIN = "https://admin.porten.test"


# ---------------------------------------------------------------------------
# Virtual authenticator
# ---------------------------------------------------------------------------


class _VirtualAuthenticator:
    """Software stand-in for a FIDO2 hardware key with real crypto.

    Produces registration (``none`` attestation) and assertion
    responses a browser would emit; negative tests mutate rp id,
    origin, signature or counter to exercise every rejection path.
    """

    def __init__(
        self,
        rp_id: str = RP_ID,
        origin: str = ORIGIN,
        credential_id: bytes = b"",
    ) -> None:
        self._key = ec.generate_private_key(ec.SECP256R1())
        self._rp_id = rp_id
        self._origin = origin
        self.credential_id = credential_id or secrets.token_bytes(32)
        self._counter = 0

    def _rp_id_hash(self) -> bytes:
        return hashlib.sha256(self._rp_id.encode("utf-8")).digest()

    def _client_data(self, ceremony: str, challenge: bytes) -> bytes:
        return json.dumps(
            {
                "type": ceremony,
                "challenge": bytes_to_base64url(challenge),
                "origin": self._origin,
            },
            separators=(",", ":"),
        ).encode("utf-8")

    def register(self, challenge: bytes) -> dict:
        self._counter += 1
        numbers = self._key.public_key().public_numbers()
        cose_key = cbor2.dumps(
            {
                1: 2,  # kty: EC2
                3: -7,  # alg: ES256
                -1: 1,  # crv: P-256
                -2: numbers.x.to_bytes(32, "big"),
                -3: numbers.y.to_bytes(32, "big"),
            }
        )
        auth_data = (
            self._rp_id_hash()
            + bytes([0x45])  # UP | UV | AT
            + self._counter.to_bytes(4, "big")
            + b"\x00" * 16  # aaguid
            + len(self.credential_id).to_bytes(2, "big")
            + self.credential_id
            + cose_key
        )
        attestation = cbor2.dumps(
            {"fmt": "none", "attStmt": {}, "authData": auth_data}
        )
        client_data = self._client_data("webauthn.create", challenge)
        credential_id = bytes_to_base64url(self.credential_id)
        return {
            "id": credential_id,
            "rawId": credential_id,
            "type": "public-key",
            "clientExtensionResults": {},
            "response": {
                "clientDataJSON": bytes_to_base64url(client_data),
                "attestationObject": bytes_to_base64url(attestation),
                "transports": ["usb"],
            },
        }

    def press(
        self,
        challenge: bytes,
        rp_id: str = "",
        origin: str = "",
    ) -> dict:
        self._counter += 1
        # Overrides let tests forge wrong-origin / wrong-rp responses
        # with an otherwise legitimately enrolled key.
        rp_id = rp_id or self._rp_id
        origin = origin or self._origin
        auth_data = (
            hashlib.sha256(rp_id.encode("utf-8")).digest()
            + bytes([0x05])  # UP | UV
            + self._counter.to_bytes(4, "big")
        )
        client_data = json.dumps(
            {
                "type": "webauthn.get",
                "challenge": bytes_to_base64url(challenge),
                "origin": origin,
            },
            separators=(",", ":"),
        ).encode("utf-8")
        signature = self._key.sign(
            auth_data + hashlib.sha256(client_data).digest(),
            ec.ECDSA(hashes.SHA256()),
        )
        credential_id = bytes_to_base64url(self.credential_id)
        return {
            "id": credential_id,
            "rawId": credential_id,
            "type": "public-key",
            "clientExtensionResults": {},
            "response": {
                "clientDataJSON": bytes_to_base64url(client_data),
                "authenticatorData": bytes_to_base64url(auth_data),
                "signature": bytes_to_base64url(signature),
                "userHandle": None,
            },
        }


# ---------------------------------------------------------------------------
# Fixtures and helpers
# ---------------------------------------------------------------------------


@pytest.fixture()
def db_session():
    """In-memory SQLite carrying the users/audit/approval tables."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    # MySQL-only column types are temporarily retyped for SQLite
    # (SQLite only autoincrements INTEGER PRIMARY KEY); production
    # MySQL is unaffected.
    swapped = []
    for table in (
        User.__table__,
        AuditLog.__table__,
        ApprovalTicket.__table__,
        WebauthnCredential.__table__,
    ):
        # BigInteger primary keys do not autoincrement on SQLite.
        column = table.c["id"]
        swapped.append((column, column.type))
        column.type = Integer()
    for name in ("avatar_url", "background_url"):
        column = User.__table__.c[name]
        swapped.append((column, column.type))
        column.type = Text()
    for table in (
        User.__table__,
        AuditLog.__table__,
        ApprovalTicket.__table__,
        WebauthnCredential.__table__,
    ):
        table.create(engine)
    for column, original in swapped:
        column.type = original

    factory = sessionmaker(bind=engine)
    session = factory()
    session.add(User(email="alice@porten.test", porten_id="111111", nickname="alice"))
    session.add(User(email="bob@porten.test", porten_id="222222", nickname="bob"))
    session.commit()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture()
def carrier():
    return Fido2KeyCarrier(
        rp_id=RP_ID, rp_name="Porten Admin", origin=ORIGIN, challenge_ttl_seconds=120
    )


@pytest.fixture()
def service(carrier):
    return ApprovalService(carrier=carrier)


def _enroll(db_session, carrier, authenticator, user_id: int) -> str:
    """Enroll an authenticator and return its stored credential id."""
    options = carrier.begin_registration(db_session, user_id)
    challenge = base64url_to_bytes(options["challenge"])
    credential = authenticator.register(challenge)
    return carrier.complete_registration(db_session, user_id, credential)


def _press(ticket: ApprovalTicket, authenticator: _VirtualAuthenticator) -> dict:
    """Sign the ticket nonce: the challenge every ceremony is bound to."""
    return authenticator.press(ticket.challenge_nonce.encode("utf-8"))


def _audit_actions(db_session, ticket_id: int) -> list:
    """Audit actions recorded for one ticket, oldest first."""
    entries = (
        db_session.query(AuditLog)
        .filter(AuditLog.action.like("approval_%"))
        .order_by(AuditLog.id)
        .all()
    )
    return [
        entry.action
        for entry in entries
        if (entry.meta or {}).get("ticket_id") == ticket_id
    ]


# ---------------------------------------------------------------------------
# Enrollment (real FIDO2 verification path)
# ---------------------------------------------------------------------------


class TestEnrollment:
    """Key enrollment through the real py_webauthn verification."""

    def test_enrollment_roundtrip(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        credential_id = _enroll(db_session, carrier, authenticator, 1)
        stored = carrier.list_credentials(db_session, 1)
        assert len(stored) == 1
        assert bytes_to_base64url(stored[0].credential_id) == credential_id
        assert stored[0].public_key  # COSE public key persisted
        assert stored[0].attestation_format == "none"
        assert stored[0].revoked is False

    def test_second_key_for_same_user(self, db_session, carrier):
        _enroll(db_session, carrier, _VirtualAuthenticator(), 1)
        _enroll(db_session, carrier, _VirtualAuthenticator(), 1)
        assert len(carrier.list_credentials(db_session, 1)) == 2

    def test_duplicate_credential_rejected(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        _enroll(db_session, carrier, authenticator, 1)
        options = carrier.begin_registration(db_session, 2)
        challenge = base64url_to_bytes(options["challenge"])
        with pytest.raises(KeyCarrierError):
            carrier.complete_registration(
                db_session, 2, authenticator.register(challenge)
            )

    def test_stale_challenge_rejected(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        options = carrier.begin_registration(db_session, 1)
        challenge = base64url_to_bytes(options["challenge"])
        # A second ceremony invalidates the stored challenge: only the
        # latest one may be completed.
        carrier.begin_registration(db_session, 1)
        with pytest.raises(KeyCarrierError):
            carrier.complete_registration(
                db_session, 1, authenticator.register(challenge)
            )

    def test_unknown_user_rejected(self, db_session, carrier):
        with pytest.raises(KeyCarrierError):
            carrier.begin_registration(db_session, 999)


# ---------------------------------------------------------------------------
# Key press (real FIDO2 verification path)
# ---------------------------------------------------------------------------


class TestAssertion:
    """Key-press verification against the enrolled public key."""

    def test_explicit_challenge_roundtrip(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        _enroll(db_session, carrier, authenticator, 1)
        nonce = secrets.token_urlsafe(32)
        options = carrier.begin_assertion(db_session, 1, nonce.encode())
        credential = authenticator.press(base64url_to_bytes(options["challenge"]))
        assert (
            carrier.verify_assertion(db_session, 1, credential, nonce.encode())
            == bytes_to_base64url(authenticator.credential_id)
        )
        row = carrier.list_credentials(db_session, 1)[0]
        assert row.sign_count > 0
        assert row.last_used_at is not None

    def test_standalone_challenge_roundtrip(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        _enroll(db_session, carrier, authenticator, 1)
        options = carrier.begin_assertion(db_session, 1)
        credential = authenticator.press(base64url_to_bytes(options["challenge"]))
        # No explicit challenge: the stored one is consumed.
        assert carrier.verify_assertion(db_session, 1, credential) is not None

    def test_standalone_challenge_is_single_use(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        _enroll(db_session, carrier, authenticator, 1)
        options = carrier.begin_assertion(db_session, 1)
        challenge = base64url_to_bytes(options["challenge"])
        carrier.verify_assertion(db_session, 1, authenticator.press(challenge))
        with pytest.raises(KeyCarrierError):
            carrier.verify_assertion(db_session, 1, authenticator.press(challenge))

    def test_tampered_signature_rejected(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        _enroll(db_session, carrier, authenticator, 1)
        nonce = secrets.token_urlsafe(32)
        options = carrier.begin_assertion(db_session, 1, nonce.encode())
        credential = authenticator.press(base64url_to_bytes(options["challenge"]))
        raw = bytearray(base64url_to_bytes(credential["response"]["signature"]))
        raw[-1] ^= 0xFF
        credential["response"]["signature"] = bytes_to_base64url(bytes(raw))
        with pytest.raises(KeyCarrierError):
            carrier.verify_assertion(db_session, 1, credential, nonce.encode())

    def test_wrong_origin_rejected(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        _enroll(db_session, carrier, authenticator, 1)
        nonce = secrets.token_urlsafe(32)
        options = carrier.begin_assertion(db_session, 1, nonce.encode())
        credential = authenticator.press(
            base64url_to_bytes(options["challenge"]),
            origin="https://evil.example",
        )
        with pytest.raises(KeyCarrierError):
            carrier.verify_assertion(db_session, 1, credential, nonce.encode())

    def test_wrong_rp_id_rejected(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        _enroll(db_session, carrier, authenticator, 1)
        nonce = secrets.token_urlsafe(32)
        options = carrier.begin_assertion(db_session, 1, nonce.encode())
        credential = authenticator.press(
            base64url_to_bytes(options["challenge"]),
            rp_id="other.porten.test",
        )
        with pytest.raises(KeyCarrierError):
            carrier.verify_assertion(db_session, 1, credential, nonce.encode())

    def test_foreign_credential_rejected(self, db_session, carrier):
        alice_key = _VirtualAuthenticator()
        _enroll(db_session, carrier, alice_key, 1)
        _enroll(db_session, carrier, _VirtualAuthenticator(), 2)
        nonce = secrets.token_urlsafe(32)
        options = carrier.begin_assertion(db_session, 1, nonce.encode())
        credential = alice_key.press(base64url_to_bytes(options["challenge"]))
        # Bob may not press Alice's key.
        with pytest.raises(KeyCarrierError):
            carrier.verify_assertion(db_session, 2, credential, nonce.encode())

    def test_replayed_counter_rejected(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        _enroll(db_session, carrier, authenticator, 1)
        nonce = secrets.token_urlsafe(32)
        options = carrier.begin_assertion(db_session, 1, nonce.encode())
        challenge = base64url_to_bytes(options["challenge"])
        first = authenticator.press(challenge)
        carrier.verify_assertion(db_session, 1, first, nonce.encode())
        # Re-issue the exact same authenticator data: same counter value.
        second = authenticator.press(challenge)
        second["response"]["authenticatorData"] = first["response"][
            "authenticatorData"
        ]
        with pytest.raises(KeyCarrierError):
            carrier.verify_assertion(db_session, 1, second, nonce.encode())

    def test_revoked_credential_rejected(self, db_session, carrier):
        authenticator = _VirtualAuthenticator()
        credential_id = _enroll(db_session, carrier, authenticator, 1)
        assert carrier.revoke(db_session, credential_id) is True
        nonce = secrets.token_urlsafe(32)
        options = carrier.begin_assertion(db_session, 1, nonce.encode())
        credential = authenticator.press(base64url_to_bytes(options["challenge"]))
        with pytest.raises(KeyCarrierError):
            carrier.verify_assertion(db_session, 1, credential, nonce.encode())

    def test_revocation_of_unknown_id(self, db_session, carrier):
        assert carrier.revoke(db_session, "not-a-credential") is False


# ---------------------------------------------------------------------------
# Two-person approval state machine
# ---------------------------------------------------------------------------


class TestApprovalFlow:
    """The full two-key lifecycle with the real carrier and audit chain."""

    def _prepare(self, db_session, carrier):
        alice_key = _VirtualAuthenticator()
        bob_key = _VirtualAuthenticator()
        _enroll(db_session, carrier, alice_key, 1)
        _enroll(db_session, carrier, bob_key, 2)
        return alice_key, bob_key

    def test_full_two_key_lifecycle(self, db_session, service, carrier):
        alice_key, bob_key = self._prepare(db_session, carrier)
        payload = {"user_id": 42, "reason": "spam"}

        ticket = service.create(
            db_session,
            action="user_freeze",
            primary_user_id=1,
            target_type="user",
            target_id=42,
            payload=payload,
            ip="203.0.113.9",
        )
        assert ticket.status == "pending"
        # SQLite round-trips naive datetimes; they are UTC by construction.
        expires_at = ticket.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        assert expires_at > datetime.now(timezone.utc)

        # The reviewer cannot start the primary ceremony.
        with pytest.raises(ApprovalError):
            service.begin_primary(db_session, ticket.id, 2)

        service.begin_primary(db_session, ticket.id, 1)
        service.authorize_primary(
            db_session, ticket.id, 1, _press(ticket, alice_key), ip="203.0.113.9"
        )
        refreshed = service.get(db_session, ticket.id)
        assert refreshed.status == "pending"
        assert refreshed.primary_authorized_at is not None
        assert refreshed.primary_credential_id

        # The primary operator cannot review their own request.
        with pytest.raises(ApprovalError):
            service.begin_reviewer(db_session, ticket.id, 1)
        with pytest.raises(ApprovalError):
            service.authorize_reviewer(db_session, ticket.id, 1, _press(ticket, alice_key))

        service.begin_reviewer(db_session, ticket.id, 2)
        service.authorize_reviewer(db_session, ticket.id, 2, _press(ticket, bob_key))
        approved = service.get(db_session, ticket.id)
        assert approved.status == "approved"
        assert approved.reviewer_user_id == 2
        assert approved.reviewer_authorized_at is not None

        # Consumption binding: action, payload and executor are checked.
        with pytest.raises(ApprovalError):
            service.consume(
                db_session,
                ticket.id,
                action="user_unfreeze",
                payload=payload,
                actor_id=1,
            )
        with pytest.raises(ApprovalError):
            service.consume(
                db_session,
                ticket.id,
                action="user_freeze",
                payload={"user_id": 43, "reason": "spam"},
                actor_id=1,
            )
        with pytest.raises(ApprovalError):
            service.consume(
                db_session, ticket.id, action="user_freeze", payload=payload, actor_id=3
            )

        consumed = service.consume(
            db_session, ticket.id, action="user_freeze", payload=payload, actor_id=1
        )
        assert consumed.status == "consumed"
        assert consumed.consumed_at is not None

        # One-shot: a consumed ticket can never be spent again.
        with pytest.raises(ApprovalError):
            service.consume(
                db_session, ticket.id, action="user_freeze", payload=payload, actor_id=1
            )

        assert _audit_actions(db_session, ticket.id) == [
            "approval_ticket_created",
            "approval_primary_authorized",
            "approval_reviewer_authorized",
            "approval_ticket_consumed",
        ]

    def test_primary_authorization_requires_the_operator(
        self, db_session, service, carrier
    ):
        alice_key, _ = self._prepare(db_session, carrier)
        ticket = service.create(db_session, action="rule_rollback", primary_user_id=1)
        with pytest.raises(ApprovalError):
            service.authorize_primary(
                db_session, ticket.id, 2, _press(ticket, alice_key)
            )
        assert service.get(db_session, ticket.id).primary_authorized_at is None

    def test_reviewer_needs_the_primary_key_first(self, db_session, service, carrier):
        _, bob_key = self._prepare(db_session, carrier)
        ticket = service.create(db_session, action="user_freeze", primary_user_id=1)
        with pytest.raises(ApprovalError):
            service.begin_reviewer(db_session, ticket.id, 2)
        with pytest.raises(ApprovalError):
            service.authorize_reviewer(
                db_session, ticket.id, 2, _press(ticket, bob_key)
            )

    def test_double_reviewer_rejected(self, db_session, service, carrier):
        alice_key, bob_key = self._prepare(db_session, carrier)
        ticket = service.create(db_session, action="user_freeze", primary_user_id=1)
        service.authorize_primary(db_session, ticket.id, 1, _press(ticket, alice_key))
        service.authorize_reviewer(db_session, ticket.id, 2, _press(ticket, bob_key))
        with pytest.raises(ApprovalError):
            service.authorize_reviewer(db_session, ticket.id, 3, _press(ticket, bob_key))

    def test_reject_flow(self, db_session, service, carrier):
        alice_key, _ = self._prepare(db_session, carrier)
        ticket = service.create(db_session, action="user_freeze", primary_user_id=1)
        service.authorize_primary(db_session, ticket.id, 1, _press(ticket, alice_key))
        with pytest.raises(ApprovalError):
            service.reject(db_session, ticket.id, 2, "")
        rejected = service.reject(db_session, ticket.id, 2, "not enough evidence")
        assert rejected.status == "rejected"
        assert rejected.decision_note == "not enough evidence"
        # A rejected ticket can never be approved or consumed.
        with pytest.raises(ApprovalError):
            service.consume(
                db_session, ticket.id, action="user_freeze", payload=None, actor_id=1
            )

    def test_cancel_flow(self, db_session, service, carrier):
        alice_key, _ = self._prepare(db_session, carrier)
        ticket = service.create(db_session, action="user_freeze", primary_user_id=1)
        with pytest.raises(ApprovalError):
            service.cancel(db_session, ticket.id, 2)
        cancelled = service.cancel(db_session, ticket.id, 1)
        assert cancelled.status == "cancelled"
        with pytest.raises(ApprovalError):
            service.authorize_primary(
                db_session, ticket.id, 1, _press(ticket, alice_key)
            )

    def test_expiry_before_review(self, db_session, service, carrier):
        alice_key, _ = self._prepare(db_session, carrier)
        ticket = service.create(db_session, action="user_freeze", primary_user_id=1)
        ticket.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        with pytest.raises(ApprovalError):
            service.begin_primary(db_session, ticket.id, 1)
        assert service.get(db_session, ticket.id).status == "expired"
        with pytest.raises(ApprovalError):
            service.authorize_primary(
                db_session, ticket.id, 1, _press(ticket, alice_key)
            )

    def test_expiry_before_consume(self, db_session, service, carrier):
        alice_key, bob_key = self._prepare(db_session, carrier)
        ticket = service.create(db_session, action="user_freeze", primary_user_id=1)
        service.authorize_primary(db_session, ticket.id, 1, _press(ticket, alice_key))
        service.authorize_reviewer(db_session, ticket.id, 2, _press(ticket, bob_key))
        ticket.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        with pytest.raises(ApprovalError):
            service.consume(
                db_session, ticket.id, action="user_freeze", payload=None, actor_id=1
            )
        assert service.get(db_session, ticket.id).status == "expired"

    def test_audit_fail_closes_the_transition(
        self, db_session, service, carrier, monkeypatch
    ):
        alice_key, _ = self._prepare(db_session, carrier)
        ticket = service.create(db_session, action="user_freeze", primary_user_id=1)

        def _boom(*args, **kwargs):
            raise AuditChainError("chain lock unavailable")

        monkeypatch.setattr(service._audit_service, "append", _boom)
        with pytest.raises(ApprovalError):
            service.authorize_primary(
                db_session, ticket.id, 1, _press(ticket, alice_key)
            )
        # The transition was rolled back: the ticket is still pending
        # and no key press is recorded.
        refreshed = service.get(db_session, ticket.id)
        assert refreshed.status == "pending"
        assert refreshed.primary_authorized_at is None

    def test_list_tickets_filters_by_status(self, db_session, service, carrier):
        self._prepare(db_session, carrier)
        first = service.create(db_session, action="user_freeze", primary_user_id=1)
        second = service.create(db_session, action="user_freeze", primary_user_id=1)
        service.cancel(db_session, first.id, 1)
        pending = service.list_tickets(db_session, status="pending")
        assert [t.id for t in pending] == [second.id]
        cancelled = service.list_tickets(db_session, status="cancelled")
        assert [t.id for t in cancelled] == [first.id]
        assert len(service.list_tickets(db_session)) == 2


# ---------------------------------------------------------------------------
# Expiry sweep
# ---------------------------------------------------------------------------


class TestExpirySweep:
    """Overdue tickets are expired with an audit trail."""

    def test_expire_overdue(self, db_session, service):
        old = service.create(db_session, action="user_freeze", primary_user_id=1)
        old.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        fresh = service.create(db_session, action="user_freeze", primary_user_id=1)
        assert service.expire_overdue(db_session) == 1
        assert service.get(db_session, old.id).status == "expired"
        assert service.get(db_session, fresh.id).status == "pending"
        # The sweep itself left evidence.
        sweeps = [
            entry
            for entry in db_session.query(AuditLog).all()
            if entry.action == "approval_expired"
        ]
        assert len(sweeps) == 1
        assert sweeps[0].meta["ticket_id"] == old.id

    def test_sweep_loop_survives_failures(self, db_session, monkeypatch):
        calls = []

        class _Stub:
            def expire_overdue(self, db):
                calls.append(1)
                if len(calls) == 1:
                    raise RuntimeError("boom")
                return 1

        # The task imports SessionLocal from app.database on every round.
        monkeypatch.setattr(
            "app.database.SessionLocal", lambda: db_session
        )

        async def _run():
            task = asyncio.create_task(
                approval_expiry_task(_Stub(), interval_seconds=0.01)
            )
            await asyncio.sleep(0.08)
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass

        asyncio.run(_run())
        assert len(calls) >= 2


def test_carrier_satisfies_protocol():
    """The FIDO2 implementation is a valid KeyCarrier."""
    assert isinstance(Fido2KeyCarrier(), KeyCarrier)

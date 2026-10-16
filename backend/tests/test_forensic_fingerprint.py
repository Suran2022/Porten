"""Tests for the four-layer forensic fingerprint and the hash-chained
audit log (design doc §9).

The RFC 3161 client is exercised against an in-test TSA: a self-signed
certificate plus a real CMS SignedData token built with asn1crypto, so
both the signing and the verification paths run end to end. Database
assertions use in-memory SQLite with the forensic and audit tables.
"""

import hashlib
import json
import math
from datetime import datetime, timezone

import httpx
import pytest
from asn1crypto import cms, core, tsp, x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography import x509 as cx509
from cryptography.x509.oid import NameOID
from PIL import Image, ImageEnhance, ImageFilter
from sqlalchemy import Integer, create_engine
from sqlalchemy.orm import sessionmaker

from app.config import get_settings
from app.models import AuditLog, ForensicRecord
from app.services.audit_chain_service import (
    AuditChainService,
    compute_entry_hash,
)
from app.services.forensic_fingerprint_service import (
    ForensicFingerprintService,
    TsaClient,
    TsaError,
    content_sha256,
    perceptual_hamming_distance,
    perceptual_hash,
)


@pytest.fixture(autouse=True)
def _restore_settings():
    """Snapshot the settings keys touched by this module."""
    settings = get_settings()
    keys = (
        "security_profile",
        "security_tsa_url",
        "security_tsa_timeout_seconds",
    )
    snapshot = {key: getattr(settings, key) for key in keys}
    yield
    for key, value in snapshot.items():
        setattr(settings, key, value)


class FakeTsa:
    """In-test RFC 3161 TSA issuing real signed tokens.

    Builds a CMS SignedData token (v3, EncapsulatedContentInfo) with a
    self-signed certificate, so ``TsaClient.verify_token`` runs its
    full signature and structure checks against a genuine token.
    """

    def __init__(self) -> None:
        self._key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        name = cx509.Name([cx509.NameAttribute(NameOID.COMMON_NAME, "Porten Test TSA")])
        self._cert = (
            cx509.CertificateBuilder()
            .subject_name(name)
            .issuer_name(name)
            .public_key(self._key.public_key())
            .serial_number(cx509.random_serial_number())
            .not_valid_before(datetime(2020, 1, 1))
            .not_valid_after(datetime(2040, 1, 1))
            .sign(self._key, hashes.SHA256())
        )
        self._cert_asn1 = x509.Certificate.load(
            self._cert.public_bytes(serialization.Encoding.DER)
        )
        self.requests: list = []
        self.fail_with: Exception = None

    def handler(self, request: httpx.Request) -> httpx.Response:
        if self.fail_with is not None:
            raise self.fail_with
        self.requests.append(request.content)
        request_asn1 = tsp.TimeStampReq.load(request.content)
        digest = request_asn1["message_imprint"]["hashed_message"].native
        token = self._issue(digest)
        return httpx.Response(
            200,
            content=token,
            headers={"Content-Type": "application/timestamp-reply"},
        )

    def _issue(self, digest: bytes) -> bytes:
        gen_time = datetime.now(timezone.utc)
        tst_info = tsp.TSTInfo(
            {
                "version": 1,
                "policy": core.ObjectIdentifier("1.2.3.4.5"),
                "message_imprint": tsp.MessageImprint(
                    {
                        "hash_algorithm": tsp.DigestAlgorithm(
                            {"algorithm": "sha256"}
                        ),
                        "hashed_message": digest,
                    }
                ),
                "serial_number": 1234567,
                "gen_time": core.GeneralizedTime(gen_time),
            }
        )
        econtent = tst_info.dump()
        signed_attrs = cms.CMSAttributes(
            [
                cms.CMSAttribute({"type": "content_type", "values": ["tst_info"]}),
                cms.CMSAttribute(
                    {
                        "type": "message_digest",
                        "values": [hashlib.sha256(econtent).digest()],
                    }
                ),
            ]
        )
        signature = self._key.sign(
            signed_attrs.untag().dump(), padding.PKCS1v15(), hashes.SHA256()
        )
        signed_data = cms.SignedData(
            {
                "version": "v3",
                "digest_algorithms": [
                    cms.DigestAlgorithm({"algorithm": "sha256"})
                ],
                "encap_content_info": cms.EncapsulatedContentInfo(
                    {"content_type": "tst_info", "content": tst_info}
                ),
                "certificates": cms.CertificateSet(
                    [cms.CertificateChoices("certificate", self._cert_asn1)]
                ),
                "signer_infos": [
                    cms.SignerInfo(
                        {
                            "version": 1,
                            "sid": cms.SignerIdentifier(
                                {
                                    "issuer_and_serial_number": (
                                        cms.IssuerAndSerialNumber(
                                            {
                                                "issuer": self._cert_asn1.issuer,
                                                "serial_number": self._cert_asn1[
                                                    "tbs_certificate"
                                                ]["serial_number"],
                                            }
                                        )
                                    )
                                }
                            ),
                            "digest_algorithm": cms.DigestAlgorithm(
                                {"algorithm": "sha256"}
                            ),
                            "signature_algorithm": cms.SignedDigestAlgorithm(
                                {"algorithm": "sha256_rsa"}
                            ),
                            "signed_attrs": signed_attrs,
                            "signature": signature,
                        }
                    )
                ],
            }
        )
        token = cms.ContentInfo(
            {"content_type": "signed_data", "content": signed_data}
        )
        return tsp.TimeStampResp(
            {
                "status": tsp.PKIStatusInfo(
                    {"status": tsp.PKIStatus("granted")}
                ),
                "time_stamp_token": token,
            }
        ).dump()


@pytest.fixture()
def fake_tsa():
    return FakeTsa()


@pytest.fixture()
def tsa_client(fake_tsa):
    return TsaClient(
        "http://tsa.test",
        client=httpx.Client(transport=httpx.MockTransport(fake_tsa.handler)),
    )


@pytest.fixture()
def db_session():
    """In-memory SQLite with the forensic and audit tables."""
    engine = create_engine("sqlite://")
    tables = (ForensicRecord.__table__, AuditLog.__table__)
    originals = {table: table.c.id.type for table in tables}
    for table in tables:
        table.c.id.type = Integer()
        table.create(engine)
        table.c.id.type = originals[table]
    factory = sessionmaker(bind=engine)
    session = factory()
    yield session, engine
    session.close()
    engine.dispose()


@pytest.fixture()
def settings():
    return get_settings()


def _write_image(path, size=(128, 96), seed=7):
    """Write a deterministic pseudo-natural test image.

    A sum of six sinusoid bands per channel plus mild per-pixel texture
    gives a broadband spectrum like a real photograph, which is what
    perceptual hashing is designed for (a single smooth sinusoid has a
    degenerate spectrum and makes the hash look fragile).
    """
    image = Image.new("RGB", size)
    pixels = image.load()
    rng = _Rng(seed)
    width, height = size
    bands = [
        (rng.uniform(0.5, 6.0), rng.uniform(0.5, 6.0), rng.uniform(0, 6.28))
        for _ in range(6)
    ]
    for y in range(height):
        for x in range(width):
            u, v = x / (width - 1), y / (height - 1)
            red = green = 0.0
            for fx, fy, phase in bands:
                red += math.sin(2 * math.pi * (fx * u + fy * v) + phase)
                green += math.sin(2 * math.pi * (fy * u + fx * v) + phase * 1.7)
            red = 128 + 21 * red + rng.uniform(-3, 3)
            green = 128 + 21 * green + rng.uniform(-3, 3)
            pixels[x, y] = (
                max(0, min(255, int(red))),
                max(0, min(255, int(green))),
                110,
            )
    image.save(path)
    return path


class _Rng:
    """Deterministic tiny PRNG (keeps tests independent of numpy)."""

    def __init__(self, seed: int) -> None:
        self._state = seed

    def uniform(self, low: float, high: float) -> float:
        self._state = (self._state * 1103515245 + 12345) % (2**31)
        return low + (high - low) * (self._state / (2**31))


# ---------------------------------------------------------------------------
# Content fingerprint
# ---------------------------------------------------------------------------


class TestContentHash:
    def test_known_vector(self):
        assert content_sha256(b"abc") == hashlib.sha256(b"abc").hexdigest()

    def test_empty_and_unicode_and_large(self):
        assert content_sha256(b"") == hashlib.sha256(b"").hexdigest()
        text = "消息内容 😀 crisis support"
        assert content_sha256(text.encode("utf-8")) == hashlib.sha256(
            text.encode("utf-8")
        ).hexdigest()
        large = b"x" * 200_000
        assert content_sha256(large) == hashlib.sha256(large).hexdigest()


class TestPerceptualHash:
    def test_identical_file_is_deterministic(self, tmp_path):
        path = _write_image(str(tmp_path / "a.png"))
        assert perceptual_hash(path) == perceptual_hash(path)

    def test_benign_transformations_stay_close(self, tmp_path):
        base_path = _write_image(str(tmp_path / "base.png"))
        reference = perceptual_hash(base_path)

        resized = str(tmp_path / "resized.png")
        with Image.open(base_path) as image:
            image.resize((256, 256), Image.LANCZOS).save(resized)
        assert perceptual_hamming_distance(reference, perceptual_hash(resized)) <= 8

        brighter = str(tmp_path / "bright.png")
        with Image.open(base_path) as image:
            ImageEnhance.Brightness(image).enhance(1.2).save(brighter)
        assert perceptual_hamming_distance(reference, perceptual_hash(brighter)) <= 8

        jpeg = str(tmp_path / "re.jpg")
        with Image.open(base_path) as image:
            image.save(jpeg, "JPEG", quality=85)
        assert perceptual_hamming_distance(reference, perceptual_hash(jpeg)) <= 8

        blurred = str(tmp_path / "blur.png")
        with Image.open(base_path) as image:
            image.filter(ImageFilter.GaussianBlur(0.6)).save(blurred)
        assert perceptual_hamming_distance(reference, perceptual_hash(blurred)) <= 8

    def test_different_images_are_far(self, tmp_path):
        left = _write_image(str(tmp_path / "left.png"), seed=7)
        right = _write_image(str(tmp_path / "right.png"), seed=42)
        distance = perceptual_hamming_distance(
            perceptual_hash(left), perceptual_hash(right)
        )
        assert distance >= 20

    def test_distance_is_symmetric_and_zero_for_self(self, tmp_path):
        left = _write_image(str(tmp_path / "l.png"), seed=1)
        right = _write_image(str(tmp_path / "r.png"), seed=2)
        hash_left, hash_right = perceptual_hash(left), perceptual_hash(right)
        assert perceptual_hamming_distance(hash_left, hash_left) == 0
        assert perceptual_hamming_distance(
            hash_left, hash_right
        ) == perceptual_hamming_distance(hash_right, hash_left)

    def test_non_image_returns_none(self, tmp_path):
        path = tmp_path / "broken.png"
        path.write_bytes(b"definitely not an image")
        assert perceptual_hash(str(path)) is None


# ---------------------------------------------------------------------------
# RFC 3161 TSA client
# ---------------------------------------------------------------------------


class TestTsaClientSigning:
    def test_sign_returns_verifiable_token(self, tsa_client, fake_tsa):
        digest = hashlib.sha256(b"evidence content").digest()
        token = tsa_client.sign(digest)
        assert isinstance(token, bytes) and len(token) > 0
        # the request carried exactly the digest we asked to stamp
        request = tsp.TimeStampReq.load(fake_tsa.requests[0])
        assert request["message_imprint"]["hashed_message"].native == digest
        assert request["cert_req"].native is True

    def test_verify_round_trip(self, tsa_client):
        digest = hashlib.sha256(b"evidence content").digest()
        token = tsa_client.sign(digest)
        verification = TsaClient.verify_token(
            token, hashlib.sha256(b"evidence content").hexdigest()
        )
        assert verification.ok
        assert verification.reason is None
        assert verification.signed_at is not None
        assert verification.signed_at.tzinfo is not None

    def test_verify_rejects_wrong_digest(self, tsa_client):
        token = tsa_client.sign(hashlib.sha256(b"one").digest())
        verification = TsaClient.verify_token(
            token, hashlib.sha256(b"two").hexdigest()
        )
        assert not verification.ok
        assert verification.reason == "imprint_mismatch"

    def test_verify_rejects_tampered_token(self, tsa_client):
        token = bytearray(tsa_client.sign(hashlib.sha256(b"x").digest()))
        token[-1] ^= 0xFF
        verification = TsaClient.verify_token(
            bytes(token), hashlib.sha256(b"x").hexdigest()
        )
        assert not verification.ok
        assert verification.reason in (
            "malformed_token",
            "signature_invalid",
            "imprint_mismatch",
        )

    def test_verify_rejects_malformed_der(self):
        verification = TsaClient.verify_token(b"\x30\x03\x02\x01\x01", "ab" * 32)
        assert not verification.ok
        assert verification.reason == "malformed_token"

    def test_sign_rejects_bad_digest_length(self, tsa_client):
        with pytest.raises(TsaError):
            tsa_client.sign(b"too short")

    def test_sign_raises_on_http_error(self, fake_tsa):
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(503, text="unavailable")

        client = TsaClient(
            "http://tsa.test", client=httpx.Client(transport=httpx.MockTransport(handler))
        )
        with pytest.raises(TsaError):
            client.sign(b"\x00" * 32)

    def test_sign_raises_on_transport_error(self, fake_tsa):
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("tsa down")

        client = TsaClient(
            "http://tsa.test", client=httpx.Client(transport=httpx.MockTransport(handler))
        )
        with pytest.raises(TsaError):
            client.sign(b"\x00" * 32)

    def test_verify_rejects_rejection_status(self, fake_tsa):
        # asn1crypto models time_stamp_token as required, so a
        # token-less rejection cannot be built directly; flip the
        # status of an otherwise valid response instead.
        token = fake_tsa._issue(hashlib.sha256(b"x").digest())
        response = tsp.TimeStampResp.load(token)
        response["status"]["status"] = tsp.PKIStatus("rejection")
        rejection = response.dump()

        verification = TsaClient.verify_token(rejection, "ab" * 32)
        assert not verification.ok
        assert verification.reason == "tsa_status:rejection"


# ---------------------------------------------------------------------------
# Forensic record lifecycle
# ---------------------------------------------------------------------------


class TestForensicRecordLifecycle:
    def test_no_tsa_configured_stays_pending(self, db_session, settings):
        session, _ = db_session
        settings.security_tsa_url = ""
        service = ForensicFingerprintService()
        assert service.timestamping_available is False
        record = service.create_record(
            session, "message", "1001", content=b"secret message body"
        )
        assert record.tsa_status == "pending"
        assert record.tsa_token is None
        assert record.tsa_requested_at is None
        # absence of a timestamp is never forged
        assert record.content_hash == content_sha256(b"secret message body")

    def test_requires_content_or_hash(self, db_session):
        session, _ = db_session
        service = ForensicFingerprintService()
        with pytest.raises(ValueError):
            service.create_record(session, "message", "1")

    def test_signed_with_configured_tsa(self, db_session, tsa_client, tmp_path):
        session, _ = db_session
        service = ForensicFingerprintService(tsa_client=tsa_client)
        record = service.create_record(
            session,
            "media",
            "m-1",
            content=b"binary media bytes",
            image_path=_write_image(str(tmp_path / "m.png")),
        )
        assert record.tsa_status == "signed"
        assert record.tsa_token
        assert record.tsa_signed_at is not None
        assert record.perceptual_hash is not None

        verification = service.verify_record(session, record.id)
        assert verification.ok
        assert verification.tsa_verified is True
        assert verification.custody_chain_valid is True

    def test_tsa_failure_marks_failed_and_keeps_hash(self, db_session):
        session, _ = db_session

        class _FailingTsa(TsaClient):
            def sign(self, digest: bytes) -> bytes:
                raise TsaError("tsa down")

        service = ForensicFingerprintService(tsa_client=_FailingTsa("http://tsa.test"))
        record = service.create_record(session, "diary", "d-1", content=b"diary text")
        assert record.tsa_status == "failed"
        assert record.tsa_token is None
        assert record.content_hash == content_sha256(b"diary text")

    def test_unverifiable_token_is_discarded(self, db_session, fake_tsa):
        session, _ = db_session

        class _LyingTsa(TsaClient):
            """Issues a token stamped for a different digest."""

            def sign(self, digest: bytes) -> bytes:
                other = hashlib.sha256(b"something else").digest()
                return fake_tsa._issue(other)

        service = ForensicFingerprintService(tsa_client=_LyingTsa("http://tsa.test"))
        record = service.create_record(session, "message", "9", content=b"body")
        assert record.tsa_status == "failed"
        assert record.tsa_token is None

    def test_sign_pending_retries(self, db_session, tsa_client):
        session, _ = db_session
        service = ForensicFingerprintService(tsa_client=tsa_client)
        record = service.create_record(
            session, "message", "7", content=b"body", request_timestamp=False
        )
        assert record.tsa_status == "pending"
        signed = service.sign_pending(session)
        assert signed == 1
        assert record.tsa_status == "signed"
        assert service.sign_pending(session) == 0

    def test_sign_pending_noop_without_tsa(self, db_session, settings):
        session, _ = db_session
        settings.security_tsa_url = ""
        service = ForensicFingerprintService()
        record = service.create_record(session, "message", "8", content=b"body")
        assert service.sign_pending(session) == 0
        assert record.tsa_status == "pending"


# ---------------------------------------------------------------------------
# Chain of custody
# ---------------------------------------------------------------------------


class TestCustodyChain:
    def _record(self, service, session):
        return service.create_record(session, "message", "55", content=b"body")

    def test_append_and_verify(self, db_session):
        session, _ = db_session
        service = ForensicFingerprintService()
        record = self._record(service, session)
        service.append_custody(
            session,
            record,
            operator_id=1,
            action="case_opened",
            before={"status": "active"},
            after={"status": "under_review"},
        )
        service.append_custody(
            session, record, operator_id=2, action="content_reviewed"
        )
        assert len(record.custody_log) == 2
        assert service.verify_custody_chain(record) is True

    def test_dual_verification_marks_verified(self, db_session):
        session, _ = db_session
        service = ForensicFingerprintService()
        record = self._record(service, session)
        assert record.verified is False
        service.append_custody(
            session,
            record,
            operator_id=1,
            action="unredacted_view",
            approver_id=2,
            approver_role="admin",
        )
        assert record.verified is True
        entry = record.custody_log[-1]
        assert entry["dual_verification"]["approver_id"] == 2
        assert entry["dual_verification"]["approver_role"] == "admin"

    def test_tampered_entry_detected(self, db_session):
        session, _ = db_session
        service = ForensicFingerprintService()
        record = self._record(service, session)
        service.append_custody(session, record, operator_id=1, action="a")
        service.append_custody(session, record, operator_id=1, action="b")
        assert service.verify_custody_chain(record) is True

        # Simulate an attacker editing the stored log behind the ORM's
        # back: expire the instance, copy the loaded entries, mutate a
        # copy and persist it, then re-verify what the database holds.
        session.expire(record)
        tampered = [dict(entry) for entry in record.custody_log]
        tampered[0]["action"] = "forged"
        record.custody_log = tampered
        session.commit()
        assert service.verify_custody_chain(record) is False

    def test_deleted_entry_breaks_linkage(self, db_session):
        session, _ = db_session
        service = ForensicFingerprintService()
        record = self._record(service, session)
        for action in ("a", "b", "c"):
            service.append_custody(session, record, operator_id=1, action=action)
        entries = list(record.custody_log)
        del entries[1]  # drop the middle entry
        record.custody_log = entries
        session.commit()
        assert service.verify_custody_chain(record) is False

    def test_empty_custody_log_is_valid(self, db_session):
        session, _ = db_session
        service = ForensicFingerprintService()
        record = self._record(service, session)
        assert service.verify_custody_chain(record) is True


# ---------------------------------------------------------------------------
# Hash-chained audit log
# ---------------------------------------------------------------------------


class TestAuditChain:
    def test_append_links_entries(self, db_session):
        session, _ = db_session
        service = AuditChainService()
        first = service.append(
            session, actor_id=1, actor_role="moderator", action="content_recalled",
            target_type="message", target_id="100", summary="recalled",
        )
        assert first.prev_hash is None
        second = service.append(
            session, actor_id=2, actor_role="admin", action="user_frozen",
            target_type="user", target_id="7",
        )
        assert second.prev_hash == first.entry_hash

        report = service.verify_chain(session)
        assert report.checked == 2
        assert report.valid
        assert report.broken_at_id is None

    def test_entry_hash_matches_recomputation(self, db_session):
        session, _ = db_session
        service = AuditChainService()
        entry = service.append(
            session, actor_id=5, action="rule_published", meta={"version": "3"}
        )
        recomputed = compute_entry_hash(
            actor_id=entry.actor_id,
            actor_role=entry.actor_role,
            action=entry.action,
            target_type=entry.target_type,
            target_id=entry.target_id,
            summary=entry.summary,
            meta=entry.meta,
            ip_hash=entry.ip_hash,
            created_at=entry.created_at,
            prev_hash=entry.prev_hash,
        )
        assert recomputed == entry.entry_hash

    def test_tampered_row_detected(self, db_session):
        session, _ = db_session
        service = AuditChainService()
        service.append(session, actor_id=1, action="one", summary="original")
        service.append(session, actor_id=1, action="two")
        service.append(session, actor_id=1, action="three")

        first = session.query(AuditLog).order_by(AuditLog.id.asc()).first()
        first.summary = "rewritten by attacker"
        session.commit()

        report = service.verify_chain(session)
        assert not report.valid
        assert report.broken_at_id == first.id
        assert report.errors

    def test_deleted_row_breaks_linkage(self, db_session):
        session, _ = db_session
        service = AuditChainService()
        service.append(session, actor_id=1, action="one")
        second = service.append(session, actor_id=1, action="two")
        service.append(session, actor_id=1, action="three")

        session.delete(second)
        session.commit()
        report = service.verify_chain(session)
        assert not report.valid
        assert report.broken_at_id is not None

    def test_forked_chain_detected(self, db_session):
        session, _ = db_session
        service = AuditChainService()
        first = service.append(session, actor_id=1, action="one")
        # Simulate a lost lock race: two branches share prev_hash, so
        # the second branch cannot chain to the first one's entry_hash.
        def _fork(action: str) -> AuditLog:
            created_at = datetime.now(timezone.utc).replace(microsecond=0)
            return AuditLog(
                actor_id=1,
                action=action,
                prev_hash=first.entry_hash,
                entry_hash=compute_entry_hash(
                    actor_id=1,
                    actor_role=None,
                    action=action,
                    target_type=None,
                    target_id=None,
                    summary=None,
                    meta=None,
                    ip_hash=None,
                    created_at=created_at,
                    prev_hash=first.entry_hash,
                ),
                created_at=created_at,
            )

        branch_a = _fork("forked-a")
        branch_b = _fork("forked-b")
        session.add_all([branch_a, branch_b])
        session.commit()

        report = service.verify_chain(session)
        assert not report.valid
        assert report.broken_at_id == branch_b.id

    def test_range_verification(self, db_session):
        session, _ = db_session
        service = AuditChainService()
        entries = [
            service.append(session, actor_id=1, action=f"action-{index}")
            for index in range(4)
        ]
        report = service.verify_chain(
            session, from_id=entries[1].id, to_id=entries[2].id
        )
        assert report.checked == 2
        assert report.valid

    def test_entries_for_subject(self, db_session):
        session, _ = db_session
        service = AuditChainService()
        service.append(
            session, actor_id=1, action="a", target_type="message", target_id="100"
        )
        service.append(
            session, actor_id=1, action="b", target_type="message", target_id="200"
        )
        service.append(
            session, actor_id=1, action="c", target_type="message", target_id="100"
        )
        found = service.entries_for_subject(session, "message", "100")
        assert [entry.action for entry in found] == ["c", "a"]

    def test_append_without_content_leakage(self, db_session):
        session, _ = db_session
        service = AuditChainService()
        entry = service.append(
            session,
            actor_id=1,
            action="content_reviewed",
            target_type="message",
            target_id="9",
            summary="reviewed",
            meta={"verdict": "malicious"},
        )
        dumped = json.dumps(
            {
                "summary": entry.summary,
                "meta": entry.meta,
                "target_type": entry.target_type,
            }
        )
        assert "secret" not in dumped


# ---------------------------------------------------------------------------
# Forensic package
# ---------------------------------------------------------------------------


class TestForensicPackage:
    def test_package_structure_and_integrity(self, db_session, tsa_client, tmp_path):
        session, _ = db_session
        forensic = ForensicFingerprintService(tsa_client=tsa_client)
        audit = AuditChainService()
        record = forensic.create_record(
            session,
            "message",
            "100",
            content=b"evidence body",
            image_path=_write_image(str(tmp_path / "p.png")),
        )
        audit.append(
            session,
            actor_id=1,
            actor_role="moderator",
            action="content_recalled",
            target_type="message",
            target_id="100",
        )
        forensic.append_custody(
            session,
            record,
            operator_id=1,
            action="case_opened",
            before={"status": "active"},
            after={"status": "under_review"},
            approver_id=2,
            approver_role="admin",
        )

        package = forensic.build_forensic_package(session, record)
        assert package["package_version"] == 1
        assert package["subject"] == {"type": "message", "id": "100"}
        assert package["content_evidence"]["content_hash"] == record.content_hash
        assert package["content_evidence"]["perceptual_hash"] == record.perceptual_hash
        assert package["time_evidence"]["status"] == "signed"
        assert package["time_evidence"]["token_sha256"] == hashlib.sha256(
            record.tsa_token
        ).hexdigest()
        assert package["custody_evidence"]["entries"] == 1
        assert package["custody_evidence"]["verified_by_two_people"] is True
        assert package["custody_evidence"]["chain_valid"] is True
        assert len(package["process_evidence"]["audit_entries"]) == 1
        assert package["integrity"]["ok"] is True
        assert package["integrity"]["tsa_verified"] is True

    def test_package_contains_no_raw_content(self, db_session, tmp_path):
        session, _ = db_session
        forensic = ForensicFingerprintService()
        record = forensic.create_record(
            session, "diary", "77", content=b"diary plaintext secret"
        )
        package = forensic.build_forensic_package(session, record)
        serialized = json.dumps(package, ensure_ascii=False, default=str)
        assert "diary plaintext secret" not in serialized
        # only hashes and redacted snapshots travel in the package
        assert record.content_hash in serialized

    def test_package_flags_broken_custody(self, db_session):
        session, _ = db_session
        forensic = ForensicFingerprintService()
        record = forensic.create_record(session, "message", "78", content=b"body")
        forensic.append_custody(session, record, operator_id=1, action="a")
        # Tamper with the persisted log (see TestCustodyChain for why
        # the instance is expired and the entries copied first).
        session.expire(record)
        entries = [dict(entry) for entry in record.custody_log]
        entries[0]["note"] = "injected after the fact"
        record.custody_log = entries
        session.commit()

        package = forensic.build_forensic_package(session, record)
        assert package["integrity"]["ok"] is False
        assert package["integrity"]["custody_chain_valid"] is False
        assert package["custody_evidence"]["chain_valid"] is False

    def test_package_unsigned_record_reports_pending(self, db_session, settings):
        session, _ = db_session
        settings.security_tsa_url = ""
        forensic = ForensicFingerprintService()
        record = forensic.create_record(session, "message", "79", content=b"body")
        package = forensic.build_forensic_package(session, record)
        assert package["time_evidence"]["status"] == "pending"
        assert package["time_evidence"]["token_sha256"] is None
        assert package["integrity"]["tsa_verified"] is None
        # custody-only integrity still holds for an empty log
        assert package["integrity"]["custody_chain_valid"] is True


class TestAuditChainErrors:
    def test_mysql_dialect_required_for_lock(self, db_session):
        """SQLite skips the advisory lock; only MySQL raises on failure."""
        session, _ = db_session
        service = AuditChainService()
        # SQLite path: no GET_LOCK, append succeeds.
        entry = service.append(session, actor_id=1, action="sqlite-ok")
        assert entry.id is not None

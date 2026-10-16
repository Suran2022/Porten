"""Four-layer digital forensics: content fingerprints, RFC 3161 trusted
timestamps and chain-of-custody (design doc §9).

Layer mapping:

1. **Content fingerprint** -- SHA-256 for every subject, plus a
   DCT-based perceptual hash for media (near-duplicate matching). Only
   hashes are persisted; raw content never enters the forensic store.
2. **Time fingerprint** -- RFC 3161 TSA tokens. When no TSA is
   configured the record stays ``pending``: the absence of a timestamp
   is never forged. TSA errors move the record to ``failed`` and leave
   the content hash intact.
3. **Chain fingerprint** -- tamper-evident linking lives in
   :class:`~app.services.audit_chain_service.AuditChainService` (audit
   entries) and in the per-entry hash chain inside each custody log.
4. **Chain of custody** -- append-only custody entries (operator, time,
   object hash, action, redacted before/after snapshots, dual-person
   verification) assembled into an exportable forensic package.

WORM storage (object-lock buckets) is infrastructure outside this
service; the application layer guarantees immutability through hashing
and append-only semantics. Multi-anchoring (consortium chain, public
chain) is recorded as a ``chain_anchor`` reference by the caller once
an external anchor exists.
"""

import hashlib
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import List, Optional

import httpx
import numpy as np
from asn1crypto import tsp
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.serialization import load_der_public_key
from PIL import Image
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import ForensicRecord
from app.services.audit_chain_service import AuditChainService, canonical_bytes

logger = logging.getLogger(__name__)

# Tolerated clock drift between the local host and the TSA when
# validating genTime and certificate validity windows.
_MAX_CLOCK_SKEW = timedelta(minutes=5)

# Subjects larger than this are refused before decoding (pixels).
_MAX_IMAGE_PIXELS = 50_000_000

# pHash geometry: 32x32 DCT, 8x8 low-frequency block -> 64 bits.
_PHASH_BLOCK_SIZE = 8
_PHASH_RESIZE = 32


class TsaError(RuntimeError):
    """Raised when the TSA cannot produce a usable timestamp."""


@dataclass(frozen=True)
class TsaVerification:
    """Outcome of verifying one RFC 3161 token."""

    ok: bool
    signed_at: Optional[datetime] = None
    reason: Optional[str] = None


@dataclass(frozen=True)
class ForensicVerification:
    """Outcome of verifying one forensic record end to end."""

    ok: bool
    tsa_verified: Optional[bool]
    custody_chain_valid: bool
    signed_at: Optional[datetime] = None
    reason: Optional[str] = None


def content_sha256(data: bytes) -> str:
    """Return the hex SHA-256 digest of raw content bytes."""
    return hashlib.sha256(data).hexdigest()


def perceptual_hash(image_path: str) -> Optional[str]:
    """Return the 64-bit DCT perceptual hash (hex) of an image.

    The hash is robust to resizing, recompression and small edits, so
    near-duplicate media can be matched without storing the image.
    Returns None when the file is not a decodable image.
    """
    try:
        with Image.open(image_path) as image:
            if image.width * image.height > _MAX_IMAGE_PIXELS:
                logger.warning(
                    "perceptual hash skipped: %s exceeds %d pixels",
                    image_path,
                    _MAX_IMAGE_PIXELS,
                )
                return None
            # draft() fast-paths JPEG downscaling at decode time.
            image.draft("L", (_PHASH_RESIZE * 2, _PHASH_RESIZE * 2))
            grayscale = image.convert("L").resize(
                (_PHASH_RESIZE, _PHASH_RESIZE), Image.LANCZOS
            )
            pixels = np.asarray(grayscale, dtype=np.float32)
    except Exception:
        logger.warning("perceptual hash failed for %s", image_path, exc_info=True)
        return None

    dct = _dct2(pixels)
    block = dct[:_PHASH_BLOCK_SIZE, :_PHASH_BLOCK_SIZE]
    # The threshold is the median of the 7x7 band with the DC row and
    # column removed, so the bits stay invariant to brightness shifts;
    # all 64 block positions are then thresholded against it.
    median = float(np.median(block[1:, 1:]))
    bits = (block > median).flatten()
    return f"{_bits_to_int(bits):016x}"


def perceptual_hamming_distance(left: str, right: str) -> int:
    """Return the bit distance between two 64-bit perceptual hashes."""
    return bin(int(left, 16) ^ int(right, 16)).count("1")


def _bits_to_int(bits: np.ndarray) -> int:
    value = 0
    for bit in bits:
        value = (value << 1) | int(bool(bit))
    return value


def _dct2(matrix: np.ndarray) -> np.ndarray:
    """Return the orthonormal 2D DCT-II of a square matrix."""
    size = matrix.shape[0]
    basis = _dct_basis(size)
    return basis @ matrix @ basis.T


def _dct_basis(size: int) -> np.ndarray:
    """Return the orthonormal DCT-II basis matrix for the given size."""
    k = np.arange(size).reshape(-1, 1)
    x = np.arange(size).reshape(1, -1)
    basis = np.cos(np.pi * (2 * x + 1) * k / (2 * size))
    basis[0] *= 1.0 / np.sqrt(2.0)
    return basis * np.sqrt(2.0 / size)


class TsaClient:
    """RFC 3161 timestamp client (POST application/timestamp-query).

    The TSA sees only the digest, never the content. Tokens are
    verified on arrival: a token that does not verify against the
    digest it was requested for is discarded rather than stored.
    """

    def __init__(
        self,
        base_url: str,
        timeout_seconds: float = 5.0,
        client: Optional[httpx.Client] = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._timeout = timeout_seconds
        self._client = client or httpx.Client(timeout=timeout_seconds)

    def sign(self, digest: bytes) -> bytes:
        """Return the DER TimeStampResp for a 32-byte SHA-256 digest."""
        if len(digest) != 32:
            raise TsaError("digest must be a 32-byte sha256 value")
        request = tsp.TimeStampReq(
            {
                "version": 1,
                "message_imprint": tsp.MessageImprint(
                    {
                        "hash_algorithm": tsp.DigestAlgorithm(
                            {"algorithm": "sha256"}
                        ),
                        "hashed_message": digest,
                    }
                ),
                "cert_req": True,
            }
        )
        try:
            response = self._client.post(
                self._base_url,
                content=request.dump(),
                headers={
                    "Content-Type": "application/timestamp-query",
                    "Accept": "application/timestamp-reply",
                },
            )
            response.raise_for_status()
        except Exception as exc:
            raise TsaError(f"tsa request failed: {exc}") from exc
        return response.content

    @staticmethod
    def verify_token(token_der: bytes, content_hash_hex: str) -> TsaVerification:
        """Verify a TimeStampResp against the digest it should stamp.

        A token is untrusted input: any unexpected structural error is
        reported as ``malformed_token`` instead of raised, so callers
        can always treat the result as data.
        """
        try:
            return TsaClient._verify_token(token_der, content_hash_hex)
        except Exception:
            return TsaVerification(ok=False, reason="malformed_token")

    @staticmethod
    def _verify_token(token_der: bytes, content_hash_hex: str) -> TsaVerification:
        """Run the ordered RFC 3161 verification checks.

        Structure, granted status, imprint match, messageDigest
        attribute consistency, TSA certificate signature over the
        signed attributes, certificate validity at genTime, and genTime
        not implausibly in the future.
        """
        response = tsp.TimeStampResp.load(token_der)

        status = response["status"]["status"].native
        if status != "granted":
            return TsaVerification(ok=False, reason=f"tsa_status:{status}")
        try:
            token = response["time_stamp_token"]
        except (KeyError, ValueError):
            return TsaVerification(ok=False, reason="token_missing")

        signed_data = token["content"]
        if len(signed_data["signer_infos"]) == 0:
            return TsaVerification(ok=False, reason="no_signer_info")
        signer_info = signed_data["signer_infos"][0]

        try:
            tst_info = signed_data["encap_content_info"]["content"].parsed
        except Exception:
            return TsaVerification(ok=False, reason="tst_info_unparseable")

        imprint = tst_info["message_imprint"]
        if imprint["hash_algorithm"]["algorithm"].native != "sha256":
            return TsaVerification(ok=False, reason="unsupported_hash_algorithm")
        if imprint["hashed_message"].native != bytes.fromhex(content_hash_hex):
            return TsaVerification(ok=False, reason="imprint_mismatch")

        # The signature covers the signed attributes; the messageDigest
        # attribute must in turn match the encapsulated TSTInfo bytes.
        econtent_field = signed_data["encap_content_info"]["content"]
        econtent_octets = getattr(econtent_field, "contents", None)
        if not isinstance(econtent_octets, bytes):
            # Fallback: re-encode the parsed TSTInfo (DER is canonical,
            # so this reproduces the original eContent octets).
            econtent_octets = tst_info.dump()
        expected_digest = hashlib.sha256(econtent_octets).digest()
        message_digest_attr = _find_attribute(signer_info, "message_digest")
        if message_digest_attr is None:
            return TsaVerification(ok=False, reason="message_digest_missing")
        if message_digest_attr != expected_digest:
            return TsaVerification(ok=False, reason="message_digest_mismatch")

        if len(signed_data["certificates"]) == 0:
            return TsaVerification(ok=False, reason="tsa_certificate_missing")
        certificate = signed_data["certificates"][0].chosen

        signed_attrs_der = signer_info["signed_attrs"].untag().dump()
        try:
            public_key = load_der_public_key(certificate.public_key.dump())
            public_key.verify(
                signer_info["signature"].native,
                signed_attrs_der,
                padding.PKCS1v15(),
                hashes.SHA256(),
            )
        except Exception:
            return TsaVerification(ok=False, reason="signature_invalid")

        gen_time = tst_info["gen_time"].native
        if not isinstance(gen_time, datetime):
            return TsaVerification(ok=False, reason="gen_time_unparseable")
        gen_time = _ensure_utc(gen_time)
        now = datetime.now(timezone.utc)
        if gen_time > now + _MAX_CLOCK_SKEW:
            return TsaVerification(ok=False, reason="gen_time_in_future")

        not_before = _ensure_utc(
            certificate["tbs_certificate"]["validity"]["not_before"].native
        )
        not_after = _ensure_utc(
            certificate["tbs_certificate"]["validity"]["not_after"].native
        )
        if not (not_before - _MAX_CLOCK_SKEW <= gen_time <= not_after + _MAX_CLOCK_SKEW):
            return TsaVerification(ok=False, reason="cert_not_valid_at_gen_time")

        return TsaVerification(ok=True, signed_at=gen_time)


def _find_attribute(signer_info, name: str) -> Optional[bytes]:
    """Return the first value of a signed attribute, or None."""
    for attribute in signer_info["signed_attrs"]:
        if attribute["type"].native == name:
            values = attribute["values"]
            if len(values) > 0:
                return values[0].native
    return None


class ForensicFingerprintService:
    """Create, sign, verify and package four-layer forensic records."""

    def __init__(self, tsa_client: Optional[TsaClient] = None) -> None:
        settings = get_settings()
        if tsa_client is not None:
            self._tsa = tsa_client
        elif settings.security_tsa_url.strip():
            self._tsa = TsaClient(
                settings.security_tsa_url,
                timeout_seconds=settings.security_tsa_timeout_seconds,
            )
        else:
            self._tsa = None

    @property
    def timestamping_available(self) -> bool:
        """True when an RFC 3161 TSA is configured."""
        return self._tsa is not None

    def create_record(
        self,
        db: Session,
        subject_type: str,
        subject_id: str,
        content: Optional[bytes] = None,
        content_hash: Optional[str] = None,
        image_path: Optional[str] = None,
        request_timestamp: bool = True,
    ) -> ForensicRecord:
        """Create a fingerprint record for one evidence subject.

        Either ``content`` (hashed here and discarded) or a precomputed
        ``content_hash`` must be given. ``image_path`` additionally
        produces a perceptual hash for media subjects.
        """
        if content is not None and content_hash is None:
            content_hash = content_sha256(content)
        if not content_hash:
            raise ValueError("either content or content_hash is required")

        record = ForensicRecord(
            subject_type=subject_type,
            subject_id=str(subject_id),
            content_hash=content_hash,
            perceptual_hash=perceptual_hash(image_path) if image_path else None,
            tsa_status="pending",
        )
        db.add(record)
        db.commit()
        db.refresh(record)
        if request_timestamp:
            self.sign_record(db, record)
        return record

    def sign_record(self, db: Session, record: ForensicRecord) -> ForensicRecord:
        """Sign (or retry) the trusted timestamp for a record.

        With no TSA configured the record stays ``pending`` -- absence
        is never forged. A TSA error or an unverifiable token moves the
        record to ``failed`` without touching the content hash.
        """
        if self._tsa is None:
            return record

        record.tsa_requested_at = datetime.now(timezone.utc)
        try:
            token = self._tsa.sign(bytes.fromhex(record.content_hash))
        except TsaError:
            logger.warning(
                "tsa signing failed for forensic record %s", record.id, exc_info=True
            )
            record.tsa_status = "failed"
            db.commit()
            return record

        verification = TsaClient.verify_token(token, record.content_hash)
        if not verification.ok:
            logger.warning(
                "tsa token rejected for forensic record %s: %s",
                record.id,
                verification.reason,
            )
            record.tsa_status = "failed"
            db.commit()
            return record

        record.tsa_token = token
        record.tsa_status = "signed"
        record.tsa_signed_at = verification.signed_at
        db.commit()
        db.refresh(record)
        return record

    def sign_pending(self, db: Session, limit: int = 100) -> int:
        """Retry signing for pending/failed records; return signed count."""
        if self._tsa is None:
            return 0
        records = (
            db.query(ForensicRecord)
            .filter(ForensicRecord.tsa_status.in_(("pending", "failed")))
            .order_by(ForensicRecord.id.asc())
            .limit(limit)
            .all()
        )
        signed = 0
        for record in records:
            previous = record.tsa_status
            self.sign_record(db, record)
            if record.tsa_status == "signed" and previous != "signed":
                signed += 1
        return signed

    def verify_record(self, db: Session, record_id: int) -> ForensicVerification:
        """Verify the timestamp token and custody chain of one record."""
        record = db.get(ForensicRecord, record_id)
        if record is None:
            raise KeyError(f"forensic record {record_id} not found")

        tsa_verified: Optional[bool] = None
        signed_at: Optional[datetime] = None
        reason: Optional[str] = None
        if record.tsa_status == "signed" and record.tsa_token:
            verification = TsaClient.verify_token(
                record.tsa_token, record.content_hash
            )
            tsa_verified = verification.ok
            signed_at = verification.signed_at
            reason = verification.reason

        custody_valid = self.verify_custody_chain(record)
        checks = [value for value in (tsa_verified, custody_valid) if value is not None]
        return ForensicVerification(
            ok=all(checks) if checks else False,
            tsa_verified=tsa_verified,
            custody_chain_valid=custody_valid,
            signed_at=signed_at,
            reason=reason,
        )

    def append_custody(
        self,
        db: Session,
        record: ForensicRecord,
        *,
        operator_id: int,
        action: str,
        operator_role: Optional[str] = None,
        before: Optional[dict] = None,
        after: Optional[dict] = None,
        note: Optional[str] = None,
        approver_id: Optional[int] = None,
        approver_role: Optional[str] = None,
    ) -> ForensicRecord:
        """Append one chain-of-custody entry to the record.

        ``before``/``after`` are caller-provided **redacted** state
        snapshots; raw content must never be passed here. Passing
        ``approver_id`` records the dual-person verification required
        for sensitive handling and marks the record verified.
        """
        entries: List[dict] = list(record.custody_log or [])
        now = datetime.now(timezone.utc)
        prev_entry_hash = entries[-1]["entry_hash"] if entries else None
        dual_verification = None
        if approver_id is not None:
            dual_verification = {
                "approver_id": approver_id,
                "approver_role": approver_role,
                "at": now.isoformat(),
            }

        entry = {
            "seq": len(entries) + 1,
            "at": now.isoformat(),
            "operator_id": operator_id,
            "operator_role": operator_role,
            "action": action,
            "object_hash": record.content_hash,
            "before": before,
            "after": after,
            "note": note,
            "dual_verification": dual_verification,
            "prev_entry_hash": prev_entry_hash,
        }
        entry["entry_hash"] = _hash_custody_entry(entry)
        entries.append(entry)

        record.custody_log = entries
        if dual_verification is not None:
            record.verified = True
        db.commit()
        db.refresh(record)
        return record

    @staticmethod
    def verify_custody_chain(record: ForensicRecord) -> bool:
        """Recompute every custody entry hash and its linkage."""
        entries = list(record.custody_log or [])
        previous_hash: Optional[str] = None
        for entry in entries:
            if entry.get("prev_entry_hash") != previous_hash:
                return False
            if _hash_custody_entry(entry) != entry.get("entry_hash"):
                return False
            previous_hash = entry.get("entry_hash")
        return True

    def build_forensic_package(self, db: Session, record: ForensicRecord) -> dict:
        """Assemble the exportable forensic package for one record.

        The package carries only hashes and redacted snapshots: subject
        evidence (content hash + trusted timestamp), process evidence
        (chained audit entries for the subject), the custody log, and
        the integrity verdicts (TSA token + custody chain).
        """
        verification = self.verify_record(db, record.id)
        custody_entries = list(record.custody_log or [])
        audit_service = AuditChainService()
        audit_entries = audit_service.entries_for_subject(
            db, record.subject_type, record.subject_id
        )
        return {
            "package_version": 1,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "subject": {
                "type": record.subject_type,
                "id": record.subject_id,
            },
            "content_evidence": {
                "hash_algorithm": record.hash_algorithm,
                "content_hash": record.content_hash,
                "perceptual_hash": record.perceptual_hash,
            },
            "time_evidence": {
                "status": record.tsa_status,
                "signed_at": (
                    record.tsa_signed_at.isoformat() if record.tsa_signed_at else None
                ),
                "token_sha256": (
                    hashlib.sha256(record.tsa_token).hexdigest()
                    if record.tsa_token
                    else None
                ),
            },
            "custody_evidence": {
                "entries": len(custody_entries),
                "verified_by_two_people": record.verified,
                "chain_valid": verification.custody_chain_valid,
                "log": custody_entries,
            },
            "process_evidence": {
                "audit_entries": [
                    {
                        "id": entry.id,
                        "actor_id": entry.actor_id,
                        "actor_role": entry.actor_role,
                        "action": entry.action,
                        "created_at": _ensure_utc(entry.created_at).isoformat(),
                        "entry_hash": entry.entry_hash,
                    }
                    for entry in audit_entries
                ],
            },
            "integrity": {
                "ok": verification.ok,
                "tsa_verified": verification.tsa_verified,
                "custody_chain_valid": verification.custody_chain_valid,
                "chain_anchor": record.chain_anchor,
            },
        }


def _hash_custody_entry(entry: dict) -> str:
    """Return the SHA-256 over one custody entry (minus its own hash)."""
    payload = {key: value for key, value in entry.items() if key != "entry_hash"}
    return hashlib.sha256(canonical_bytes(payload)).hexdigest()


def _ensure_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


__all__ = [
    "ForensicFingerprintService",
    "ForensicVerification",
    "TsaClient",
    "TsaError",
    "TsaVerification",
    "content_sha256",
    "perceptual_hamming_distance",
    "perceptual_hash",
]

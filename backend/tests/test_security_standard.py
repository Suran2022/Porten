"""Tests for the standard-profile security capabilities.

Redis-backed services are exercised against a small in-memory fake
(no external dependency); database-backed services run on SQLite with
only the tables they need, following the pattern in test_security.py.
"""

import io
import zipfile
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
import redis
from PIL import Image
from sqlalchemy import Integer, create_engine
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import sessionmaker

from app.models import (
    DeviceSession,
    LoginAttempt,
    Message,
    SecurityEvent,
    UrlReputation,
)
from app.schemas.security import UrlVerdictLevel
from app.services import redis_rate_limit_service as rate_limit_module
from app.services.behavior_analysis_service import BehaviorAnalyzer
from app.services.device_binding_service import DeviceBindingService
from app.services.event_queue_service import RedisStreamEventQueue, StreamingEventSink
from app.services.file_sanitizer_service import (
    SYNC_REENCODE_MAX_BYTES,
    MediaFileSanitizer,
    SanitizeError,
)
from app.services.login_attempt_service import LoginAttemptService
from app.services.redis_rate_limit_service import RedisRateLimiter
from app.services.security_event_service import SecurityEventService
from app.services.threat_intel_service import ThreatIntelService
from app.services.url_scanner_service import CachedUrlScanner, LocalRuleUrlScanner
from app.services.waf_service import RedisWafRuleProvider
from app.utils import hash_ip


# ---------------------------------------------------------------------------
# In-memory Redis fake
# ---------------------------------------------------------------------------


class _FakePipeline:
    """Queues commands and replays them against the fake client."""

    def __init__(self, client: "FakeRedis") -> None:
        self._client = client
        self._ops: list = []

    def zremrangebyscore(self, key, min_score, max_score):
        self._ops.append(("zremrangebyscore", (key, min_score, max_score)))
        return self

    def zcard(self, key):
        self._ops.append(("zcard", (key,)))
        return self

    def zadd(self, key, mapping):
        self._ops.append(("zadd", (key, mapping)))
        return self

    def expire(self, key, seconds):
        self._ops.append(("expire", (key, seconds)))
        return self

    def execute(self):
        return [getattr(self._client, name)(*args) for name, args in self._ops]


class FakeRedis:
    """In-memory stand-in for the Redis subset the services use.

    ``fail`` switches every operation to raise ``RedisError`` so the
    degradation paths can be exercised without a live server.
    """

    def __init__(self) -> None:
        self._strings: dict = {}
        self._zsets: dict = {}
        self._streams: dict = {}
        self._sets: dict = {}
        self._seq = 0
        self.fail = False

    def _check(self) -> None:
        if self.fail:
            raise redis.RedisError("fake redis unavailable")

    def pipeline(self):
        return _FakePipeline(self)

    # strings
    def get(self, key):
        self._check()
        return self._strings.get(key)

    def set(self, key, value, ex=None):
        self._check()
        self._strings[key] = value

    def delete(self, *keys):
        self._check()
        for key in keys:
            self._strings.pop(key, None)
            self._zsets.pop(key, None)
            self._streams.pop(key, None)

    # sorted sets
    def zremrangebyscore(self, key, min_score, max_score):
        self._check()
        zset = self._zsets.setdefault(key, {})
        for member in [m for m, s in zset.items() if min_score <= s <= max_score]:
            del zset[member]

    def zcard(self, key):
        self._check()
        return len(self._zsets.get(key, {}))

    def zadd(self, key, mapping):
        self._check()
        self._zsets.setdefault(key, {}).update(mapping)

    def zrem(self, key, member):
        self._check()
        self._zsets.get(key, {}).pop(member, None)

    def expire(self, key, seconds):
        self._check()

    # sets
    def sadd(self, key, *members):
        self._check()
        current = self._sets.setdefault(key, set())
        before = len(current)
        current.update(members)
        return len(current) - before

    def srem(self, key, *members):
        self._check()
        current = self._sets.get(key, set())
        removed = sum(1 for member in members if member in current)
        current.difference_update(members)
        return removed

    def smembers(self, key):
        self._check()
        return set(self._sets.get(key, set()))

    # streams
    def xadd(self, key, fields, maxlen=None, approximate=True):
        self._check()
        self._seq += 1
        entry_id = f"{self._seq}-0"
        entries = self._streams.setdefault(key, [])
        entries.append((entry_id, dict(fields)))
        if maxlen is not None and len(entries) > maxlen:
            del entries[: len(entries) - maxlen]
        return entry_id

    def xrange(self, key, min="-", max="+", count=None):
        self._check()
        entries = list(self._streams.get(key, []))
        if min not in ("-", ""):
            exclusive = min.startswith("(")
            boundary = self._parse_id(min[1:] if exclusive else min)
            entries = [
                (entry_id, fields)
                for entry_id, fields in entries
                if self._parse_id(entry_id) > boundary
                if exclusive or self._parse_id(entry_id) >= boundary
            ]
        if count is not None:
            entries = entries[:count]
        return entries

    def xlen(self, key):
        self._check()
        return len(self._streams.get(key, []))

    @staticmethod
    def _parse_id(raw: str):
        ms, _, seq = raw.partition("-")
        return (int(ms), int(seq or 0))


class _Clock:
    """Deterministic ``time`` replacement for window-expiry tests."""

    def __init__(self, now: float = 1000.0) -> None:
        self.now = now

    def time(self) -> float:
        return self.now


@pytest.fixture()
def fake_redis():
    return FakeRedis()


@pytest.fixture()
def db_engine():
    """In-memory SQLite holding exactly the tables under test."""
    engine = create_engine("sqlite://")
    tables = (
        SecurityEvent.__table__,
        UrlReputation.__table__,
        DeviceSession.__table__,
        LoginAttempt.__table__,
        Message.__table__,
    )
    # SQLite only autoincrements INTEGER PRIMARY KEY (rowid alias);
    # production MySQL is unaffected by the temporary retype.
    originals = {table: table.c.id.type for table in tables}
    for table in tables:
        table.c.id.type = Integer()
        table.create(engine)
        table.c.id.type = originals[table]
    yield engine
    engine.dispose()


@pytest.fixture()
def session_factory(db_engine):
    return sessionmaker(bind=db_engine)


@pytest.fixture()
def db_session(session_factory):
    session = session_factory()
    yield session
    session.close()


def _message(session, sender_id, conversation_id, created_at, content="hi"):
    message = Message(
        sender_id=sender_id,
        conversation_id=conversation_id,
        content=content,
        message_type="text",
        created_at=created_at,
    )
    session.add(message)
    return message


# ---------------------------------------------------------------------------
# Redis rate limiter
# ---------------------------------------------------------------------------


class TestRedisRateLimiter:
    def test_allows_up_to_limit_then_denies(self, fake_redis):
        limiter = RedisRateLimiter(fake_redis)
        results = [limiter.allow("ip:1", 3, 60) for _ in range(4)]
        assert results == [True, True, True, False]

    def test_denied_request_does_not_consume_quota(self, fake_redis):
        limiter = RedisRateLimiter(fake_redis)
        for _ in range(3):
            assert limiter.allow("ip:1", 3, 60)
        assert limiter.allow("ip:1", 3, 60) is False
        # The rolled-back timestamp leaves exactly the accepted count.
        assert fake_redis.zcard("porten:ratelimit:ip:1") == 3

    def test_window_expiry_frees_quota(self, fake_redis, monkeypatch):
        clock = _Clock()
        monkeypatch.setattr(rate_limit_module, "time", clock)
        limiter = RedisRateLimiter(fake_redis)
        # Advance the clock between calls: in production each request
        # lands on a distinct timestamp (and thus a distinct member).
        results = []
        for _ in range(3):
            results.append(limiter.allow("ip:1", 2, 60))
            clock.now += 1
        assert results == [True, True, False]
        clock.now += 61
        assert limiter.allow("ip:1", 2, 60) is True

    def test_falls_back_when_redis_fails(self, fake_redis):
        limiter = RedisRateLimiter(fake_redis)
        fake_redis.fail = True
        assert [limiter.allow("ip:1", 2, 60) for _ in range(3)] == [
            True,
            True,
            False,
        ]


# ---------------------------------------------------------------------------
# Threat intel + cached scanner
# ---------------------------------------------------------------------------


class TestThreatIntel:
    def test_unknown_host_returns_none(self, fake_redis, session_factory):
        service = ThreatIntelService(fake_redis, session_factory=session_factory)
        assert service.get_reputation("unknown.example.com") is None

    def test_record_then_lookup(self, fake_redis, db_session):
        service = ThreatIntelService(fake_redis, session_factory=lambda: db_session)
        service.record_reputation(
            db_session,
            "bad.example.com",
            UrlVerdictLevel.MALICIOUS,
            "confirmed phishing",
            source="review",
        )
        verdict = service.get_reputation("bad.example.com")
        assert verdict is not None
        assert verdict.level == UrlVerdictLevel.MALICIOUS

    def test_cache_hit_avoids_database(self, fake_redis, db_session):
        service = ThreatIntelService(fake_redis, session_factory=lambda: db_session)
        service.record_reputation(
            db_session, "cached.example.com", UrlVerdictLevel.SAFE, "reviewed"
        )
        # Warm the cache, then drop the row: a cache hit must still answer.
        assert service.get_reputation("cached.example.com") is not None
        db_session.query(UrlReputation).delete()
        db_session.commit()
        assert service.get_reputation("cached.example.com") is not None

    def test_expired_record_ignored(self, fake_redis, db_session):
        service = ThreatIntelService(fake_redis, session_factory=lambda: db_session)
        service.record_reputation(
            db_session,
            "stale.example.com",
            UrlVerdictLevel.MALICIOUS,
            "expired verdict",
            expires_at=datetime.now(timezone.utc) - timedelta(hours=1),
        )
        assert service.get_reputation("stale.example.com") is None

    def test_redis_failure_falls_through_to_db(self, fake_redis, db_session):
        service = ThreatIntelService(fake_redis, session_factory=lambda: db_session)
        service.record_reputation(
            db_session, "dbonly.example.com", UrlVerdictLevel.SUSPICIOUS, "reported"
        )
        fake_redis.fail = True
        verdict = service.get_reputation("dbonly.example.com")
        assert verdict is not None
        assert verdict.level == UrlVerdictLevel.SUSPICIOUS

    def test_record_invalidates_cache(self, fake_redis, db_session):
        service = ThreatIntelService(fake_redis, session_factory=lambda: db_session)
        service.record_reputation(
            db_session, "flip.example.com", UrlVerdictLevel.SAFE, "first look"
        )
        assert service.get_reputation("flip.example.com").level == UrlVerdictLevel.SAFE
        service.record_reputation(
            db_session, "flip.example.com", UrlVerdictLevel.MALICIOUS, "later review"
        )
        verdict = service.get_reputation("flip.example.com")
        assert verdict.level == UrlVerdictLevel.MALICIOUS


class TestCachedUrlScanner:
    def _scanner(self, fake_redis, session_factory):
        intel = ThreatIntelService(fake_redis, session_factory=session_factory)
        return CachedUrlScanner(LocalRuleUrlScanner(), intel)

    def test_local_malicious_is_final(self, fake_redis, db_session):
        scanner = self._scanner(fake_redis, lambda: db_session)
        # Even a "safe" reputation cannot launder a private address.
        ThreatIntelService(fake_redis, session_factory=lambda: db_session).record_reputation(
            db_session, "127.0.0.1", UrlVerdictLevel.SAFE, "internal test host"
        )
        verdict = scanner.scan("http://127.0.0.1/admin")
        assert verdict.level == UrlVerdictLevel.MALICIOUS

    def test_reputation_overrides_heuristic(self, fake_redis, db_session):
        scanner = self._scanner(fake_redis, lambda: db_session)
        ThreatIntelService(fake_redis, session_factory=lambda: db_session).record_reputation(
            db_session, "example.com", UrlVerdictLevel.SAFE, "reviewed, clean"
        )
        # Non-standard port alone is only suspicious; review clears it.
        verdict = scanner.scan("http://example.com:8080/page")
        assert verdict.level == UrlVerdictLevel.SAFE

    def test_reputation_escalates_unknown_host(self, fake_redis, db_session):
        scanner = self._scanner(fake_redis, lambda: db_session)
        ThreatIntelService(fake_redis, session_factory=lambda: db_session).record_reputation(
            db_session, "clean-looking.example.org", UrlVerdictLevel.MALICIOUS, "intel feed"
        )
        verdict = scanner.scan("https://clean-looking.example.org/offer")
        assert verdict.level == UrlVerdictLevel.MALICIOUS

    def test_no_reputation_uses_local_verdict(self, fake_redis, db_session):
        scanner = self._scanner(fake_redis, lambda: db_session)
        verdict = scanner.scan("https://porten.example.com/help")
        assert verdict.level == UrlVerdictLevel.SAFE


# ---------------------------------------------------------------------------
# Event queue + streaming sink
# ---------------------------------------------------------------------------


class TestEventQueue:
    def test_publish_returns_entry_id(self, fake_redis):
        queue = RedisStreamEventQueue(fake_redis, "stream", "cursor")
        entry_id = queue.publish("upload_rejected", {"user_id": 7})
        assert entry_id is not None
        assert fake_redis.xlen("stream") == 1

    def test_cursor_roundtrip(self, fake_redis):
        queue = RedisStreamEventQueue(fake_redis, "stream", "cursor")
        assert queue.get_cursor() == "0"
        entry_id = queue.publish("x", {"a": 1})
        queue.advance_cursor(entry_id)
        assert queue.get_cursor() == entry_id

    def test_replay_since_is_exclusive_and_bounded(self, fake_redis):
        queue = RedisStreamEventQueue(fake_redis, "stream", "cursor")
        first = queue.publish("a", {"n": 1})
        second = queue.publish("b", {"n": 2})
        queue.publish("c", {"n": 3})

        entries = queue.replay_since(first, count=10)
        assert [entry["type"] for entry in entries] == ["b", "c"]

        entries = queue.replay_since(first, count=1)
        assert [entry["type"] for entry in entries] == ["b"]

    def test_pending_count(self, fake_redis):
        queue = RedisStreamEventQueue(fake_redis, "stream", "cursor")
        queue.publish("a", {})
        queue.publish("b", {})
        assert queue.pending_count() == 2
        cursor = queue.publish("c", {})
        queue.advance_cursor(cursor)
        assert queue.pending_count() == 0

    def test_publish_failure_returns_none(self, fake_redis):
        queue = RedisStreamEventQueue(fake_redis, "stream", "cursor")
        fake_redis.fail = True
        assert queue.publish("a", {}) is None
        assert queue.replay_since("0") == []

    def test_sink_writes_db_then_publishes(self, fake_redis, db_session):
        sink = StreamingEventSink(
            SecurityEventService(),
            RedisStreamEventQueue(fake_redis, "stream", "cursor"),
        )
        sink.emit(
            db_session,
            event_type="behavior_risk",
            severity="warning",
            user_id=1,
            detail="level=high",
            meta={"score": 0.8},
        )
        event = db_session.query(SecurityEvent).one()
        assert event.event_type == "behavior_risk"
        assert event.meta == {"score": 0.8}
        assert fake_redis.xlen("stream") == 1

    def test_sink_keeps_db_record_when_stream_fails(self, fake_redis, db_session):
        sink = StreamingEventSink(
            SecurityEventService(),
            RedisStreamEventQueue(fake_redis, "stream", "cursor"),
        )
        fake_redis.fail = True
        sink.emit(db_session, event_type="behavior_risk", user_id=1)
        assert db_session.query(SecurityEvent).count() == 1
        assert fake_redis._streams.get("stream", []) == []


# ---------------------------------------------------------------------------
# WAF rules
# ---------------------------------------------------------------------------


class TestWafRules:
    def test_seed_rule_blocks_injection(self, fake_redis):
        provider = RedisWafRuleProvider(fake_redis, "waf:rules")
        assert provider.matches("/search", "q=1 union select 1") == "sql_union_select"
        assert provider.matches("/page", "<script>alert(1)</script>") == "xss_script_tag"
        assert provider.matches("/clean", "q=hello") is None

    def test_encoded_payloads_blocked(self, fake_redis):
        provider = RedisWafRuleProvider(fake_redis, "waf:rules")
        # '+' and %XX-encoded spaces must not sneak past the patterns.
        assert provider.matches("/search", "q=1+union+select+1") == "sql_union_select"
        assert provider.matches("/search", "q=1%20union%20select%201") == "sql_union_select"
        assert (
            provider.matches("/search", "q=1%2520union%2520select%25201")
            == "sql_union_select"
        )
        assert (
            provider.matches("/files/..%2f..%2fetc/passwd", "") == "path_traversal"
        )

    def test_hot_reload_replaces_rule_set(self, fake_redis):
        provider = RedisWafRuleProvider(fake_redis, "waf:rules")
        provider.publish_rules(
            [{"name": "custom_block", "pattern": "forbidden-path"}], "v2"
        )
        assert provider.current_version() == "v2"
        assert provider.matches("/forbidden-path", "") == "custom_block"
        # The seed set was replaced, not merged.
        assert provider.matches("/search", "q=1 union select 1") is None

    def test_missing_document_restores_seed(self, fake_redis):
        provider = RedisWafRuleProvider(fake_redis, "waf:rules")
        provider.publish_rules(
            [{"name": "custom_block", "pattern": "forbidden-path"}], "v2"
        )
        fake_redis._strings.pop("waf:rules", None)
        provider._last_refresh = 0.0  # force a refresh attempt
        assert provider.current_version() == "seed"
        assert provider.matches("/x", "union select") == "sql_union_select"
        assert provider.matches("/forbidden-path", "") is None

    def test_invalid_document_ignored(self, fake_redis):
        provider = RedisWafRuleProvider(fake_redis, "waf:rules")
        fake_redis._strings["waf:rules"] = "not-json{"
        provider._last_refresh = 0.0
        assert provider.current_version() == "seed"
        assert provider.matches("/x", "union select") == "sql_union_select"

    def test_redis_failure_keeps_seed_rules(self, fake_redis):
        provider = RedisWafRuleProvider(fake_redis, "waf:rules")
        fake_redis.fail = True
        provider._last_refresh = 0.0
        assert provider.matches("/x", "union select") == "sql_union_select"


# ---------------------------------------------------------------------------
# File sanitizer
# ---------------------------------------------------------------------------


def _image_bytes(fmt: str, payload: bytes = b"") -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (8, 8), (10, 20, 30)).save(buffer, format=fmt)
    return buffer.getvalue() + payload


@pytest.fixture()
def sanitizer():
    return MediaFileSanitizer()


@pytest.fixture()
def upload_file(tmp_path):
    def _write(name: str, data: bytes):
        path = tmp_path / name
        path.write_bytes(data)
        return path

    return _write


class TestFileSanitizer:
    def test_jpeg_trailing_payload_stripped(self, sanitizer, upload_file):
        path = upload_file("photo.jpg", _image_bytes("JPEG", b"HIDDEN-PAYLOAD"))
        sanitizer.sanitize(str(path), "image/jpeg")
        data = path.read_bytes()
        assert data.startswith(b"\xff\xd8\xff")
        assert b"HIDDEN-PAYLOAD" not in data

    def test_png_trailing_payload_stripped(self, sanitizer, upload_file):
        path = upload_file("pic.png", _image_bytes("PNG", b"HIDDEN-PAYLOAD"))
        sanitizer.sanitize(str(path), "image/png")
        data = path.read_bytes()
        assert data.startswith(b"\x89PNG")
        assert b"HIDDEN-PAYLOAD" not in data

    def test_exe_disguised_as_image_refused(self, sanitizer, upload_file):
        path = upload_file("malware.jpg", b"MZ" + b"\x00" * 62)
        with pytest.raises(SanitizeError):
            sanitizer.sanitize(str(path), "image/jpeg")

    def test_garbage_refused(self, sanitizer, upload_file):
        path = upload_file("random.bin", b"\x00" * 64)
        with pytest.raises(SanitizeError):
            sanitizer.sanitize(str(path), "application/octet-stream")

    def test_zip_declared_as_pdf_refused(self, sanitizer, upload_file):
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            archive.writestr("hello.txt", "hi")
        path = upload_file("doc.pdf", buffer.getvalue())
        with pytest.raises(SanitizeError):
            sanitizer.sanitize(str(path), "application/pdf")

    def test_image_declared_as_non_image_refused(self, sanitizer, upload_file):
        path = upload_file("sneak.png", _image_bytes("PNG"))
        with pytest.raises(SanitizeError):
            sanitizer.sanitize(str(path), "application/pdf")

    def test_pdf_declared_correctly_passes(self, sanitizer, upload_file):
        path = upload_file("doc.pdf", b"%PDF-1.4\n" + b"body" * 20)
        assert sanitizer.sanitize(str(path), "application/pdf") == str(path)

    def test_jpg_alias_accepted(self, sanitizer, upload_file):
        path = upload_file("photo.jpg", _image_bytes("JPEG"))
        assert sanitizer.sanitize(str(path), "image/jpg") == str(path)

    def test_large_image_skips_sync_reencode(self, sanitizer, upload_file, monkeypatch):
        monkeypatch.setattr(
            "app.services.file_sanitizer_service.SYNC_REENCODE_MAX_BYTES", 4
        )
        data = _image_bytes("JPEG", b"TRAILER")
        path = upload_file("big.jpg", data)
        assert sanitizer.sanitize(str(path), "image/jpeg") == str(path)
        # Untouched: the async path owns re-encoding for large files.
        assert path.read_bytes() == data

    def test_riff_webp_disambiguated(self, sanitizer, upload_file):
        header = b"RIFF" + b"\x00" * 4 + b"WEBP" + b"VP8 " + b"\x00" * 16
        path = upload_file("pic.webp", header)
        assert sanitizer._detect_type(path) == "image/webp"

    def test_riff_wave_disambiguated(self, sanitizer, upload_file):
        header = b"RIFF" + b"\x00" * 4 + b"WAVE" + b"fmt " + b"\x00" * 16
        path = upload_file("snd.wav", header)
        assert sanitizer._detect_type(path) == "audio/wav"


# ---------------------------------------------------------------------------
# Device binding
# ---------------------------------------------------------------------------


class TestDeviceBinding:
    def test_bind_and_validate(self, db_session):
        service = DeviceBindingService()
        user = SimpleNamespace(id=1)
        service.bind_device(db_session, user, "device-a", "My Phone", "ios")
        assert service.is_device_valid(db_session, 1, "device-a") is True

    def test_revoke_invalidates(self, db_session):
        service = DeviceBindingService()
        service.bind_device(db_session, SimpleNamespace(id=1), "device-a")
        assert service.revoke_device(db_session, 1, "device-a") is True
        assert service.is_device_valid(db_session, 1, "device-a") is False
        # Second revoke is a no-op.
        assert service.revoke_device(db_session, 1, "device-a") is False

    def test_relogin_reactivates_revoked_binding(self, db_session):
        service = DeviceBindingService()
        service.bind_device(db_session, SimpleNamespace(id=1), "device-a")
        service.revoke_device(db_session, 1, "device-a")
        service.bind_device(db_session, SimpleNamespace(id=1), "device-a")
        assert service.is_device_valid(db_session, 1, "device-a") is True

    def test_touch_throttled_within_interval(self, db_session):
        service = DeviceBindingService()
        service.bind_device(db_session, SimpleNamespace(id=1), "device-a")
        first = (
            db_session.query(DeviceSession)
            .filter_by(device_id="device-a")
            .one()
            .last_seen_at
        )
        service.touch_device(db_session, 1, "device-a")
        second = (
            db_session.query(DeviceSession)
            .filter_by(device_id="device-a")
            .one()
            .last_seen_at
        )
        assert first == second

    def test_touch_updates_after_interval(self, db_session):
        service = DeviceBindingService()
        service.bind_device(db_session, SimpleNamespace(id=1), "device-a")
        record = (
            db_session.query(DeviceSession).filter_by(device_id="device-a").one()
        )
        stale = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(seconds=301)
        record.last_seen_at = stale
        db_session.commit()
        service.touch_device(db_session, 1, "device-a")
        # SQLite strips tzinfo; stored values are UTC wall time.
        assert record.last_seen_at > stale


# ---------------------------------------------------------------------------
# Edge blocklist
# ---------------------------------------------------------------------------


class TestEdgeBlocklist:
    def test_empty_by_default(self, fake_redis):
        from app.services.edge_blocklist_service import RedisEdgeBlocklist

        blocklist = RedisEdgeBlocklist(fake_redis, "blocklist")
        assert blocklist.is_blocked("10.0.0.1") is False

    def test_block_and_unblock(self, fake_redis):
        from app.services.edge_blocklist_service import RedisEdgeBlocklist

        blocklist = RedisEdgeBlocklist(fake_redis, "blocklist")
        blocklist.block_ip("10.0.0.1")
        assert blocklist.is_blocked("10.0.0.1") is True
        assert blocklist.is_blocked("10.0.0.2") is False

        blocklist.unblock_ip("10.0.0.1")
        assert blocklist.is_blocked("10.0.0.1") is False

    def test_hot_reload_picks_up_external_change(self, fake_redis):
        from app.services.edge_blocklist_service import RedisEdgeBlocklist

        blocklist = RedisEdgeBlocklist(fake_redis, "blocklist")
        assert blocklist.is_blocked("10.0.0.9") is False
        # Another instance (or an operator) writes directly to Redis.
        fake_redis.sadd("blocklist", "10.0.0.9")
        blocklist._last_refresh = 0.0  # force a refresh attempt
        assert blocklist.is_blocked("10.0.0.9") is True

    def test_redis_failure_keeps_last_known_set(self, fake_redis):
        from app.services.edge_blocklist_service import RedisEdgeBlocklist

        blocklist = RedisEdgeBlocklist(fake_redis, "blocklist")
        blocklist.block_ip("10.0.0.1")
        fake_redis.fail = True
        blocklist._last_refresh = 0.0
        # Fail-open semantics for writes; the cached set still answers.
        assert blocklist.is_blocked("10.0.0.1") is True
        blocklist.block_ip("10.0.0.2")  # must not raise
        assert blocklist.is_blocked("10.0.0.1") is True


# ---------------------------------------------------------------------------
# Behavior analysis
# ---------------------------------------------------------------------------


def _seed_history(session, sender_id, conversation_id, per_day, days):
    """Insert per_day messages for each of the last `days` days."""
    now = datetime.now(timezone.utc)
    for offset in range(1, days + 1):
        day = now - timedelta(days=offset)
        for index in range(per_day):
            _message(
                session,
                sender_id,
                conversation_id,
                day + timedelta(seconds=index),
            )
    session.commit()


class TestBehaviorAnalyzer:
    def test_ignores_non_message_actions(self, db_session):
        assert BehaviorAnalyzer().assess(db_session, 1, "login", {}) is None

    def test_quiet_user_no_signal(self, db_session):
        _seed_history(db_session, 1, 10, per_day=2, days=6)
        _message(db_session, 1, 10, datetime.now(timezone.utc))
        db_session.commit()
        assert BehaviorAnalyzer().assess(
            db_session, 1, "message_send", {"conversation_id": 10}
        ) is None

    def test_baseline_spike_detected(self, db_session):
        _seed_history(db_session, 1, 10, per_day=2, days=6)
        today = datetime.now(timezone.utc)
        for index in range(20):
            _message(db_session, 1, 10, today + timedelta(seconds=index))
        db_session.commit()

        result = BehaviorAnalyzer().assess(
            db_session, 1, "message_send", {"conversation_id": 10}
        )
        assert result is not None
        assert "baseline_spike" in result["signals"]
        assert result["level"] == "medium"

    def test_insufficient_history_no_signal(self, db_session):
        _seed_history(db_session, 1, 10, per_day=2, days=3)
        today = datetime.now(timezone.utc)
        for index in range(50):
            _message(db_session, 1, 10, today + timedelta(seconds=index))
        db_session.commit()
        assert BehaviorAnalyzer().assess(
            db_session, 1, "message_send", {"conversation_id": 10}
        ) is None

    def test_cohort_crowding_detected(self, db_session):
        now = datetime.now(timezone.utc)
        for sender in (1, 2, 3):
            _message(db_session, sender, 20, now - timedelta(minutes=5))
        db_session.commit()

        result = BehaviorAnalyzer().assess(
            db_session, 1, "message_send", {"conversation_id": 20}
        )
        assert result is not None
        assert "cohort_crowding" in result["signals"]

    def test_old_senders_not_counted_as_new(self, db_session):
        now = datetime.now(timezone.utc)
        # Two genuinely new senders, one established member posting again.
        _message(db_session, 1, 20, now - timedelta(minutes=5))
        _message(db_session, 2, 20, now - timedelta(minutes=4))
        _message(db_session, 3, 20, now - timedelta(days=3))
        _message(db_session, 3, 20, now - timedelta(minutes=3))
        db_session.commit()

        assert BehaviorAnalyzer().assess(
            db_session, 1, "message_send", {"conversation_id": 20}
        ) is None

    def test_hard_limit_detected(self, db_session):
        now = datetime.now(timezone.utc)
        session = db_session
        session.bulk_save_objects(
            [
                Message(
                    sender_id=1,
                    conversation_id=30,
                    content="spam",
                    message_type="text",
                    created_at=now - timedelta(seconds=index % 600),
                )
                for index in range(501)
            ]
        )
        session.commit()

        result = BehaviorAnalyzer().assess(
            db_session, 1, "message_send", {"conversation_id": 30}
        )
        assert result is not None
        assert "hard_limit" in result["signals"]

    def test_composite_score_high(self, db_session):
        # Established rhythm in the user's usual conversation ...
        _seed_history(db_session, 1, 10, per_day=2, days=6)
        now = datetime.now(timezone.utc)
        # ... then a burst inside a brand-new funnel conversation the
        # user never posted in before, alongside other fresh senders.
        for index in range(20):
            _message(db_session, 1, 50, now + timedelta(seconds=index))
        for sender in (2, 3):
            _message(db_session, sender, 50, now - timedelta(minutes=5))
        db_session.commit()

        result = BehaviorAnalyzer().assess(
            db_session, 1, "message_send", {"conversation_id": 50}
        )
        assert result is not None
        assert set(result["signals"]) == {"baseline_spike", "cohort_crowding"}
        assert result["score"] >= 0.7
        assert result["level"] == "high"


# ---------------------------------------------------------------------------
# Login attempt recording
# ---------------------------------------------------------------------------


class TestLoginAttempts:
    def test_ip_hash_is_stable_and_salted(self):
        assert hash_ip("10.0.0.1") == hash_ip("10.0.0.1")
        assert hash_ip("10.0.0.1") != hash_ip("10.0.0.2")
        assert len(hash_ip("10.0.0.1")) == 64

    def test_success_recorded(self, db_session):
        LoginAttemptService().record(
            db_session, "user@example.com", "10.0.0.1", success=True, user_id=1
        )
        attempt = db_session.query(LoginAttempt).one()
        assert attempt.success is True
        assert attempt.user_id == 1
        assert attempt.failure_reason is None
        assert attempt.ip_hash == hash_ip("10.0.0.1")

    def test_failure_reason_recorded(self, db_session):
        LoginAttemptService().record(
            db_session,
            "ghost@example.com",
            "10.0.0.2",
            success=False,
            failure_reason="unknown_user",
        )
        attempt = db_session.query(LoginAttempt).one()
        assert attempt.success is False
        assert attempt.user_id is None
        assert attempt.failure_reason == "unknown_user"

    def test_db_failure_swallowed(self):
        class _BrokenSession:
            def add(self, obj):
                pass

            def commit(self):
                raise SQLAlchemyError("disk on fire")

            def rollback(self):
                pass

        # Must not raise: audit writes never break login.
        LoginAttemptService().record(
            _BrokenSession(), "user@example.com", "10.0.0.1", success=True
        )


# ---------------------------------------------------------------------------
# Factory assembly
# ---------------------------------------------------------------------------


class TestFactory:
    def test_lite_assembly(self):
        from app.security.factory import build_security_capabilities

        capabilities = build_security_capabilities("lite")
        assert capabilities.rate_limiter is not None
        assert capabilities.waf_rules is None
        assert capabilities.file_sanitizer is None
        assert capabilities.behavior_analyzer is None

    def test_standard_assembly_with_redis(self, monkeypatch):
        from app.security import factory

        monkeypatch.setattr(factory, "create_redis_client", lambda url=None: FakeRedis())
        capabilities = factory.build_security_capabilities("standard")
        assert type(capabilities.rate_limiter).__name__ == "RedisRateLimiter"
        assert type(capabilities.url_scanner).__name__ == "CachedUrlScanner"
        assert type(capabilities.event_sink).__name__ == "StreamingEventSink"
        assert type(capabilities.waf_rules).__name__ == "RedisWafRuleProvider"
        assert type(capabilities.file_sanitizer).__name__ == "MediaFileSanitizer"
        assert type(capabilities.behavior_analyzer).__name__ == "BehaviorAnalyzer"
        assert type(capabilities.edge_blocklist).__name__ == "RedisEdgeBlocklist"

    def test_standard_degrades_without_redis(self, monkeypatch):
        from app.security import factory

        monkeypatch.setattr(factory, "create_redis_client", lambda url=None: None)
        capabilities = factory.build_security_capabilities("standard")
        assert type(capabilities.rate_limiter).__name__ == "InMemoryRateLimiter"
        assert type(capabilities.url_scanner).__name__ == "LocalRuleUrlScanner"
        assert type(capabilities.event_sink).__name__ == "SecurityEventService"
        assert capabilities.waf_rules is None
        assert capabilities.event_queue is None
        assert capabilities.edge_blocklist is None
        # Redis-independent capabilities stay active.
        assert capabilities.file_sanitizer is not None
        assert capabilities.behavior_analyzer is not None

    def test_standard_fails_fast_when_redis_required(self, monkeypatch):
        from app.config import get_settings
        from app.security import factory

        settings = get_settings()
        monkeypatch.setattr(factory, "create_redis_client", lambda url=None: None)
        original = settings.security_redis_required
        settings.security_redis_required = True
        try:
            with pytest.raises(RuntimeError):
                factory.build_security_capabilities("standard")
        finally:
            settings.security_redis_required = original

    def test_unknown_profile_rejected(self):
        from app.security.factory import build_security_capabilities

        with pytest.raises(ValueError):
            build_security_capabilities("bogus")

    def test_advanced_assembly_with_redis(self, monkeypatch):
        from app.security import factory

        monkeypatch.setattr(factory, "create_redis_client", lambda url=None: FakeRedis())
        capabilities = factory.build_security_capabilities("advanced")
        # advanced = the full standard set plus the fetch sandbox
        assert type(capabilities.rate_limiter).__name__ == "RedisRateLimiter"
        assert type(capabilities.edge_blocklist).__name__ == "RedisEdgeBlocklist"
        assert capabilities.url_sandbox is not None
        assert hasattr(capabilities.url_sandbox, "fetch")

    def test_advanced_sandbox_disabled_without_config(self, monkeypatch):
        from app.security import factory
        from app.config import get_settings

        monkeypatch.setattr(factory, "create_redis_client", lambda url=None: FakeRedis())
        settings = get_settings()
        original_url = settings.security_sandbox_url
        original_enabled = settings.security_url_fetch_enabled
        settings.security_sandbox_url = None
        settings.security_url_fetch_enabled = False
        try:
            capabilities = factory.build_security_capabilities("advanced")
        finally:
            settings.security_sandbox_url = original_url
            settings.security_url_fetch_enabled = original_enabled
        assert type(capabilities.url_sandbox).__name__ == "DisabledSandbox"

    def test_advanced_degrades_without_redis(self, monkeypatch):
        from app.security import factory

        monkeypatch.setattr(factory, "create_redis_client", lambda url=None: None)
        capabilities = factory.build_security_capabilities("advanced")
        # same degradation contract as standard, sandbox stays assembled
        assert type(capabilities.rate_limiter).__name__ == "InMemoryRateLimiter"
        assert capabilities.waf_rules is None
        assert capabilities.edge_blocklist is None
        assert capabilities.url_sandbox is not None

    def test_advanced_fails_fast_when_redis_required(self, monkeypatch):
        from app.config import get_settings
        from app.security import factory

        monkeypatch.setattr(factory, "create_redis_client", lambda url=None: None)
        settings = get_settings()
        original = settings.security_redis_required
        settings.security_redis_required = True
        try:
            with pytest.raises(RuntimeError):
                factory.build_security_capabilities("advanced")
        finally:
            settings.security_redis_required = original

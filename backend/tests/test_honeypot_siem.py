"""Tests for the honeypot decoys, honeytokens and SIEM export
(design doc §5.5).

The decoy router is exercised through a minimal FastAPI app with the
real honeypot router, an in-memory SQLite session and a recording
event sink; the SIEM exporter runs against an in-memory Redis Stream
stand-in and a stub HTTP client.
"""

import asyncio
import hashlib
import json
import time
from typing import Optional

import httpx
import pytest
import redis
from fastapi import FastAPI, Request
from fastapi.testclient import TestClient
from sqlalchemy import Integer, create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import get_settings
from app.database import get_db
from app.dependencies import auth as auth_module
from app.models import Honeytoken
from app.routers import honeypot as honeypot_module
from app.routers.honeypot import router as honeypot_router
from app.services.honeytoken_service import (
    TOKEN_TYPES,
    HoneytokenService,
    hash_token,
    honeytoken_service,
)
from app.services.siem_export_service import (
    SiemExporter,
    _decode_entry,
    build_siem_exporter,
    siem_export_task,
)
from app.utils.security import hash_ip


@pytest.fixture(autouse=True)
def _restore_settings():
    """Snapshot the settings keys touched by this module."""
    settings = get_settings()
    keys = (
        "security_honeypot_enabled",
        "security_honeypot_autoblock",
        "security_siem_enabled",
        "security_siem_webhook_url",
        "security_siem_interval_seconds",
        "security_siem_batch_size",
        "security_siem_timeout_seconds",
        "security_siem_consumer_group",
        "security_event_stream_key",
    )
    snapshot = {key: getattr(settings, key) for key in keys}
    yield
    for key, value in snapshot.items():
        setattr(settings, key, value)


@pytest.fixture()
def settings():
    return get_settings()


# ---------------------------------------------------------------------------
# Test doubles
# ---------------------------------------------------------------------------


class _RecordingSink:
    """Event sink double that records every emitted event."""

    def __init__(self, fail: bool = False) -> None:
        self.events: list = []
        self.fail = fail

    def emit(
        self,
        db,
        event_type: str,
        severity: str = "info",
        user_id: Optional[int] = None,
        detail: Optional[str] = None,
        meta: Optional[dict] = None,
    ) -> None:
        if self.fail:
            raise RuntimeError("event sink unavailable")
        self.events.append(
            {
                "event_type": event_type,
                "severity": severity,
                "user_id": user_id,
                "detail": detail,
                "meta": meta,
            }
        )


class _FakeBlocklist:
    """Edge blocklist double that records blocked IPs."""

    def __init__(self, fail: bool = False) -> None:
        self.blocked: list = []
        self.fail = fail

    def block_ip(self, ip: str) -> None:
        if self.fail:
            raise RuntimeError("blocklist unavailable")
        self.blocked.append(ip)


class _FakeCapabilities:
    """Minimal capabilities stand-in for the honeypot router."""

    def __init__(self, sink: _RecordingSink, blocklist: _FakeBlocklist) -> None:
        self.event_sink = sink
        self.edge_blocklist = blocklist


def _db_session():
    """In-memory SQLite session carrying the honeytokens table."""
    # StaticPool + check_same_thread=False so the TestClient's worker
    # thread shares the same in-memory database as the test thread.
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    table = Honeytoken.__table__
    # SQLite only autoincrements INTEGER PRIMARY KEY (rowid alias);
    # production MySQL is unaffected by the temporary retype.
    original = table.c.id.type
    table.c.id.type = Integer()
    table.create(engine)
    table.c.id.type = original
    factory = sessionmaker(bind=engine)
    return factory(), engine


def _request(path: str = "/api/v1/messages", client_ip: str = "203.0.113.7") -> Request:
    """Build a request with a realistic scope for direct dependency calls."""
    return Request(
        {
            "type": "http",
            "http_version": "1.1",
            "method": "GET",
            "scheme": "http",
            "server": ("testserver", 80),
            "path": path,
            "query_string": b"",
            "headers": [(b"authorization", b"Bearer decoy")],
            "client": (client_ip, 12345),
        }
    )


@pytest.fixture()
def db_session():
    session, engine = _db_session()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture()
def decoy_app(monkeypatch, db_session):
    """Minimal app serving the real honeypot router against a fake.

    The decoy delay is neutralised so the suite stays fast, and the
    security capabilities singleton is replaced by recording doubles.
    """
    sink = _RecordingSink()
    blocklist = _FakeBlocklist()
    monkeypatch.setattr(honeypot_module, "_DECOY_DELAY_SECONDS", 0)
    monkeypatch.setattr(
        honeypot_module,
        "get_security_capabilities",
        lambda: _FakeCapabilities(sink, blocklist),
    )
    app = FastAPI()
    app.include_router(honeypot_router)
    app.dependency_overrides[get_db] = lambda: db_session
    client = TestClient(app)
    return client, sink, blocklist


class TestHashToken:
    """Token hashing is deterministic and unsalted."""

    def test_stable_sha256_hex(self):
        digest = hash_token("decoy-token")
        assert digest == hashlib.sha256(b"decoy-token").hexdigest()
        assert len(digest) == 64


class TestHoneytokenService:
    """Plant, look up, account for and revoke decoy credentials."""

    def test_plant_stores_only_the_hash(self, db_session):
        plaintext = honeytoken_service.plant(
            db_session, token_type="admin_session", label="decoy-1"
        )
        row = db_session.query(Honeytoken).one()
        assert row.token_hash == hash_token(plaintext)
        assert row.token_type == "admin_session"
        assert row.label == "decoy-1"
        assert row.active is True
        assert row.hit_count == 0
        # The plaintext must never be persisted in any column.
        assert plaintext not in {row.token_hash, row.label or ""}

    def test_plant_rejects_unknown_type(self, db_session):
        with pytest.raises(ValueError):
            honeytoken_service.plant(db_session, token_type="master_key")

    def test_plant_accepts_every_documented_type(self, db_session):
        for token_type in TOKEN_TYPES:
            plaintext = honeytoken_service.plant(db_session, token_type=token_type)
            assert honeytoken_service.lookup(db_session, plaintext) is not None
        assert db_session.query(Honeytoken).count() == len(TOKEN_TYPES)

    def test_lookup_matches_only_active_tokens(self, db_session):
        plaintext = honeytoken_service.plant(db_session, token_type="api_key")
        assert honeytoken_service.lookup(db_session, plaintext) is not None
        assert honeytoken_service.lookup(db_session, "wrong-token") is None
        assert honeytoken_service.lookup(db_session, "") is None

        token = honeytoken_service.lookup(db_session, plaintext)
        assert honeytoken_service.revoke(db_session, token.id) is True
        assert honeytoken_service.lookup(db_session, plaintext) is None

    def test_revoke_unknown_id_returns_false(self, db_session):
        assert honeytoken_service.revoke(db_session, 999) is False

    def test_register_hit_accounts_every_presentation(self, db_session):
        plaintext = honeytoken_service.plant(db_session, token_type="reset_link")
        token = honeytoken_service.lookup(db_session, plaintext)
        honeytoken_service.register_hit(db_session, token, "198.51.100.9")
        honeytoken_service.register_hit(db_session, token, "198.51.100.9")
        refreshed = honeytoken_service.lookup(db_session, plaintext)
        assert refreshed.hit_count == 2
        assert refreshed.last_hit_at is not None
        assert refreshed.last_hit_ip_hash == hash_ip("198.51.100.9")

    def test_register_hit_never_raises_on_failure(self, db_session, monkeypatch):
        plaintext = honeytoken_service.plant(db_session, token_type="api_key")
        token = honeytoken_service.lookup(db_session, plaintext)

        def _boom():
            raise RuntimeError("db down")

        monkeypatch.setattr(db_session, "commit", _boom)
        # Must swallow the failure: authentication cannot break here.
        honeytoken_service.register_hit(db_session, token, "203.0.113.7")

    def test_list_active_returns_newest_first(self, db_session):
        honeytoken_service.plant(db_session, token_type="api_key", label="old")
        honeytoken_service.plant(db_session, token_type="api_key", label="new")
        tokens = honeytoken_service.list_active(db_session)
        assert [t.label for t in tokens] == ["new", "old"]

    def test_service_singleton_is_reused(self):
        assert isinstance(honeytoken_service, HoneytokenService)


class TestDecoyEndpointsDisabled:
    """A disabled honeypot is indistinguishable from undeployed routes."""

    def test_all_decoys_answer_404(self, decoy_app, settings):
        client, sink, blocklist = decoy_app
        settings.security_honeypot_enabled = False
        paths = [
            ("get", "/admin"),
            ("post", "/admin/login"),
            ("get", "/api/admin"),
            ("get", "/internal/metrics"),
            ("get", "/actuator/env"),
            ("get", "/manage"),
        ]
        for method, path in paths:
            response = getattr(client, method)(path)
            assert response.status_code == 404, f"{method} {path}"
        assert sink.events == []
        assert blocklist.blocked == []


class TestDecoyEndpointsEnabled:
    """Enabled decoys answer like the genuine article and report hits."""

    def test_decoy_surfaces(self, decoy_app, settings):
        client, _, _ = decoy_app
        settings.security_honeypot_enabled = True

        response = client.get("/admin")
        assert response.status_code == 200
        assert "<form" in response.text
        assert "Porten Admin" in response.text

        response = client.post("/admin/login")
        assert response.status_code == 401
        assert response.json()["detail"] == "Invalid username or password"

        response = client.get("/api/admin")
        assert response.status_code == 401
        assert response.json()["detail"] == "admin token required"

        response = client.get("/internal/metrics")
        assert response.status_code == 200
        body = response.json()
        assert body["uptime_seconds"] > 0
        assert 0 < body["error_rate"] < 1

        response = client.get("/actuator/env")
        assert response.status_code == 200
        assert response.json()["activeProfiles"] == ["prod"]

        response = client.get("/manage", follow_redirects=False)
        assert response.status_code == 302

    def test_hit_emits_high_severity_event(self, decoy_app, settings):
        client, sink, _ = decoy_app
        settings.security_honeypot_enabled = True
        client.get("/internal/metrics")
        assert len(sink.events) == 1
        event = sink.events[0]
        assert event["event_type"] == "honeypot_endpoint_hit"
        assert event["severity"] == "high"
        assert event["detail"] == "GET /internal/metrics"

    def test_autoblock_blocks_the_probing_ip(self, decoy_app, settings):
        client, _, blocklist = decoy_app
        settings.security_honeypot_enabled = True
        settings.security_honeypot_autoblock = True
        client.get("/admin")
        assert blocklist.blocked == ["testclient"]

    def test_autoblock_disabled_leaves_ip_alone(self, decoy_app, settings):
        client, _, blocklist = decoy_app
        settings.security_honeypot_enabled = True
        settings.security_honeypot_autoblock = False
        client.get("/admin")
        assert blocklist.blocked == []

    def test_autoblock_failure_never_breaks_decoy(self, decoy_app, settings):
        client, _, blocklist = decoy_app
        settings.security_honeypot_enabled = True
        blocklist.fail = True
        response = client.get("/admin")
        assert response.status_code == 200

    def test_event_sink_failure_never_breaks_decoy(self, decoy_app, settings):
        client, sink, _ = decoy_app
        settings.security_honeypot_enabled = True
        sink.fail = True
        response = client.get("/admin")
        assert response.status_code == 200

    def test_honeytoken_at_decoy_raises_critical(
        self, decoy_app, settings, db_session
    ):
        client, sink, blocklist = decoy_app
        settings.security_honeypot_enabled = True
        settings.security_honeypot_autoblock = True
        plaintext = honeytoken_service.plant(
            db_session, token_type="admin_session", label="decoy-admin"
        )
        response = client.get(
            "/admin", headers={"Authorization": f"Bearer {plaintext}"}
        )
        assert response.status_code == 200
        critical = [e for e in sink.events if e["severity"] == "critical"]
        assert len(critical) == 1
        assert critical[0]["event_type"] == "honeypot_honeytoken_presented"
        token = honeytoken_service.lookup(db_session, plaintext)
        assert token.hit_count == 1
        assert token.last_hit_ip_hash == hash_ip("testclient")
        assert blocklist.blocked == ["testclient"]

    def test_unknown_bearer_token_is_not_flagged(
        self, decoy_app, settings, db_session
    ):
        client, sink, _ = decoy_app
        settings.security_honeypot_enabled = True
        client.get("/admin", headers={"Authorization": "Bearer not-a-honeytoken"})
        assert [e for e in sink.events if e["severity"] == "critical"] == []


class TestAuthPathHoneytoken:
    """Planted credentials presented to the auth path prove compromise."""

    def test_planted_token_flags_critical(self, db_session, monkeypatch):
        sink = _RecordingSink()
        blocklist = _FakeBlocklist()
        monkeypatch.setattr(
            auth_module,
            "get_security_capabilities",
            lambda: _FakeCapabilities(sink, blocklist),
        )
        settings = get_settings()
        settings.security_honeypot_enabled = True
        settings.security_honeypot_autoblock = True
        plaintext = honeytoken_service.plant(db_session, token_type="api_key")

        auth_module._check_honeytoken(db_session, _request(), plaintext)

        assert len(sink.events) == 1
        assert sink.events[0]["event_type"] == "honeypot_honeytoken_presented"
        assert sink.events[0]["severity"] == "critical"
        assert sink.events[0]["detail"] == "GET /api/v1/messages"
        token = honeytoken_service.lookup(db_session, plaintext)
        assert token.hit_count == 1
        assert token.last_hit_ip_hash == hash_ip("203.0.113.7")
        assert blocklist.blocked == ["203.0.113.7"]

    def test_unknown_token_is_silent(self, db_session, monkeypatch):
        sink = _RecordingSink()
        blocklist = _FakeBlocklist()
        monkeypatch.setattr(
            auth_module,
            "get_security_capabilities",
            lambda: _FakeCapabilities(sink, blocklist),
        )
        settings = get_settings()
        settings.security_honeypot_enabled = True
        auth_module._check_honeytoken(db_session, _request(), "genuine-but-invalid")
        assert sink.events == []
        assert blocklist.blocked == []

    def test_disabled_honeypot_skips_the_check(self, db_session, monkeypatch):
        sink = _RecordingSink()
        blocklist = _FakeBlocklist()
        monkeypatch.setattr(
            auth_module,
            "get_security_capabilities",
            lambda: _FakeCapabilities(sink, blocklist),
        )
        settings = get_settings()
        settings.security_honeypot_enabled = False
        plaintext = honeytoken_service.plant(db_session, token_type="api_key")
        auth_module._check_honeytoken(db_session, _request(), plaintext)
        assert sink.events == []
        token = honeytoken_service.lookup(db_session, plaintext)
        assert token.hit_count == 0

    def test_check_never_raises(self, db_session, monkeypatch):
        sink = _RecordingSink(fail=True)
        blocklist = _FakeBlocklist(fail=True)
        monkeypatch.setattr(
            auth_module,
            "get_security_capabilities",
            lambda: _FakeCapabilities(sink, blocklist),
        )
        settings = get_settings()
        settings.security_honeypot_enabled = True
        settings.security_honeypot_autoblock = True
        plaintext = honeytoken_service.plant(db_session, token_type="api_key")
        # Both the hit accounting sink and the blocklist fail; the
        # authentication path must stay unaffected.
        auth_module._check_honeytoken(db_session, _request(), plaintext)


# ---------------------------------------------------------------------------
# SIEM export
# ---------------------------------------------------------------------------


def _stream_id_key(entry_id: str) -> tuple:
    """Sortable (ms, seq) tuple for a stream entry id ("0" sorts first)."""
    if entry_id == "0":
        return (0, 0)
    ms, _, seq = entry_id.partition("-")
    return (int(ms), int(seq))


class _FakeStreamRedis:
    """In-memory stand-in for the Redis Stream subset the exporter uses."""

    def __init__(self) -> None:
        self._entries: dict = {}
        self._groups: dict = {}
        self._seq = 0
        self.fail = False

    def _check(self) -> None:
        if self.fail:
            raise redis.RedisError("fake redis unavailable")

    def xadd(self, key, fields, maxlen=None, approximate=False):
        self._check()
        self._seq += 1
        entry_id = f"{int(time.time() * 1000)}-{self._seq}"
        self._entries.setdefault(key, []).append((entry_id, dict(fields)))
        return entry_id

    def xgroup_create(self, key, group, id="0", mkstream=False):
        self._check()
        if mkstream:
            self._entries.setdefault(key, [])
        if (key, group) in self._groups:
            raise redis.exceptions.ResponseError(
                "BUSYGROUP Consumer Group name already exists"
            )
        self._groups[(key, group)] = {"last": id, "pending": {}}
        return True

    def xreadgroup(self, group, consumer, streams, count=None):
        self._check()
        (key, stream_id), = streams.items()
        state = self._groups[(key, group)]
        if stream_id == "0":
            # Replay this consumer's pending entries (no state change).
            pending = state["pending"].setdefault(consumer, {})
            return [(key, list(pending.items()))]
        fresh = [
            (eid, fields)
            for eid, fields in self._entries.get(key, [])
            if _stream_id_key(eid) > _stream_id_key(state["last"])
        ]
        if count:
            fresh = fresh[:count]
        for eid, fields in fresh:
            state["last"] = eid
            state["pending"].setdefault(consumer, {})[eid] = fields
        return [(key, fresh)]

    def xack(self, key, group, *ids):
        self._check()
        state = self._groups.get((key, group))
        if state is None:
            return 0
        acked = 0
        for entry_id in ids:
            for pending in state["pending"].values():
                if entry_id in pending:
                    del pending[entry_id]
                    acked += 1
        return acked

    def xpending_range(self, key, group, min="-", max="+", count=None):
        self._check()
        state = self._groups.get((key, group))
        if state is None:
            return []
        pending = [
            {"entry_id": eid, "consumer": consumer}
            for consumer, entries in state["pending"].items()
            for eid in entries
        ]
        return pending[:count] if count else pending


class _StubHttpClient:
    """HTTP client double recording posted batches."""

    def __init__(self, status_code: int = 200) -> None:
        self.status_code = status_code
        self.posts: list = []
        self.fail = False

    def post(self, url, json=None):
        if self.fail:
            raise httpx.HTTPError("stub network error")
        self.posts.append((url, json))
        return _StubResponse(self.status_code)


class _StubResponse:
    def __init__(self, status_code: int) -> None:
        self.status_code = status_code


def _seed_event(client: _FakeStreamRedis, key: str, event_type: str) -> str:
    """Append one encoded event to the stream like the real sink does."""
    return client.xadd(
        key,
        {
            "type": event_type,
            "severity": "high",
            "user_id": "",
            "detail": f"{event_type} detail",
            "payload": json.dumps(
                {"severity": "high", "user_id": None, "detail": "payload detail"}
            ),
        },
    )


def _exporter(client: _FakeStreamRedis, http: _StubHttpClient, **kwargs) -> SiemExporter:
    kwargs.setdefault("stream_key", "porten:security:events")
    kwargs.setdefault("group", "siem-export")
    kwargs.setdefault("webhook_url", "https://siem.example.com/hook")
    return SiemExporter(client, http_client=http, **kwargs)


class TestDecodeEntry:
    """Stream entries decode into JSON-safe event dicts."""

    def test_payload_json_is_merged(self):
        event = _decode_entry(
            "1-1",
            {
                "type": "waf_block",
                "payload": json.dumps({"severity": "high", "detail": "blocked"}),
            },
        )
        assert event == {
            "id": "1-1",
            "type": "waf_block",
            "severity": "high",
            "detail": "blocked",
        }

    def test_malformed_payload_is_tolerated(self):
        event = _decode_entry("1-2", {"type": "waf_block", "payload": "not-json"})
        assert event == {"id": "1-2", "type": "waf_block"}

    def test_plain_fields_pass_through(self):
        event = _decode_entry("1-3", {"type": "login_failed", "severity": "info"})
        assert event == {
            "id": "1-3",
            "type": "login_failed",
            "severity": "info",
        }


class TestSiemExporter:
    """At-least-once delivery with pending retry and failure isolation."""

    def test_fresh_entries_are_delivered_and_acked(self):
        client = _FakeStreamRedis()
        http = _StubHttpClient()
        key = "porten:security:events"
        _seed_event(client, key, "waf_block")
        _seed_event(client, key, "login_failed")

        exporter = _exporter(client, http)
        assert exporter.export_once() == 2

        assert len(http.posts) == 1
        url, payload = http.posts[0]
        assert url == "https://siem.example.com/hook"
        assert payload["source"] == "porten-security"
        assert [e["type"] for e in payload["events"]] == [
            "waf_block",
            "login_failed",
        ]
        # Payload fields override the flattened stream copies.
        assert payload["events"][0]["detail"] == "payload detail"
        # Accepted entries are acknowledged: nothing stays pending.
        assert exporter.pending_count() == 0

    def test_rejected_batch_stays_pending_and_is_retried(self):
        client = _FakeStreamRedis()
        http = _StubHttpClient(status_code=500)
        key = "porten:security:events"
        _seed_event(client, key, "waf_block")

        exporter = _exporter(client, http)
        assert exporter.export_once() == 0
        assert exporter.pending_count() == 1

        # Webhook recovers: the still-pending entry is re-delivered.
        http.status_code = 200
        assert exporter.export_once() == 1
        assert len(http.posts) == 2
        assert exporter.pending_count() == 0

    def test_network_error_stays_pending(self):
        client = _FakeStreamRedis()
        http = _StubHttpClient()
        http.fail = True
        _seed_event(client, "porten:security:events", "waf_block")

        exporter = _exporter(client, http)
        assert exporter.export_once() == 0
        assert exporter.pending_count() == 1

        http.fail = False
        assert exporter.export_once() == 1
        assert exporter.pending_count() == 0

    def test_redis_failure_round_returns_zero(self):
        client = _FakeStreamRedis()
        http = _StubHttpClient()
        exporter = _exporter(client, http)
        client.fail = True
        assert exporter.export_once() == 0
        assert exporter.pending_count() == 0
        assert http.posts == []

    def test_busygroup_is_tolerated(self):
        client = _FakeStreamRedis()
        http = _StubHttpClient()
        key = "porten:security:events"
        _seed_event(client, key, "waf_block")
        # Simulate a group created by a previous process.
        client.xgroup_create(key, "siem-export", id="0")

        exporter = _exporter(client, http)
        assert exporter.export_once() == 1

    def test_batch_size_limits_one_round(self):
        client = _FakeStreamRedis()
        http = _StubHttpClient()
        key = "porten:security:events"
        for index in range(5):
            _seed_event(client, key, f"event_{index}")

        exporter = _exporter(client, http, batch_size=2)
        assert exporter.export_once() == 2
        assert exporter.pending_count() == 0
        # The remaining entries are picked up by the next round.
        assert exporter.export_once() == 2
        assert exporter.export_once() == 1
        assert len(http.posts) == 3


class TestSiemExportTask:
    """The background loop survives iteration failures."""

    def test_loop_runs_iterations_and_survives_errors(self):
        calls = []

        class _Stub:
            def export_once(self):
                calls.append(1)
                if len(calls) == 1:
                    raise RuntimeError("boom")
                return 1

        async def _run():
            task = asyncio.create_task(
                siem_export_task(_Stub(), interval_seconds=0.01)
            )
            await asyncio.sleep(0.08)
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass

        asyncio.run(_run())
        assert len(calls) >= 2


class TestBuildSiemExporter:
    """Assembly is config-gated and Redis-aware."""

    def test_returns_none_when_disabled(self, settings):
        settings.security_siem_enabled = False
        assert build_siem_exporter() is None

    def test_returns_none_without_webhook_url(self, settings):
        settings.security_siem_enabled = True
        settings.security_siem_webhook_url = ""
        assert build_siem_exporter() is None

    def test_returns_none_when_redis_unreachable(self, settings, monkeypatch):
        settings.security_siem_enabled = True
        settings.security_siem_webhook_url = "https://siem.example.com/hook"
        monkeypatch.setattr(
            "app.services.siem_export_service.create_redis_client", lambda: None
        )
        assert build_siem_exporter() is None

    def test_returns_exporter_when_configured(self, settings, monkeypatch):
        settings.security_siem_enabled = True
        settings.security_siem_webhook_url = "https://siem.example.com/hook"
        settings.security_siem_batch_size = 50
        settings.security_siem_consumer_group = "siem-export"
        monkeypatch.setattr(
            "app.services.siem_export_service.create_redis_client",
            lambda: _FakeStreamRedis(),
        )
        exporter = build_siem_exporter()
        assert exporter is not None
        assert exporter._webhook_url == "https://siem.example.com/hook"
        assert exporter._batch_size == 50
        assert exporter._group == "siem-export"
        assert exporter._stream_key == settings.security_event_stream_key

"""Tests for the SSRF-hardened URL fetch sandbox and the external
threat-intelligence feed (design doc §5.5).

Fetch mechanics are exercised against a real loopback HTTP server with
a permissive policy (``blocked_networks=()``); SSRF refusals are tested
under the default strict policy. The remote sandbox and the feed use
injected stub clients, and the feed database assertions run against
in-memory SQLite.
"""

import asyncio
import base64
import ipaddress
import json
import socket
import threading
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import httpx
import pytest
import redis
from sqlalchemy import Integer, create_engine
from sqlalchemy.orm import sessionmaker

from app.config import get_settings
from app.models import UrlReputation
from app.schemas.security import UrlVerdictLevel
from app.services.threat_intel_feed_service import (
    ThreatIntelFeedService,
    build_threat_intel_feed_service,
    threat_intel_feed_task,
)
from app.services.threat_intel_service import ThreatIntelService
from app.services.url_fetch_sandbox_service import (
    DisabledSandbox,
    LocalIsolationSandbox,
    RemoteSandboxClient,
    SsrfPolicy,
)


@pytest.fixture(autouse=True)
def _restore_settings():
    """Snapshot the settings keys touched by this module."""
    settings = get_settings()
    keys = (
        "security_profile",
        "security_url_fetch_enabled",
        "security_url_fetch_timeout_seconds",
        "security_url_fetch_max_bytes",
        "security_url_fetch_max_redirects",
        "security_sandbox_url",
        "security_threat_feed_url",
        "security_threat_feed_interval_seconds",
        "security_threat_feed_ttl_seconds",
    )
    snapshot = {key: getattr(settings, key) for key in keys}
    yield
    for key, value in snapshot.items():
        setattr(settings, key, value)


# ---------------------------------------------------------------------------
# Test doubles
# ---------------------------------------------------------------------------


class _FakeRedis:
    """In-memory stand-in for the Redis subset ThreatIntelService uses."""

    def __init__(self) -> None:
        self._strings: dict = {}
        self.fail = False

    def _check(self) -> None:
        if self.fail:
            raise redis.RedisError("fake redis unavailable")

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


class _LoopbackHandler(BaseHTTPRequestHandler):
    """Fixed routes for fetch-mechanics tests.

    ``last_host`` records the Host header of the most recent request so
    IP-pinning behaviour can be asserted.
    """

    last_host: str = ""

    def log_message(self, *args):  # silence request logging
        pass

    def do_GET(self):
        _LoopbackHandler.last_host = self.headers.get("Host", "")
        if self.path == "/redirect":
            self._redirect("/final")
        elif self.path == "/redirect-private":
            self._redirect("http://192.168.0.1/secret")
        elif self.path == "/loop":
            self._redirect("/loop")
        elif self.path == "/final":
            self._body(b"final content", "text/plain")
        elif self.path == "/big":
            self._body(b"x" * 5000, "text/plain")
        elif self.path == "/slow":
            import time

            time.sleep(0.5)
            self._body(b"slow", "text/plain")
        else:
            self._body(b"hello sandbox", "text/plain")

    def _redirect(self, location: str) -> None:
        self.send_response(302)
        self.send_header("Location", location)
        self.end_headers()

    def _body(self, body: bytes, content_type: str) -> None:
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


@pytest.fixture()
def local_server():
    """Threading HTTP server on loopback; yields its base URL."""
    server = ThreadingHTTPServer(("127.0.0.1", 0), _LoopbackHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield f"http://127.0.0.1:{server.server_address[1]}"
    server.shutdown()
    server.server_close()
    thread.join(timeout=5)


def _permissive_policy(**kwargs) -> SsrfPolicy:
    """Policy that allows loopback so the local test server is reachable."""
    kwargs.setdefault("max_bytes", 524288)
    kwargs.setdefault("timeout_seconds", 5.0)
    return SsrfPolicy(blocked_networks=(), **kwargs)


@pytest.fixture()
def settings():
    return get_settings()


@pytest.fixture()
def db_session():
    """In-memory SQLite with the url_reputations table."""
    engine = create_engine("sqlite://")
    table = UrlReputation.__table__
    # SQLite only autoincrements INTEGER PRIMARY KEY (rowid alias);
    # production MySQL is unaffected by the temporary retype.
    original = table.c.id.type
    table.c.id.type = Integer()
    table.create(engine)
    table.c.id.type = original
    factory = sessionmaker(bind=engine)
    session = factory()
    yield session, engine
    session.close()
    engine.dispose()


def _intel_service(session, redis_client=None) -> ThreatIntelService:
    return ThreatIntelService(
        redis_client or _FakeRedis(), session_factory=lambda: session
    )


class _StubResponse:
    """Minimal httpx.Response stand-in for the feed client."""

    def __init__(self, text: str = "", status_code: int = 200) -> None:
        self.text = text
        self.status_code = status_code

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise httpx.HTTPStatusError(
                "stub error", request=None, response=None
            )


class _StubClient:
    """Feed HTTP client returning a fixed payload or raising."""

    def __init__(
        self, text: str = "", exc: Exception = None, status_code: int = 200
    ) -> None:
        self._text = text
        self._exc = exc
        self._status_code = status_code
        self.calls: list = []

    def get(self, url: str) -> _StubResponse:
        self.calls.append(url)
        if self._exc is not None:
            raise self._exc
        return _StubResponse(self._text, status_code=self._status_code)


def _feed_service(session, client: _StubClient, **kwargs) -> ThreatIntelFeedService:
    kwargs.setdefault("feed_url", "http://feed.test/list")
    kwargs.setdefault("ttl_seconds", 604800)
    return ThreatIntelFeedService(
        _intel_service(session),
        session_factory=lambda: session,
        client=client,
        **kwargs,
    )


# ---------------------------------------------------------------------------
# SsrfPolicy
# ---------------------------------------------------------------------------


class TestSsrfPolicy:
    """Policy defaults deny everything non-public and are injectable."""

    def test_default_policy_blocks_internal_ranges(self):
        policy = SsrfPolicy()
        for value in (
            "127.0.0.1",
            "10.1.2.3",
            "172.16.0.1",
            "192.168.1.1",
            "169.254.169.254",  # cloud metadata
            "100.64.0.1",  # CGNAT
            "0.0.0.0",
            "::1",
            "fc00::1",
            "fe80::1",
            "64:ff9b::1",  # NAT64
        ):
            assert policy.is_blocked_ip(ipaddress.ip_address(value)), value

    def test_default_policy_allows_public_addresses(self):
        policy = SsrfPolicy()
        for value in ("8.8.8.8", "1.1.1.1", "2606:4700::1111"):
            assert not policy.is_blocked_ip(ipaddress.ip_address(value)), value

    def test_empty_policy_allows_everything(self):
        policy = SsrfPolicy(blocked_networks=())
        assert not policy.is_blocked_ip(ipaddress.ip_address("127.0.0.1"))

    def test_ipv4_mapped_ipv6_validates_embedded_address(self):
        # Custom policy that only blocks 10/8: the mapped embedding of a
        # 10.x address must still be refused via the embedded address.
        policy = SsrfPolicy(
            blocked_networks=(ipaddress.ip_network("10.0.0.0/8"),)
        )
        assert policy.is_blocked_ip(ipaddress.ip_address("::ffff:10.0.0.1"))
        assert not policy.is_blocked_ip(ipaddress.ip_address("::ffff:8.8.8.8"))

    def test_scheme_allowlist_default(self):
        policy = SsrfPolicy()
        assert policy.allowed_schemes == frozenset({"http", "https"})


# ---------------------------------------------------------------------------
# LocalIsolationSandbox: fetch mechanics
# ---------------------------------------------------------------------------


class TestLocalIsolationSandboxFetch:
    """Fetch mechanics against a real loopback server."""

    def test_basic_fetch(self, local_server):
        sandbox = LocalIsolationSandbox(_permissive_policy())
        result = sandbox.fetch(f"{local_server}/")
        assert result.ok
        assert result.status_code == 200
        assert result.body == b"hello sandbox"
        assert result.content_type.startswith("text/plain")
        assert result.final_url == f"{local_server}/"
        assert not result.truncated
        assert result.error is None

    def test_redirect_followed_to_final_target(self, local_server):
        sandbox = LocalIsolationSandbox(_permissive_policy())
        result = sandbox.fetch(f"{local_server}/redirect")
        assert result.ok
        assert result.body == b"final content"
        assert result.final_url == f"{local_server}/final"

    def test_response_size_cap_truncates(self, local_server):
        sandbox = LocalIsolationSandbox(_permissive_policy(max_bytes=1000))
        result = sandbox.fetch(f"{local_server}/big")
        assert result.ok
        assert result.truncated
        assert len(result.body) == 1000

    def test_dangerous_scheme_rejected(self, local_server):
        sandbox = LocalIsolationSandbox(_permissive_policy())
        result = sandbox.fetch("file:///etc/passwd")
        assert not result.ok
        assert result.error.startswith("blocked_scheme")

    def test_missing_host_rejected(self):
        sandbox = LocalIsolationSandbox(_permissive_policy())
        result = sandbox.fetch("http://")
        assert not result.ok
        assert result.error == "missing_host"

    def test_connection_failure_reported_not_raised(self):
        sandbox = LocalIsolationSandbox(_permissive_policy(timeout_seconds=1.0))
        result = sandbox.fetch("http://127.0.0.1:1/")
        assert not result.ok
        assert result.error == "fetch_failed"

    def test_read_timeout_enforced(self, local_server):
        sandbox = LocalIsolationSandbox(_permissive_policy(timeout_seconds=0.1))
        result = sandbox.fetch(f"{local_server}/slow")
        assert not result.ok
        assert result.error == "fetch_failed"

    def test_hostname_travels_in_host_header_while_ip_is_pinned(
        self, local_server, monkeypatch
    ):
        # The hostname is resolved once to a validated address; the TCP
        # connection targets that pinned address while the original
        # hostname is what the server sees in the Host header.
        port = int(local_server.rsplit(":", 1)[1])
        monkeypatch.setattr(
            socket,
            "getaddrinfo",
            lambda host, prt, *a, **kw: [
                (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", prt))
            ],
        )
        sandbox = LocalIsolationSandbox(_permissive_policy())
        result = sandbox.fetch(f"http://pinned.example.test:{port}/")
        assert result.ok
        assert result.body == b"hello sandbox"
        assert _LoopbackHandler.last_host == f"pinned.example.test:{port}"


# ---------------------------------------------------------------------------
# LocalIsolationSandbox: SSRF refusals (default strict policy)
# ---------------------------------------------------------------------------


class TestLocalIsolationSandboxSsrf:
    """The default policy refuses internal targets before connecting."""

    def test_loopback_blocked(self, local_server):
        sandbox = LocalIsolationSandbox()  # default strict policy
        result = sandbox.fetch(f"{local_server}/")
        assert not result.ok
        assert result.error.startswith("ssrf_blocked: 127.0.0.1")

    def test_cloud_metadata_blocked(self):
        sandbox = LocalIsolationSandbox()
        result = sandbox.fetch("http://169.254.169.254/latest/meta-data/")
        assert not result.ok
        assert result.error.startswith("ssrf_blocked: 169.254.169.254")

    def test_private_ranges_blocked(self):
        sandbox = LocalIsolationSandbox()
        for url in (
            "http://10.0.0.1/",
            "http://192.168.1.1/",
            "http://[::1]:8080/",
            "http://100.64.0.1/",
        ):
            result = sandbox.fetch(url)
            assert not result.ok, url
            assert result.error.startswith("ssrf_blocked"), url

    def test_localhost_name_blocked_via_resolution(self):
        sandbox = LocalIsolationSandbox()
        result = sandbox.fetch("http://localhost/")
        assert not result.ok
        assert result.error.startswith("ssrf_blocked")

    def test_redirect_to_private_target_revalidated(self, local_server):
        # Only 192.168.0.0/16 is blocked: the initial loopback hop is
        # allowed, the redirect target is not.
        policy = SsrfPolicy(
            blocked_networks=(ipaddress.ip_network("192.168.0.0/16"),),
            timeout_seconds=5.0,
        )
        sandbox = LocalIsolationSandbox(policy)
        result = sandbox.fetch(f"{local_server}/redirect-private")
        assert not result.ok
        assert result.error.startswith("ssrf_blocked: 192.168.0.1")

    def test_redirects_disallowed_by_policy(self, local_server):
        sandbox = LocalIsolationSandbox(
            _permissive_policy(allow_redirects=False)
        )
        result = sandbox.fetch(f"{local_server}/redirect")
        assert not result.ok
        assert result.error == "redirect_not_allowed"

    def test_too_many_redirects_capped(self, local_server):
        sandbox = LocalIsolationSandbox(
            _permissive_policy(max_redirects=1)
        )
        result = sandbox.fetch(f"{local_server}/loop")
        assert not result.ok
        assert result.error == "too_many_redirects"

    def test_dns_failure_reported(self):
        sandbox = LocalIsolationSandbox()  # strict; blocked pre-resolution
        result = sandbox.fetch("http://this-host-does-not-exist.invalid/")
        assert not result.ok
        assert result.error.startswith(("dns_failed", "ssrf_blocked"))


# ---------------------------------------------------------------------------
# RemoteSandboxClient
# ---------------------------------------------------------------------------


class TestRemoteSandboxClient:
    """The cluster sandbox client degrades to sandbox_unavailable."""

    def _client(self, handler, settings) -> RemoteSandboxClient:
        settings.security_sandbox_url = "http://sandbox.internal"
        return RemoteSandboxClient(
            client=httpx.Client(transport=httpx.MockTransport(handler))
        )

    def test_successful_fetch_parsed(self, settings):
        body = base64.b64encode(b"remote content").decode()

        def handler(request: httpx.Request) -> httpx.Response:
            assert request.url.path == "/fetch"
            return httpx.Response(
                200,
                json={
                    "ok": True,
                    "final_url": "http://example.test/",
                    "status_code": 200,
                    "content_type": "text/html",
                    "body": body,
                    "truncated": False,
                },
            )

        result = self._client(handler, settings).fetch("http://example.test/")
        assert result.ok
        assert result.body == b"remote content"
        assert result.final_url == "http://example.test/"
        assert result.content_type == "text/html"

    def test_non_200_reports_unavailable(self, settings):
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(500, json={"error": "boom"})

        result = self._client(handler, settings).fetch("http://example.test/")
        assert not result.ok
        assert result.error == "sandbox_unavailable"

    def test_transport_error_reports_unavailable(self, settings):
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("sandbox down")

        result = self._client(handler, settings).fetch("http://example.test/")
        assert not result.ok
        assert result.error == "sandbox_unavailable"

    def test_malformed_payload_reports_unavailable(self, settings):
        def handler(request: httpx.Request) -> httpx.Response:
            return httpx.Response(200, text="not json")

        result = self._client(handler, settings).fetch("http://example.test/")
        assert not result.ok
        assert result.error == "sandbox_unavailable"


class TestDisabledSandbox:
    """Profiles without the capability fail open."""

    def test_reports_disabled(self):
        result = DisabledSandbox().fetch("http://example.test/")
        assert not result.ok
        assert result.error == "sandbox_disabled"


# ---------------------------------------------------------------------------
# ThreatIntelFeedService: parsing and ingestion
# ---------------------------------------------------------------------------


class TestThreatIntelFeedParsing:
    """Both feed formats parse; malformed entries are skipped."""

    def test_line_format_with_tabs(self, db_session):
        session, _ = db_session
        client = _StubClient(
            "evil.com\tmalicious\n"
            "bad.example\tsuspicious\tphishing\n"
        )
        applied = _feed_service(session, client).ingest_once()
        assert applied == 2
        rows = {row.host: row for row in session.query(UrlReputation).all()}
        assert rows["evil.com"].level == "malicious"
        assert rows["bad.example"].level == "suspicious"
        assert rows["bad.example"].reason == "phishing"
        assert rows["bad.example"].source == "feed"

    def test_line_format_with_comments_and_blanks(self, db_session):
        session, _ = db_session
        client = _StubClient(
            "# threat feed v1\n"
            "\n"
            "evil.com,malicious,phishing\n"
            "\n"
        )
        applied = _feed_service(session, client).ingest_once()
        assert applied == 1

    def test_json_array_format(self, db_session):
        session, _ = db_session
        payload = json.dumps(
            [
                {"host": "a.example", "level": "malicious", "reason": "phishing"},
                {"host": "b.example", "level": "safe"},
            ]
        )
        applied = _feed_service(session, _StubClient(payload)).ingest_once()
        assert applied == 2

    def test_json_lines_format(self, db_session):
        session, _ = db_session
        payload = (
            '{"host": "a.example", "level": "malicious"}\n'
            '{"host": "b.example", "level": "suspicious", "reason": "scam"}\n'
        )
        applied = _feed_service(session, _StubClient(payload)).ingest_once()
        assert applied == 2

    def test_invalid_entries_skipped(self, db_session):
        session, _ = db_session
        client = _StubClient(
            "evil.com,bogus-level\n"
            "\n"
            "bad host,malicious\n"
            "user@evil.com,malicious\n"
            "malware.example,malicious\n"
        )
        applied = _feed_service(session, client).ingest_once()
        assert applied == 1
        rows = session.query(UrlReputation).all()
        assert [row.host for row in rows] == ["malware.example"]

    def test_empty_payload_applies_nothing(self, db_session):
        session, _ = db_session
        assert _feed_service(session, _StubClient("   \n\n")).ingest_once() == 0

    def test_disabled_feed_url_applies_nothing(self, db_session):
        session, _ = db_session
        service = _feed_service(session, _StubClient("evil.com,malicious"), feed_url="")
        assert service.ingest_once() == 0
        assert session.query(UrlReputation).count() == 0


class TestThreatIntelFeedIngestion:
    """Ingestion upserts, expires, and never raises."""

    def test_upsert_is_idempotent_and_updates(self, db_session):
        session, _ = db_session
        service = _feed_service(session, _StubClient("evil.com,malicious,first"))
        assert service.ingest_once() == 1
        service._client = _StubClient("evil.com,suspicious,updated")
        assert service.ingest_once() == 1
        rows = session.query(UrlReputation).all()
        assert len(rows) == 1
        assert rows[0].level == "suspicious"
        assert rows[0].reason == "updated"

    def test_ttl_applied_to_records(self, db_session):
        session, _ = db_session
        service = _feed_service(session, _StubClient("evil.com,malicious"), ttl_seconds=3600)
        service.ingest_once()
        row = session.query(UrlReputation).one()
        assert row.expires_at is not None
        expires = row.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        assert expires > datetime.now(timezone.utc)
        assert expires <= datetime.now(timezone.utc) + timedelta(seconds=3601)

    def test_reputation_readable_after_ingest(self, db_session):
        session, _ = db_session
        service = _feed_service(session, _StubClient("evil.com,malicious,phishing"))
        service.ingest_once()
        verdict = service._intel.get_reputation("evil.com")
        assert verdict is not None
        assert verdict.level == UrlVerdictLevel.MALICIOUS
        assert verdict.reason == "phishing"

    def test_fetch_failure_keeps_existing_records(self, db_session):
        session, _ = db_session
        intel = _intel_service(session)
        intel.record_reputation(
            session,
            "known.example",
            UrlVerdictLevel.MALICIOUS,
            "manual review",
        )
        client = _StubClient(exc=httpx.ConnectError("feed down"))
        service = _feed_service(session, client)
        assert service.ingest_once() == 0
        rows = session.query(UrlReputation).all()
        assert [row.host for row in rows] == ["known.example"]
        assert intel.get_reputation("known.example") is not None

    def test_database_failure_returns_zero(self, db_session, monkeypatch):
        session, _ = db_session

        def _boom(*args, **kwargs):
            raise RuntimeError("db down")

        monkeypatch.setattr(ThreatIntelService, "record_reputations", _boom)
        service = _feed_service(session, _StubClient("evil.com,malicious"))
        assert service.ingest_once() == 0

    def test_http_error_status_returns_zero(self, db_session):
        session, _ = db_session
        client = _StubClient("", status_code=503)
        assert _feed_service(session, client).ingest_once() == 0


class TestThreatIntelFeedTask:
    """The background loop survives iteration failures."""

    def test_loop_runs_iterations_and_survives_errors(self):
        calls = []

        class _Stub:
            def ingest_once(self):
                calls.append(1)
                if len(calls) == 1:
                    raise RuntimeError("boom")
                return 1

        async def _run():
            task = asyncio.create_task(
                threat_intel_feed_task(_Stub(), interval_seconds=0.01)
            )
            await asyncio.sleep(0.08)
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass

        asyncio.run(_run())
        assert len(calls) >= 2


class TestBuildThreatIntelFeedService:
    """Assembly is config-gated and Redis-aware."""

    def test_returns_none_when_feed_url_empty(self, settings):
        settings.security_threat_feed_url = ""
        assert build_threat_intel_feed_service() is None

    def test_returns_service_when_configured(self, settings, monkeypatch):
        settings.security_threat_feed_url = "http://feed.test/list"
        monkeypatch.setattr(
            "app.services.threat_intel_feed_service.create_redis_client",
            lambda: _FakeRedis(),
        )
        service = build_threat_intel_feed_service()
        assert isinstance(service, ThreatIntelFeedService)

    def test_returns_none_when_redis_unreachable(self, settings, monkeypatch):
        settings.security_threat_feed_url = "http://feed.test/list"
        monkeypatch.setattr(
            "app.services.threat_intel_feed_service.create_redis_client",
            lambda: None,
        )
        assert build_threat_intel_feed_service() is None

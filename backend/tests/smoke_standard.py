"""One-shot E2E smoke script for batch-2 (standard profile) features.

Requires MariaDB and a reachable Redis. Run with::

    SECURITY_PROFILE=standard python tests/smoke_standard.py

Covers the capabilities that only exist in the standard profile: WAF
rule hits and hot-reload, Redis Stream event fan-out and replay, URL
reputation escalation through the cached scanner, Redis rate limiting,
and token-device binding through the real auth flow.
"""

import sys
from datetime import datetime, timezone
from pathlib import Path

# Allow running from any working directory.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import redis
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.config import get_settings
from app.database import SessionLocal
from app.main import app
from app.models import User
from app.schemas.security import UrlVerdictLevel
from app.security.redis_client import create_redis_client
from app.security.singleton import get_security_capabilities
from app.services.email_service import EmailService
from app.services.event_queue_service import RedisStreamEventQueue
from app.services.threat_intel_service import ThreatIntelService

settings = get_settings()
client = TestClient(app)
db = SessionLocal()
redis_client = create_redis_client()

EMAIL = "smoke_std@example.com"
PASSWORD = "Smoke#2026xy"
failures = []


def check(name, cond, extra=""):
    status = "PASS" if cond else "FAIL"
    print(f"[{status}] {name} {extra}")
    if not cond:
        failures.append(name)


# 0. profile sanity
capabilities = get_security_capabilities()
check("profile is standard", settings.security_profile == "standard")
check("redis reachable", redis_client is not None)
check(
    "capabilities assembled",
    type(capabilities.waf_rules).__name__ == "RedisWafRuleProvider"
    and type(capabilities.event_sink).__name__ == "StreamingEventSink",
)

# 1. WAF: injection query blocked, clean path untouched
r = client.get("/api/v1/messages/conversation/1", params={"q": "1 union select 1"})
check("waf blocks sql injection query", r.status_code == 403, f"code={r.status_code}")

r = client.get("/api/v1/messages/conversation/1")
check("clean path not waf-blocked", r.status_code == 401, f"code={r.status_code}")

# 2. WAF hot reload: publish a custom rule document
capabilities.waf_rules.publish_rules(
    [{"name": "e2e_custom_block", "pattern": r"smoke-forbidden-marker"}], "e2e-v1"
)
r = client.get("/health", params={"probe": "smoke-forbidden-marker"})
check("waf hot-reloaded rule blocks", r.status_code == 403, f"code={r.status_code}")
r = client.get("/health", params={"probe": "union select"})
check("replaced rule set no longer blocks seed pattern", r.status_code == 200)
# Restore the seed set for subsequent checks.
redis_client.delete(settings.security_waf_rules_key)
capabilities.waf_rules._last_refresh = 0.0
r = client.get("/api/v1/messages/conversation/1", params={"q": "1 union select 1"})
check("seed rules restored after document removal", r.status_code == 403)

# 3. auth flow (register + login with device binding)
db.execute(text("DELETE FROM verification_codes WHERE email = :e"), {"e": EMAIL})
db.execute(text("DELETE FROM users WHERE email = :e"), {"e": EMAIL})
db.commit()

r = client.post(
    "/api/v1/auth/send-verification-code",
    json={"email": EMAIL, "purpose": "register"},
)
check("send-verification-code 200", r.status_code == 200, r.text[:120])

code = db.execute(
    text(
        "SELECT code FROM verification_codes WHERE email = :e "
        "AND purpose = 'register' ORDER BY id DESC LIMIT 1"
    ),
    {"e": EMAIL},
).scalar()

r = client.post(
    "/api/v1/auth/register",
    json={
        "email": EMAIL,
        "password": PASSWORD,
        "confirm_password": PASSWORD,
        "verification_code": code,
        "device_id": "e2e-device-1",
        "device_name": "E2E Phone",
        "platform": "ios",
    },
)
check("register 201", r.status_code == 201, r.text[:120])
token = r.json()["data"]["token"]["access_token"]
headers = {"Authorization": f"Bearer {token}"}

# 4. token-device binding: revoking the device invalidates the token
r = client.post("/api/v1/auth/logout", json={"device_id": "e2e-device-1"}, headers=headers)
check("device logout 200", r.status_code == 200, r.text[:120])
r = client.get("/api/v1/users/me", headers=headers)
check("revoked device token rejected", r.status_code == 401, f"code={r.status_code}")

# 5. login records attempts (success + failure)
r = client.post(
    "/api/v1/auth/login/password",
    json={"email": EMAIL, "password": "WrongPass#999", "device_id": "e2e-device-2"},
)
check("bad password 401", r.status_code == 401)
r = client.post(
    "/api/v1/auth/login/password",
    json={"email": EMAIL, "password": PASSWORD, "device_id": "e2e-device-2"},
)
check("good password 200", r.status_code == 200, r.text[:120])
token = r.json()["data"]["token"]["access_token"]
headers = {"Authorization": f"Bearer {token}"}

db.commit()  # refresh the REPEATABLE READ snapshot for cross-session rows
user = db.query(User).filter_by(email=EMAIL).one()
attempts = db.execute(
    text(
        "SELECT success, failure_reason FROM login_attempts "
        "WHERE email = :e ORDER BY id"
    ),
    {"e": EMAIL},
).all()
check(
    "login attempts recorded",
    len(attempts) >= 2
    and any(a.success for a in attempts)
    and any(not a.success and a.failure_reason == "bad_credentials" for a in attempts),
    f"rows={attempts}",
)

# 6. security events fan out to the Redis stream (precheck block path)
r = client.post(
    "/api/v1/messages/send",
    json={
        "conversation_id": 1,
        "content": "出售冰毒，联系我",
        "message_type": "text",
    },
    headers=headers,
)
check("violation message blocked", r.status_code == 400, f"code={r.status_code}")

queue = RedisStreamEventQueue(
    redis_client,
    stream_key=settings.security_event_stream_key,
    cursor_key=f"{settings.security_event_stream_key}:cursor",
)
events = queue.replay_since("0", count=50)
types = [event.get("type") for event in events]
check(
    "security events in redis stream",
    "message_blocked" in types,
    f"types={types}",
)
check("pending events visible to consumers", queue.pending_count() >= 1)

# 7. URL reputation escalation through the cached scanner
intel = ThreatIntelService(redis_client, session_factory=SessionLocal)
intel.record_reputation(
    db,
    "e2e-reputation.example.com",
    UrlVerdictLevel.MALICIOUS,
    "e2e recorded verdict",
    source="review",
)
verdict = capabilities.url_scanner.scan("https://e2e-reputation.example.com/x")
check(
    "reputation escalates unknown host",
    verdict.level == UrlVerdictLevel.MALICIOUS,
    f"level={verdict.level}",
)

# 8. edge blocklist: banning the client IP rejects requests; unban restores
capabilities.edge_blocklist.block_ip("testclient")
r = client.get("/health")
check("blocked client rejected", r.status_code == 403, f"code={r.status_code}")
capabilities.edge_blocklist.unblock_ip("testclient")
r = client.get("/health")
check("unblocked client restored", r.status_code == 200, f"code={r.status_code}")

# 9. redis rate-limit state is shared (keys exist in redis)
keys = redis_client.keys("porten:ratelimit:*")
check("redis rate limit keys present", len(keys) >= 1, f"keys={keys[:3]}")

print()
if failures:
    print(f"FAILED: {len(failures)} check(s): {failures}")
    sys.exit(1)
print("ALL STANDARD SMOKE CHECKS PASSED")

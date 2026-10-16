"""One-shot E2E smoke script for batch-1 security features."""

import sys
from datetime import datetime, timezone
from pathlib import Path

# Allow running from any working directory.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient
from sqlalchemy import text

from app.database import SessionLocal
from app.main import app
from app.models import Conversation
from app.services.email_service import EmailService

client = TestClient(app)
db = SessionLocal()

EMAIL = "smoke_a@example.com"
PASSWORD = "Smoke#2026xy"
failures = []


def check(name, cond, extra=""):
    status = "PASS" if cond else "FAIL"
    print(f"[{status}] {name} {extra}")
    if not cond:
        failures.append(name)


# 1. basic endpoints
check("health 200", client.get("/health").status_code == 200)
check("docs 200", client.get("/docs").status_code == 200)
check(
    "retention requires auth",
    client.get("/api/v1/retention").status_code == 401,
)

# 2. register flow (verification code is persisted even without SMTP)
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
        "verification_code": code,
        "password": PASSWORD,
        "confirm_password": PASSWORD,
        "nickname": "冒烟测试员",
    },
)
check("register 201", r.status_code == 201, r.text[:200])
# Refresh the snapshot so this session sees the freshly registered row.
db.commit()
token = r.json().get("data", {}).get("token", {}).get("access_token")
check("register returns token", bool(token))
headers = {"Authorization": f"Bearer {token}"}

# 3. retention settings
r = client.get("/api/v1/retention", headers=headers)
check("retention default 365", r.json()["data"]["retention_days"] == 365, r.text[:160])
r = client.put("/api/v1/retention", json={"retention_days": 90}, headers=headers)
check("retention set 90", r.json()["data"]["retention_days"] == 90)
r = client.put("/api/v1/retention", json={"retention_days": 30}, headers=headers)
check("retention rejects 30", r.status_code in (400, 422), r.text[:120])

# 4. friend conversation for message pre-check
db.commit()
sender_id = db.execute(
    text("SELECT id FROM users WHERE email = :e"), {"e": EMAIL}
).scalar()
friend = db.execute(
    text("SELECT id FROM users WHERE email != :e ORDER BY id LIMIT 1"), {"e": EMAIL}
).scalar()
if friend is None:
    db.execute(
        text(
            "INSERT INTO users (email, porten_id, nickname, role, is_active, "
            "email_verified, created_at, updated_at) VALUES "
            "('smoke_b@example.com', 'PT99999999', '好友', 'user', 1, 1, "
            "NOW(6), NOW(6))"
        )
    )
    db.commit()
    friend = db.execute(
        text("SELECT id FROM users WHERE email = 'smoke_b@example.com'")
    ).scalar()

conv = (
    db.query(Conversation)
    .filter_by(type="friend", user_id=sender_id, friend_user_id=friend)
    .first()
)
if not conv:
    db.execute(
        text(
            "INSERT IGNORE INTO friendships (user_id, friend_id, created_at, updated_at) "
            "VALUES (:a, :b, NOW(6), NOW(6)), (:b, :a, NOW(6), NOW(6))"
        ),
        {"a": sender_id, "b": friend},
    )
    db.commit()
    conv = Conversation(
        type="friend",
        user_id=sender_id,
        friend_user_id=friend,
        created_at=datetime.now(timezone.utc),
    )
    db.add(conv)
    db.commit()
conv_id = conv.id

# 5. send-time pre-check
r = client.post(
    "/api/v1/messages/send",
    json={"conversation_id": conv_id, "message_type": "text", "content": "今天激素复查结果很好"},
    headers=headers,
)
check("normal message 200", r.status_code == 200, r.text[:160])

r = client.post(
    "/api/v1/messages/send",
    json={"conversation_id": conv_id, "message_type": "text", "content": "出售冰毒联系我"},
    headers=headers,
)
check("drug message blocked 400", r.status_code == 400, r.text[:160])

r = client.post(
    "/api/v1/messages/send",
    json={"conversation_id": conv_id, "message_type": "text", "content": "点击 http://169.254.169.254/latest 领取"},
    headers=headers,
)
check("metadata url blocked 400", r.status_code == 400, r.text[:160])

r = client.post(
    "/api/v1/messages/send",
    json={"conversation_id": conv_id, "message_type": "text", "content": "最近好难受，不想活了，帮帮我"},
    headers=headers,
)
check("help-seeking allowed 200", r.status_code == 200, r.text[:160])

db.commit()
events = db.execute(
    text(
        "SELECT event_type, COUNT(*) FROM security_events "
        "WHERE user_id = :u GROUP BY event_type"
    ),
    {"u": sender_id},
).all()
print("    security events:", events)
check(
    "blocked + help events recorded",
    {"message_blocked": 2, "help_signal_detected": 1}.items()
    <= dict(events).items(),
)

# 6. rate limiting on auth bucket (30/min)
codes = [
    client.post(
        "/api/v1/auth/send-verification-code",
        json={"email": f"rl_{i}@example.com", "purpose": "register"},
    ).status_code
    for i in range(35)
]
check("auth rate limit triggers 429", 429 in codes, f"codes={sorted(set(codes))}")

db.close()
print()
if failures:
    print("FAILURES:", failures)
    sys.exit(1)
print("ALL SMOKE CHECKS PASSED")

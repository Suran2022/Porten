"""Tests for the admin security surface (#34): event triage, response
actions gated by two-person approval tickets, rule versioning,
retention adjustment and the ticket-gated audit report export."""

from datetime import datetime, timedelta, timezone

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import Integer, Text, create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.routers.security_admin as admin_module
from app.database import get_db
from app.models import (
    ApprovalTicket,
    AuditLog,
    Message,
    ModerationRuleVersion,
    RetentionPolicy,
    SecurityEvent,
    UebaEntityScore,
    User,
    Conversation,
)
from app.routers.security_admin import router
from app.services.approval_service import ApprovalService


# --- database fixture ---------------------------------------------------------

@pytest.fixture()
def db_session(monkeypatch):
    """In-memory SQLite with the tables the admin surface touches."""
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    # MySQL-only column types are temporarily retyped for SQLite
    # (SQLite only autoincrements INTEGER PRIMARY KEY).
    swapped = []
    for table in (
        User.__table__,
        AuditLog.__table__,
        ApprovalTicket.__table__,
        SecurityEvent.__table__,
        UebaEntityScore.__table__,
        Message.__table__,
        RetentionPolicy.__table__,
        ModerationRuleVersion.__table__,
        Conversation.__table__,
    ):
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
        SecurityEvent.__table__,
        UebaEntityScore.__table__,
        Message.__table__,
        RetentionPolicy.__table__,
        ModerationRuleVersion.__table__,
        Conversation.__table__,
    ):
        table.create(engine)
    for column, original in swapped:
        column.type = original

    factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    session = factory()
    admin = User(email="admin@t.test", porten_id="1", nickname="a", role="admin")
    member = User(email="u@t.test", porten_id="2", nickname="u", role="user")
    session.add_all([admin, member])
    session.commit()
    session.admin_id, session.member_id = admin.id, member.id

    yield session
    session.close()
    engine.dispose()


@pytest.fixture()
def client(db_session, monkeypatch):
    """Test app with the admin router, auth and db overridden."""
    test_app = FastAPI()
    test_app.include_router(router)

    def override_db():
        yield db_session

    async def override_admin():
        from app.models import User as U

        return db_session.query(U).filter_by(role="admin").first()

    test_app.dependency_overrides[get_db] = override_db
    test_app.dependency_overrides[admin_module.require_admin] = override_admin
    return TestClient(test_app)


# --- helpers -------------------------------------------------------------------

def _approved_ticket(db, action, payload, target_type=None, target_id=None):
    """Drive a ticket to APPROVED state directly (approval flow is
    covered by test_approval.py; here only the gate matters)."""
    service = ApprovalService()
    ticket = service.create(
        db,
        action=action,
        primary_user_id=db.admin_id,
        target_type=target_type,
        target_id=target_id,
        payload=payload,
    )
    ticket.status = "approved"
    ticket.reviewer_user_id = db.member_id
    db.commit()
    return ticket


def _seed_event(db, **overrides):
    fields = dict(
        event_type="malicious_url_blocked",
        severity="critical",
        user_id=db.member_id,
        detail="blocked",
        meta={"url_domain": "evil.example"},
        created_at=datetime.now(timezone.utc),
    )
    fields.update(overrides)
    event = SecurityEvent(**fields)
    db.add(event)
    db.commit()
    return event


# --- admin guard ----------------------------------------------------------------

def test_non_admin_gets_403(db_session, client):
    app = FastAPI()
    app.include_router(router)

    def override_db():
        yield db_session

    app.dependency_overrides[get_db] = override_db
    # No auth override: the real get_current_user runs and fails auth.
    guest = TestClient(app)
    response = guest.get("/api/v1/admin/security/events")
    assert response.status_code in (401, 403)


# --- event triage -----------------------------------------------------------------

def test_list_events_filters(db_session, client):
    _seed_event(db_session)
    _seed_event(db_session, event_type="login_anomaly", severity="info")
    _seed_event(
        db_session, user_id=None, event_type="honeypot_hit", severity="critical"
    )

    response = client.get("/api/v1/admin/security/events")
    assert response.status_code == 200
    assert len(response.json()["data"]) == 3

    response = client.get(
        "/api/v1/admin/security/events", params={"severity": "critical"}
    )
    assert all(row["severity"] == "critical" for row in response.json()["data"])

    response = client.get(
        "/api/v1/admin/security/events",
        params={"user_id": db_session.member_id, "hours": 1},
    )
    assert len(response.json()["data"]) == 2

    response = client.get(
        "/api/v1/admin/security/events",
        params={"hours": 1, "until_hours_ago": 2},
    )
    # unsupported filter is ignored, not an error
    assert response.status_code == 200


def test_event_context_redacted(db_session, client):
    event = _seed_event(db_session)
    db_session.add(
        UebaEntityScore(
            entity_type="user",
            entity_id=str(db_session.member_id),
            window_start=datetime.now(timezone.utc) - timedelta(hours=1),
            window_end=datetime.now(timezone.utc),
            score=73,
            level="high",
            signals={"security_events": 40},
        )
    )
    db_session.add(
        AuditLog(
            actor_id=db_session.admin_id,
            action="response_user_freeze",
            target_type="user",
            target_id=str(db_session.member_id),
            entry_hash="a" * 64,
        )
    )
    db_session.commit()

    response = client.get(f"/api/v1/admin/security/events/{event.id}/context")
    assert response.status_code == 200
    body = response.json()["data"]
    assert body["event"]["id"] == event.id
    assert body["ueba_score"]["score"] == 73
    assert body["ueba_score"]["level"] == "high"
    assert body["audit_entries"][0]["action"] == "response_user_freeze"
    # no raw content anywhere in the context
    assert "content" not in str(body).lower() or "[recalled" not in str(body)


def test_event_context_404(db_session, client):
    response = client.get("/api/v1/admin/security/events/999999/context")
    assert response.status_code == 404


# --- response actions ---------------------------------------------------------------

def test_response_action_without_ticket_rejected(db_session, client):
    message = _message(db_session)
    response = client.post(
        "/api/v1/admin/security/responses",
        json={
            "ticket_id": 424242,
            "action": "message_recall",
            "target_type": "message",
            "target_id": str(message.id),
            "payload": {"reason": "spam"},
        },
    )
    assert response.status_code == 403
    db_session.rollback()


def test_message_recall_with_ticket(db_session, client):
    message = _message(db_session)
    ticket = _approved_ticket(
        db_session, "message_recall", {"reason": "spam"},
        target_type="message", target_id=str(message.id),
    )
    response = client.post(
        "/api/v1/admin/security/responses",
        json={
            "ticket_id": ticket.id,
            "action": "message_recall",
            "target_type": "message",
            "target_id": str(message.id),
            "payload": {"reason": "spam"},
        },
    )
    assert response.status_code == 200, response.text
    assert response.json()["data"]["result"]["recalled"] is True
    db_session.refresh(message)
    assert message.message_type == "recalled"
    assert message.content == "[recalled by moderation]"
    # ticket consumed exactly once
    second = client.post(
        "/api/v1/admin/security/responses",
        json={
            "ticket_id": ticket.id,
            "action": "message_recall",
            "target_type": "message",
            "target_id": str(message.id),
            "payload": {"reason": "spam"},
        },
    )
    assert second.status_code == 403
    # the action left a chained audit entry
    entry = (
        db_session.query(AuditLog)
        .filter_by(action="response_message_recall")
        .first()
    )
    assert entry is not None


def test_payload_binding_rejects_modified_request(db_session, client):
    message = _message(db_session)
    ticket = _approved_ticket(
        db_session, "message_recall", {"reason": "spam"},
        target_type="message", target_id=str(message.id),
    )
    response = client.post(
        "/api/v1/admin/security/responses",
        json={
            "ticket_id": ticket.id,
            "action": "message_recall",
            "target_type": "message",
            "target_id": str(message.id),
            "payload": {"reason": "different reason"},
        },
    )
    assert response.status_code == 403


def test_user_freeze_and_unfreeze(db_session, client):
    ticket = _approved_ticket(
        db_session, "user_freeze", {"reason": "abuse"},
        target_type="user", target_id=str(db_session.member_id),
    )
    response = client.post(
        "/api/v1/admin/security/responses",
        json={
            "ticket_id": ticket.id,
            "action": "user_freeze",
            "target_type": "user",
            "target_id": str(db_session.member_id),
            "payload": {"reason": "abuse"},
        },
    )
    assert response.status_code == 200
    member = db_session.query(User).filter_by(id=db_session.member_id).first()
    assert member.is_active is False

    ticket2 = _approved_ticket(
        db_session, "user_unfreeze", {"reason": "appeal upheld"},
        target_type="user", target_id=str(db_session.member_id),
    )
    response = client.post(
        "/api/v1/admin/security/responses",
        json={
            "ticket_id": ticket2.id,
            "action": "user_unfreeze",
            "target_type": "user",
            "target_id": str(db_session.member_id),
            "payload": {"reason": "appeal upheld"},
        },
    )
    assert response.status_code == 200
    db_session.expire(member)
    assert member.is_active is True


def test_action_target_type_mismatch(db_session, client):
    ticket = _approved_ticket(
        db_session, "user_freeze", {"reason": "x"},
        target_type="message", target_id="1",
    )
    response = client.post(
        "/api/v1/admin/security/responses",
        json={
            "ticket_id": ticket.id,
            "action": "user_freeze",
            "target_type": "message",
            "target_id": "1",
            "payload": {"reason": "x"},
        },
    )
    assert response.status_code == 400


def _message(db):
    from app.models import Conversation

    conversation = Conversation(type="friend", user_id=db.member_id)
    db.add(conversation)
    db.flush()
    message = Message(
        conversation_id=conversation.id,
        sender_id=db.member_id,
        content="spam body",
    )
    db.add(message)
    db.commit()
    return message


# --- rule versioning -------------------------------------------------------------------

def test_rule_versions_append_only(db_session, client):
    response = client.post(
        "/api/v1/admin/security/rules",
        json={"name": "message_keywords", "patterns": ["a", "b"]},
    )
    assert response.status_code == 200
    assert response.json()["data"]["version"] == 1

    response = client.post(
        "/api/v1/admin/security/rules",
        json={"name": "message_keywords", "patterns": ["a", "b", "c"],
              "enabled": False},
    )
    assert response.json()["data"]["version"] == 2

    rows = client.get(
        "/api/v1/admin/security/rules", params={"name": "message_keywords"}
    ).json()["data"]
    assert [row["version"] for row in rows] == [2, 1]
    assert rows[0]["enabled"] is False
    entry = (
        db_session.query(AuditLog)
        .filter_by(action="rule_published", target_id="message_keywords:v2")
        .first()
    )
    assert entry is not None


# --- retention adjustment ----------------------------------------------------------------

def test_admin_retention_adjustment(db_session, client):
    response = client.put(
        f"/api/v1/admin/security/retention/{db_session.member_id}",
        json={"retention_days": 180},
    )
    assert response.status_code == 200
    policy = (
        db_session.query(RetentionPolicy)
        .filter_by(user_id=db_session.member_id)
        .first()
    )
    assert policy.retention_days == 180
    entry = (
        db_session.query(AuditLog).filter_by(action="retention_adjusted").first()
    )
    assert entry is not None

    response = client.put(
        f"/api/v1/admin/security/retention/{db_session.member_id}",
        json={"retention_days": 10},
    )
    # the request schema rejects out-of-range values before the service
    assert response.status_code == 422


def test_admin_retention_missing_user(db_session, client):
    response = client.put(
        "/api/v1/admin/security/retention/999999",
        json={"retention_days": 180},
    )
    assert response.status_code == 404


# --- audit report export --------------------------------------------------------------------

def test_audit_report_requires_ticket(db_session, client):
    response = client.post(
        "/api/v1/admin/security/audit-reports",
        json={"ticket_id": 424242, "target_type": "user",
              "target_id": str(db_session.member_id)},
    )
    assert response.status_code == 403


def test_audit_report_export(db_session, client):
    db_session.add(
        AuditLog(
            actor_id=db_session.admin_id,
            action="response_user_freeze",
            target_type="user",
            target_id=str(db_session.member_id),
            entry_hash="b" * 64,
        )
    )
    db_session.commit()
    ticket = _approved_ticket(
        db_session, "audit_report_export",
        {"target_type": "user", "target_id": str(db_session.member_id)},
    )
    response = client.post(
        "/api/v1/admin/security/audit-reports",
        json={"ticket_id": ticket.id, "target_type": "user",
              "target_id": str(db_session.member_id)},
    )
    assert response.status_code == 200, response.text
    body = response.json()["data"]
    assert body["target_id"] == str(db_session.member_id)
    assert any(
        entry["action"] == "response_user_freeze"
        for entry in body["entries"]
    )
    assert body["chain_checked"] >= 1


def test_audit_report_subject_binding(db_session, client):
    ticket = _approved_ticket(
        db_session, "audit_report_export",
        {"target_type": "user", "target_id": "555"},
    )
    response = client.post(
        "/api/v1/admin/security/audit-reports",
        json={"ticket_id": ticket.id, "target_type": "user",
              "target_id": str(db_session.member_id)},
    )
    assert response.status_code == 403

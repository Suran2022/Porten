"""Tests for the lite-profile security capabilities."""

import time
from types import SimpleNamespace

import pytest
from sqlalchemy import Integer, create_engine
from sqlalchemy.orm import sessionmaker

from app.models import RetentionPolicy, SecurityEvent, VerificationCode
from app.schemas.security import (
    ModerationDecision,
    UrlVerdictLevel,
)
from app.services.content_moderation_service import RuleBasedModerator
from app.services.email_service import EmailService
from app.services.rate_limit_service import InMemoryRateLimiter
from app.services.retention_service import RetentionService
from app.services.security_event_service import SecurityEventService
from app.services.send_precheck_service import (
    FAIL_CLOSED_WINDOW_SECONDS,
    PrecheckUnavailable,
    SendPrecheckService,
)
from app.services.url_scanner_service import LocalRuleUrlScanner
from app.utils.normalize import extract_urls, normalize_text


# ---------------------------------------------------------------------------
# URL scanner
# ---------------------------------------------------------------------------


def test_url_scanner_blocks_dangerous_scheme():
    """javascript:/data: URLs are always malicious."""
    scanner = LocalRuleUrlScanner()
    assert scanner.scan("javascript:alert(1)").level == UrlVerdictLevel.MALICIOUS
    assert scanner.scan("data:text/html,<script>").level == UrlVerdictLevel.MALICIOUS


def test_url_scanner_blocks_metadata_address():
    """Cloud metadata IPs are SSRF payloads and must be blocked."""
    scanner = LocalRuleUrlScanner()
    verdict = scanner.scan("http://169.254.169.254/latest/meta-data/")
    assert verdict.level == UrlVerdictLevel.MALICIOUS


def test_url_scanner_blocks_private_address():
    """Private-network literals are never legitimate chat links."""
    scanner = LocalRuleUrlScanner()
    assert scanner.scan("http://192.168.1.1/admin").level == UrlVerdictLevel.MALICIOUS
    assert scanner.scan("http://127.0.0.1:8080/").level == UrlVerdictLevel.MALICIOUS


def test_url_scanner_blocks_credential_authority():
    """http://trusted.com@evil.com/ style hosts are malicious."""
    scanner = LocalRuleUrlScanner()
    verdict = scanner.scan("http://porten.example.com@evil.example.com/login")
    assert verdict.level == UrlVerdictLevel.MALICIOUS


def test_url_scanner_allows_normal_url():
    """Ordinary public links stay safe."""
    scanner = LocalRuleUrlScanner()
    verdict = scanner.scan("https://porten.example.com/help")
    assert verdict.level == UrlVerdictLevel.SAFE


# ---------------------------------------------------------------------------
# Content moderator
# ---------------------------------------------------------------------------


def test_moderator_blocks_confirmed_violation():
    """Confirmed-level violations are blocked synchronously."""
    moderator = RuleBasedModerator()
    result = moderator.check("出售冰毒，联系我", "text")
    assert result.decision == ModerationDecision.BLOCK
    assert result.category == "drug"


def test_moderator_blocks_malicious_url_in_message():
    """A malicious link inside a message blocks the whole message."""
    moderator = RuleBasedModerator()
    result = moderator.check(
        "点击领取 http://169.254.169.254/latest/meta-data", "text"
    )
    assert result.decision == ModerationDecision.BLOCK
    assert result.category == "malicious_url"


def test_moderator_allows_help_seeking():
    """Help-seeking content is never blocked (CHI 2025 constraint)."""
    moderator = RuleBasedModerator()
    result = moderator.check("最近压力好大，不想活了，帮帮我", "text")
    assert result.decision == ModerationDecision.ALLOW
    assert result.category == "help_signal"


def test_moderator_allows_venting():
    """Negative venting without harm implementation stays allowed."""
    moderator = RuleBasedModerator()
    result = moderator.check("这个世界对跨性别者太不友善了，烦死了", "text")
    assert result.decision == ModerationDecision.ALLOW
    assert result.category is None


def test_moderator_allows_transition_discussion():
    """Medical/transition vocabulary must never trip the rules."""
    moderator = RuleBasedModerator()
    for text in (
        "今天激素复查结果很好",
        "医生说下个月可以调整剂量了",
        "性别肯定门诊挂号攻略",
    ):
        result = moderator.check(text, "text")
        assert result.decision == ModerationDecision.ALLOW, text


def test_moderator_folds_evasion():
    """Zero-width and separator evasion is folded before matching."""
    moderator = RuleBasedModerator()
    result = moderator.check("出\u200b售 冰\u00b7毒", "text")
    assert result.decision == ModerationDecision.BLOCK


def test_moderator_skips_non_text():
    """Only text is moderated synchronously in the lite profile."""
    moderator = RuleBasedModerator()
    result = moderator.check("anything", "image")
    assert result.decision == ModerationDecision.ALLOW


# ---------------------------------------------------------------------------
# Rate limiter
# ---------------------------------------------------------------------------


def test_rate_limiter_blocks_after_quota():
    """Requests beyond the window quota are rejected."""
    limiter = InMemoryRateLimiter()
    assert all(limiter.allow("k", 3, 60) for _ in range(3))
    assert limiter.allow("k", 3, 60) is False


def test_rate_limiter_window_expiry():
    """Quota frees up once the window elapses."""
    limiter = InMemoryRateLimiter()
    assert limiter.allow("k", 1, 0.05) is True
    assert limiter.allow("k", 1, 0.05) is False
    time.sleep(0.06)
    assert limiter.allow("k", 1, 0.05) is True


def test_rate_limiter_evicts_oldest_key():
    """Key capacity is bounded for low-memory deployments."""
    limiter = InMemoryRateLimiter(max_tracked_keys=2)
    limiter.allow("a", 10, 60)
    limiter.allow("b", 10, 60)
    limiter.allow("c", 10, 60)  # evicts "a"
    limiter.allow("b", 10, 60)  # touches "b" so "c" becomes oldest
    limiter.allow("d", 10, 60)  # evicts "c"
    # "a" was evicted: its window starts fresh rather than staying blocked
    assert limiter.allow("a", 1, 60) is True


# ---------------------------------------------------------------------------
# Normalization
# ---------------------------------------------------------------------------


def test_normalize_folds_zero_width_and_leet():
    """Normalization folds evasion variants to one canonical form."""
    assert normalize_text("黄\u200b色") == normalize_text("黄色")
    assert normalize_text("S3X") == normalize_text("sex")


def test_normalize_decodes_html_entities():
    """HTML-entity evasion is decoded before matching."""
    assert normalize_text("&lt;b&gt;x&lt;/b&gt;") == normalize_text("<b>x</b>")


def test_extract_urls_strips_trailing_punctuation():
    """URLs are extracted without trailing sentence punctuation."""
    assert extract_urls("看 https://a.example.com/x。") == ["https://a.example.com/x"]


# ---------------------------------------------------------------------------
# Security event sink (SQLite in-memory)
# ---------------------------------------------------------------------------


@pytest.fixture()
def db_session():
    """Provide an isolated in-memory database session.

    Only the security tables are created: the full metadata includes
    MySQL-specific column types that SQLite cannot render, and none of
    these tests need domain tables. Primary keys are temporarily typed
    as Integer because SQLite only autoincrements INTEGER PRIMARY KEY
    (rowid alias); production MySQL is unaffected.
    """
    engine = create_engine("sqlite://")
    tables = (
        SecurityEvent.__table__,
        RetentionPolicy.__table__,
        VerificationCode.__table__,
    )
    originals = {table: table.c.id.type for table in tables}
    for table in tables:
        table.c.id.type = Integer()
        table.create(engine)
        table.c.id.type = originals[table]
    session = sessionmaker(bind=engine)()
    yield session
    session.close()


def _user(user_id: int = 1) -> SimpleNamespace:
    """Lightweight stand-in carrying just the id."""
    return SimpleNamespace(id=user_id)


def test_event_sink_persists_event(db_session):
    """Events are persisted with metadata only."""
    SecurityEventService().emit(
        db_session,
        event_type="message_blocked",
        severity="warning",
        user_id=1,
        detail="blocked category: drug",
        meta={"category": "drug"},
    )
    db_session.commit()

    event = db_session.query(SecurityEvent).one()
    assert event.event_type == "message_blocked"
    assert event.severity == "warning"
    assert event.user_id == 1
    assert event.meta == {"category": "drug"}


def test_event_sink_never_raises(db_session):
    """A broken session must not surface as a business error."""
    SecurityEventService().emit(db_session, event_type="x", user_id=None)
    db_session.rollback()
    # Still usable afterwards.
    SecurityEventService().emit(db_session, event_type="y")
    db_session.commit()


# ---------------------------------------------------------------------------
# Send pre-check orchestration
# ---------------------------------------------------------------------------


class _FailingModerator:
    """Moderator stub that always fails."""

    def check(self, content, message_type):
        raise RuntimeError("boom")


def _precheck_service(moderator=None, sink=None):
    return SendPrecheckService(
        moderator or RuleBasedModerator(),
        sink or SecurityEventService(),
    )


def test_precheck_blocks_and_records(db_session):
    """Blocked messages raise for the router and emit an event."""
    service = _precheck_service()
    result = service.precheck(db_session, user_id=1, content="出售冰毒", message_type="text")
    assert result.decision == ModerationDecision.BLOCK
    event = db_session.query(SecurityEvent).one()
    assert event.event_type == "message_blocked"


def test_precheck_help_signal_records_without_block(db_session):
    """Help signals are recorded but never blocked."""
    service = _precheck_service()
    result = service.precheck(
        db_session, user_id=1, content="不想活了，帮帮我", message_type="text"
    )
    assert result.decision == ModerationDecision.ALLOW
    event = db_session.query(SecurityEvent).one()
    assert event.event_type == "help_signal_detected"


def test_precheck_fail_closed_window(db_session):
    """Checker failures reject sends inside the fail-closed window."""
    service = _precheck_service(moderator=_FailingModerator())
    with pytest.raises(PrecheckUnavailable):
        service.precheck(db_session, user_id=1, content="hi", message_type="text")


def test_precheck_degrades_after_window(db_session):
    """After the fail-closed window, sends degrade to record-and-review."""
    service = _precheck_service(moderator=_FailingModerator())
    # Simulate a failure that started just outside the fail-closed window.
    service._first_failure_at = time.monotonic() - FAIL_CLOSED_WINDOW_SECONDS - 1
    result = service.precheck(db_session, user_id=1, content="hi", message_type="text")
    assert result.decision == ModerationDecision.ALLOW
    assert result.category == "precheck_degraded"
    event = db_session.query(SecurityEvent).one()
    assert event.event_type == "precheck_degraded"


# ---------------------------------------------------------------------------
# Retention policy
# ---------------------------------------------------------------------------


def test_retention_defaults_to_one_year(db_session):
    """Users without a policy get the one-year default."""
    service = RetentionService()
    assert service.get_retention_days(db_session, _user()) == 365


def test_retention_set_and_update(db_session):
    """Retention can be set and updated within bounds."""
    user = _user()
    service = RetentionService()
    service.set_retention_days(db_session, user, 90)
    assert service.get_retention_days(db_session, user) == 90
    service.set_retention_days(db_session, user, 730)
    assert service.get_retention_days(db_session, user) == 730


def test_retention_rejects_out_of_bounds(db_session):
    """Values outside 3 months..2 years are rejected."""
    user = _user()
    service = RetentionService()
    with pytest.raises(ValueError):
        service.set_retention_days(db_session, user, 30)
    with pytest.raises(ValueError):
        service.set_retention_days(db_session, user, 731)


# ---------------------------------------------------------------------------
# Verification code hardening
# ---------------------------------------------------------------------------


def test_verification_code_attempt_cap(db_session):
    """Repeated wrong guesses stop validating after the attempt cap."""
    from datetime import datetime, timedelta, timezone

    record = VerificationCode(
        email="t@example.com",
        code="123456",
        purpose="login",
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
        used=False,
        attempts=EmailService.MAX_VERIFY_ATTEMPTS,
    )
    db_session.add(record)
    db_session.commit()

    service = EmailService()
    assert service.verify_code(db_session, "t@example.com", "123456", "login") is False

"""Security related schemas."""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class UrlVerdictLevel(str, Enum):
    """URL reputation levels."""

    SAFE = "safe"
    SUSPICIOUS = "suspicious"
    MALICIOUS = "malicious"


class UrlVerdict(BaseModel):
    """Result of scanning a single URL."""

    url: str
    level: UrlVerdictLevel = UrlVerdictLevel.SAFE
    reason: Optional[str] = None


class ModerationDecision(str, Enum):
    """Synchronous send-time pre-check decisions."""

    ALLOW = "allow"
    BLOCK = "block"


class ModerationResult(BaseModel):
    """Result of the synchronous send-time content pre-check.

    Only confirmed-level violations are blocked here; anything uncertain is
    allowed and routed to the asynchronous review queue.
    """

    decision: ModerationDecision = ModerationDecision.ALLOW
    category: Optional[str] = None
    reason: Optional[str] = None


class SecurityEventCreate(BaseModel):
    """Payload for recording a security event."""

    event_type: str = Field(..., max_length=50)
    severity: str = Field(default="info", max_length=20)
    user_id: Optional[int] = None
    detail: Optional[str] = None
    meta: Optional[dict] = None


class RetentionPolicyResponse(BaseModel):
    """Effective retention settings for the current user."""

    retention_days: int
    min_days: int
    max_days: int
    default_days: int
    is_customized: bool


class RetentionPolicyUpdate(BaseModel):
    """Payload for updating the user-side retention window."""

    retention_days: int = Field(..., ge=90, le=730)


class FetchResult(BaseModel):
    """Outcome of a sandboxed URL fetch (design doc §5.5).

    ``ok`` is False both for policy refusals (SSRF-blocked) and for
    transport failures; ``error`` carries the machine-readable reason
    (e.g. ``ssrf_blocked``, ``sandbox_unavailable``). Callers treat a
    failed fetch as "no dynamic conclusion" and stay fail-open.
    """

    ok: bool
    final_url: str = ""
    status_code: Optional[int] = None
    content_type: Optional[str] = None
    body: bytes = b""
    truncated: bool = False
    error: Optional[str] = None


class AdminSecurityEventResponse(BaseModel):
    """One security event as shown in the admin triage queue."""

    id: int
    event_type: str
    severity: str
    user_id: Optional[int] = None
    detail: Optional[str] = None
    meta: Optional[dict] = None
    created_at: datetime


class AdminEventContextResponse(BaseModel):
    """Redacted triage context for one event.

    Only non-content metadata is returned: the event itself, the
    entity's latest UEBA score and the audit entries bound to the
    subject. Raw message content never appears here.
    """

    event: AdminSecurityEventResponse
    ueba_score: Optional[dict] = None
    audit_entries: list[dict] = []


class ResponseActionRequest(BaseModel):
    """Execute a moderator response action bound to an approval ticket."""

    ticket_id: int
    action: str = Field(..., max_length=50)
    target_type: str = Field(..., max_length=20)
    target_id: str = Field(..., max_length=64)
    payload: Optional[dict] = None


class ResponseActionResponse(BaseModel):
    """Redacted result summary of an executed response action."""

    action: str
    target_type: str
    target_id: str
    result: dict


class RuleVersionPublish(BaseModel):
    """Publish a new version of a named moderation rule set."""

    name: str = Field(..., max_length=100)
    patterns: list = Field(default_factory=list)
    enabled: bool = True


class RuleVersionResponse(BaseModel):
    """One published rule version."""

    id: int
    name: str
    version: int
    patterns: Optional[list] = None
    enabled: bool
    created_by: Optional[int] = None
    created_at: datetime


class AdminRetentionUpdate(BaseModel):
    """Admin-side retention adjustment for one user."""

    retention_days: int = Field(..., ge=90, le=730)


class AuditReportRequest(BaseModel):
    """Export the audit report for one subject (ticket-gated)."""

    ticket_id: int
    target_type: str = Field(..., max_length=20)
    target_id: str = Field(..., max_length=64)


class AuditReportResponse(BaseModel):
    """Chain-verified audit trail for one subject."""

    target_type: str
    target_id: str
    entries: list[dict] = []
    chain_valid: bool
    chain_checked: int

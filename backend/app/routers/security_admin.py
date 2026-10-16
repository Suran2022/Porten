"""Admin security surface (design doc §5.6, admin profile only).

All endpoints require an authenticated admin. Destructive operations
(response actions, audit report export) are additionally gated by a
two-person / two-key approval ticket: the ticket is consumed with the
exact action + payload it authorized before the operation runs, so a
stolen admin session alone cannot act.
"""

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models import (
    AuditLog,
    ModerationRuleVersion,
    SecurityEvent,
    UebaEntityScore,
    User,
)
from app.schemas.common import ResponseModel
from app.schemas.security import (
    AdminEventContextResponse,
    AdminRetentionUpdate,
    AdminSecurityEventResponse,
    AuditReportRequest,
    AuditReportResponse,
    ResponseActionRequest,
    ResponseActionResponse,
    RuleVersionPublish,
    RuleVersionResponse,
)
from app.services.approval_service import ApprovalError, approval_service
from app.services.audit_chain_service import AuditChainError, AuditChainService
from app.services.response_action_service import (
    ResponseActionError,
    response_action_service,
)
from app.services.retention_service import RetentionService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/admin/security", tags=["admin-security"])

audit_chain_service = AuditChainService()
retention_service = RetentionService()


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """Guard the whole admin surface behind the admin role."""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="admin privileges required",
        )
    return current_user


def _entry_summary(entry: AuditLog) -> dict:
    """Redacted, non-content summary of one audit entry."""
    return {
        "id": entry.id,
        "action": entry.action,
        "actor_id": entry.actor_id,
        "target_type": entry.target_type,
        "target_id": entry.target_id,
        "summary": entry.summary,
        "created_at": entry.created_at,
        "entry_hash": entry.entry_hash,
    }


def _event_response(event: SecurityEvent) -> AdminSecurityEventResponse:
    return AdminSecurityEventResponse(
        id=event.id,
        event_type=event.event_type,
        severity=event.severity,
        user_id=event.user_id,
        detail=event.detail,
        meta=event.meta,
        created_at=event.created_at,
    )


# -- event triage ----------------------------------------------------------


@router.get("/events", response_model=ResponseModel[list[AdminSecurityEventResponse]])
def list_events(
    severity: Optional[str] = Query(None),
    event_type: Optional[str] = Query(None),
    user_id: Optional[int] = Query(None),
    hours: int = Query(24, ge=1, le=24 * 30),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    """Query the security event trail with multi-dimension filters."""
    query = db.query(SecurityEvent).order_by(SecurityEvent.id.desc())
    if severity is not None:
        query = query.filter(SecurityEvent.severity == severity)
    if event_type is not None:
        query = query.filter(SecurityEvent.event_type == event_type)
    if user_id is not None:
        query = query.filter(SecurityEvent.user_id == user_id)
    query = query.filter(
        SecurityEvent.created_at
        >= datetime.now(timezone.utc) - timedelta(hours=hours)
    )
    rows = query.offset(offset).limit(limit).all()
    return ResponseModel(data=[_event_response(row) for row in rows])


@router.get(
    "/events/{event_id}/context",
    response_model=ResponseModel[AdminEventContextResponse],
)
def get_event_context(
    event_id: int,
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    """Redacted triage context: event + latest UEBA score + audit trail."""
    event = db.query(SecurityEvent).filter_by(id=event_id).first()
    if event is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="event not found"
        )
    ueba = None
    if event.user_id is not None:
        score = (
            db.query(UebaEntityScore)
            .filter_by(entity_type="user", entity_id=str(event.user_id))
            .order_by(UebaEntityScore.window_start.desc())
            .first()
        )
        if score is not None:
            ueba = {
                "window_start": score.window_start,
                "score": score.score,
                "level": score.level,
                "signals": score.signals,
            }
    entries = []
    if event.user_id is not None:
        entries = [
            _entry_summary(entry)
            for entry in audit_chain_service.entries_for_subject(
                db, "user", str(event.user_id), limit=20
            )
        ]
    return ResponseModel(
        data=AdminEventContextResponse(
            event=_event_response(event),
            ueba_score=ueba,
            audit_entries=entries,
        )
    )


# -- response actions --------------------------------------------------------


@router.post("/responses", response_model=ResponseModel[ResponseActionResponse])
def execute_response(
    payload: ResponseActionRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Execute a response action bound to a consumed approval ticket."""
    request_payload = payload.payload or {}
    try:
        approval_service.consume(
            db,
            payload.ticket_id,
            action=payload.action,
            payload=request_payload,
            actor_id=admin.id,
        )
        result = response_action_service.execute(
            db,
            action=payload.action,
            target_type=payload.target_type,
            target_id=payload.target_id,
            operator_id=admin.id,
            payload=request_payload,
        )
    except ApprovalError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)
        ) from exc
    except (ResponseActionError, AuditChainError) as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    return ResponseModel(
        data=ResponseActionResponse(
            action=payload.action,
            target_type=payload.target_type,
            target_id=payload.target_id,
            result=result,
        )
    )


# -- rule versioning ---------------------------------------------------------


@router.get("/rules", response_model=ResponseModel[list[RuleVersionResponse]])
def list_rules(
    name: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    """List published rule versions, newest first."""
    query = db.query(ModerationRuleVersion).order_by(
        ModerationRuleVersion.name, ModerationRuleVersion.version.desc()
    )
    if name is not None:
        query = query.filter(ModerationRuleVersion.name == name)
    rows = query.limit(200).all()
    return ResponseModel(
        data=[
            RuleVersionResponse(
                id=row.id,
                name=row.name,
                version=row.version,
                patterns=row.patterns,
                enabled=row.enabled,
                created_by=row.created_by,
                created_at=row.created_at,
            )
            for row in rows
        ]
    )


@router.post("/rules", response_model=ResponseModel[RuleVersionResponse])
def publish_rule(
    payload: RuleVersionPublish,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Publish the next version of a rule set (append-only, audited)."""
    latest = (
        db.query(ModerationRuleVersion)
        .filter_by(name=payload.name)
        .order_by(ModerationRuleVersion.version.desc())
        .first()
    )
    version = (latest.version + 1) if latest else 1
    row = ModerationRuleVersion(
        name=payload.name,
        version=version,
        patterns=payload.patterns,
        enabled=payload.enabled,
        created_by=admin.id,
    )
    db.add(row)
    db.flush()
    try:
        audit_chain_service.append(
            db,
            actor_id=admin.id,
            actor_role="admin",
            action="rule_published",
            target_type="rule",
            target_id=f"{payload.name}:v{version}",
            summary=f"published rule {payload.name} v{version}",
            meta={"version": version, "enabled": payload.enabled},
        )
    except AuditChainError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="audit recording failed; rule not published",
        ) from exc
    return ResponseModel(
        data=RuleVersionResponse(
            id=row.id,
            name=row.name,
            version=row.version,
            patterns=row.patterns,
            enabled=row.enabled,
            created_by=row.created_by,
            created_at=row.created_at,
        )
    )


# -- retention adjustment ------------------------------------------------------


@router.put("/retention/{user_id}", response_model=ResponseModel[dict])
def adjust_retention(
    user_id: int,
    payload: AdminRetentionUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Admin-side retention window adjustment for one user (audited)."""
    target = db.query(User).filter_by(id=user_id).first()
    if target is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="user not found"
        )
    try:
        retention_service.set_retention_days(db, target, payload.retention_days)
        audit_chain_service.append(
            db,
            actor_id=admin.id,
            actor_role="admin",
            action="retention_adjusted",
            target_type="user",
            target_id=str(user_id),
            summary=f"retention set to {payload.retention_days} days",
            meta={"retention_days": payload.retention_days},
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    except AuditChainError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="audit recording failed; retention not adjusted",
        ) from exc
    return ResponseModel(
        data={"user_id": user_id, "retention_days": payload.retention_days}
    )


# -- audit report export (ticket-gated) ------------------------------------------


@router.post("/audit-reports", response_model=ResponseModel[AuditReportResponse])
def export_audit_report(
    payload: AuditReportRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Export the chain-verified audit trail for one subject.

    Requires a two-person / two-key ticket for the
    ``audit_report_export`` action bound to the same subject, so bulk
    evidence export can never happen on one person's say-so.
    """
    try:
        approval_service.consume(
            db,
            payload.ticket_id,
            action="audit_report_export",
            payload={
                "target_type": payload.target_type,
                "target_id": payload.target_id,
            },
            actor_id=admin.id,
        )
        entries = [
            _entry_summary(entry)
            for entry in audit_chain_service.entries_for_subject(
                db, payload.target_type, payload.target_id, limit=500
            )
        ]
        report = audit_chain_service.verify_chain(db)
    except ApprovalError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)
        ) from exc
    except AuditChainError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)
        ) from exc
    return ResponseModel(
        data=AuditReportResponse(
            target_type=payload.target_type,
            target_id=payload.target_id,
            entries=entries,
            chain_valid=report.valid,
            chain_checked=report.checked,
        )
    )

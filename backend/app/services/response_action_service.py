"""Response action service (admin triage surface, design doc §5.6).

Executes the moderator response catalogue against live records:

* ``message_mark``        -- flag a message for review;
* ``message_recall``      -- blank the content and mark it recalled;
* ``message_quarantine``  -- hide a message pending manual review;
* ``user_freeze``         -- deactivate an account;
* ``user_unfreeze``       -- reactivate an account;
* ``circuit_breaker``     -- block a source IP at the edge.

Every action is gated upstream by a two-person / two-key approval
ticket (the router consumes the ticket before calling in) and records
a hash-chained audit entry. ``AuditChainService.append`` commits the
session as part of recording, so callers must treat the audit write as
the transaction boundary: on ``AuditChainError`` the whole change rolls
back (fail-closed -- a response without its audit trail is not
applied).
"""

import logging
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.models import Message, User
from app.security.singleton import get_security_capabilities
from app.services.audit_chain_service import AuditChainService, AuditChainError

logger = logging.getLogger(__name__)


class ResponseActionError(RuntimeError):
    """Raised when a response action cannot be executed."""


class ResponseActionService:
    """Execute moderator response actions with chained audit records."""

    ACTIONS = {
        "message_mark": "message",
        "message_recall": "message",
        "message_quarantine": "message",
        "user_freeze": "user",
        "user_unfreeze": "user",
        "circuit_breaker": "ip",
    }
    #: Payload keys persisted into the audit entry (never raw content).
    AUDIT_META_KEYS = ("reason", "case_id", "ticket_id")

    def __init__(self, audit: Optional[AuditChainService] = None) -> None:
        self._audit_service = audit or AuditChainService()

    def execute(
        self,
        db: Session,
        *,
        action: str,
        target_type: str,
        target_id: str,
        operator_id: int,
        payload: Optional[dict[str, Any]] = None,
        ip: Optional[str] = None,
    ) -> dict:
        """Run one response action; returns a redacted result summary."""
        if action not in self.ACTIONS:
            raise ResponseActionError(f"unknown action: {action}")
        if self.ACTIONS[action] != target_type:
            raise ResponseActionError(
                f"action {action} applies to {self.ACTIONS[action]} targets"
            )
        payload = payload or {}
        handler = {
            "message_mark": self._mark_message,
            "message_recall": self._recall_message,
            "message_quarantine": self._quarantine_message,
            "user_freeze": self._set_user_active,
            "user_unfreeze": self._set_user_active,
            "circuit_breaker": self._circuit_breaker,
        }[action]
        result = handler(db, str(target_id), payload, action)
        try:
            self._audit(
                db,
                action=action,
                target_type=target_type,
                target_id=str(target_id),
                operator_id=operator_id,
                payload=payload,
                ip=ip,
            )
        except AuditChainError as exc:
            db.rollback()
            raise ResponseActionError(
                "audit recording failed; response not applied"
            ) from exc
        return result

    # -- handlers ----------------------------------------------------------

    def _mark_message(self, db: Session, target_id: str, payload: dict, action: str) -> dict:
        message = self._get_message(db, target_id)
        message.extra = {**(message.extra or {}), "flagged": True}
        return {"message_id": message.id, "flagged": True}

    def _recall_message(self, db: Session, target_id: str, payload: dict, action: str) -> dict:
        message = self._get_message(db, target_id)
        message.content = "[recalled by moderation]"
        message.message_type = "recalled"
        message.extra = {**(message.extra or {}), "recalled": True}
        return {"message_id": message.id, "recalled": True}

    def _quarantine_message(
        self, db: Session, target_id: str, payload: dict, action: str
    ) -> dict:
        message = self._get_message(db, target_id)
        message.message_type = "quarantined"
        message.extra = {**(message.extra or {}), "quarantined": True}
        return {"message_id": message.id, "quarantined": True}

    def _set_user_active(
        self, db: Session, target_id: str, payload: dict, action: str
    ) -> dict:
        user = db.query(User).filter_by(id=int(target_id)).first()
        if user is None:
            raise ResponseActionError(f"user {target_id} not found")
        user.is_active = action == "user_unfreeze"
        return {"user_id": user.id, "is_active": user.is_active}

    def _circuit_breaker(
        self, db: Session, target_id: str, payload: dict, action: str
    ) -> dict:
        blocklist = getattr(get_security_capabilities(), "edge_blocklist", None)
        if blocklist is None:
            raise ResponseActionError("edge blocklist is not available")
        try:
            blocklist.block_ip(target_id)
        except Exception as exc:
            raise ResponseActionError(f"blocking {target_id} failed") from exc
        return {"ip": target_id, "blocked": True}

    # -- internals ---------------------------------------------------------

    def _get_message(self, db: Session, target_id: str) -> Message:
        message = db.query(Message).filter_by(id=int(target_id)).first()
        if message is None:
            raise ResponseActionError(f"message {target_id} not found")
        return message

    def _audit(
        self,
        db: Session,
        *,
        action: str,
        target_type: str,
        target_id: str,
        operator_id: int,
        payload: dict,
        ip: Optional[str],
    ) -> None:
        meta = {key: payload[key] for key in self.AUDIT_META_KEYS if payload.get(key)}
        meta["executor_id"] = operator_id
        self._audit_service.append(
            db,
            actor_id=operator_id,
            actor_role="admin",
            action=f"response_{action}",
            target_type=target_type,
            target_id=target_id,
            summary=f"response action: {action}",
            meta=meta,
            ip_hash=ip,
        )


response_action_service = ResponseActionService()

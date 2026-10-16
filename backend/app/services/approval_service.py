"""Two-person / two-key approval service (design doc §10.1).

A sensitive operation requires two hardware keys pressed in sequence:
the primary operator opens a ticket bound to the exact action, target
and payload, presses their own key, and a *different* reviewer presses
theirs within the validity window (default 5 minutes). Only an
approved-and-unexpired ticket may be spent once by the operation it
was issued for.

Every transition is appended to the hash-chained audit log (§9), so
the "who pressed what key when" trail is tamper-evident. A failed
audit append rolls the transition back and aborts it: approvals can
never happen without leaving evidence (fail-closed).

Authorization ("two people agreed") is deliberately kept separate from
access control ("these people may do this"): the admin RBAC layer
(#34) is stacked on top and decides who may open which ticket type.
"""

import asyncio
import json
import logging
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import ApprovalTicket
from app.services.audit_chain_service import AuditChainError, AuditChainService
from app.services.webauthn_service import KeyCarrierError, fido2_key_carrier
from app.utils.security import hash_ip

logger = logging.getLogger(__name__)

# Ticket states and their allowed transitions (kept here, not in the
# model, so the state machine is visible next to its enforcement).
PENDING = "pending"
APPROVED = "approved"
REJECTED = "rejected"
EXPIRED = "expired"
CONSUMED = "consumed"
CANCELLED = "cancelled"


class ApprovalError(RuntimeError):
    """Raised when an approval operation violates the two-key rule."""


def _canonical(payload: Optional[dict]) -> str:
    """Serialize a payload deterministically (None means empty)."""
    return json.dumps(payload or {}, sort_keys=True, ensure_ascii=False)


class ApprovalService:
    """Ticketed two-key authorization state machine."""

    def __init__(self, *, carrier=None, audit: Optional[AuditChainService] = None):
        # The carrier is injectable so tests can substitute a stub; the
        # default is the FIDO2 implementation.
        self._carrier = carrier if carrier is not None else fido2_key_carrier
        self._audit_service = audit or AuditChainService()

    # -- ticket lifecycle ----------------------------------------------------

    def create(
        self,
        db: Session,
        *,
        action: str,
        primary_user_id: int,
        target_type: Optional[str] = None,
        target_id: Optional[Any] = None,
        payload: Optional[dict] = None,
        ip: Optional[str] = None,
    ) -> ApprovalTicket:
        """Open a pending ticket bound to the exact action and payload."""
        if not action:
            raise ApprovalError("action is required")
        settings = get_settings()
        ticket = ApprovalTicket(
            action=action,
            target_type=target_type,
            target_id=str(target_id) if target_id is not None else None,
            request_payload=payload,
            primary_user_id=primary_user_id,
            status=PENDING,
            challenge_nonce=secrets.token_urlsafe(32),
            expires_at=datetime.now(timezone.utc)
            + timedelta(seconds=settings.security_approval_ttl_seconds),
        )
        db.add(ticket)
        db.flush()
        self._audit(
            db,
            actor_id=primary_user_id,
            audit_action="approval_ticket_created",
            ticket=ticket,
            ip=ip,
            summary=f"approval requested: {action}",
        )
        return ticket

    def begin_primary(
        self, db: Session, ticket_id: int, actor_id: int
    ) -> dict:
        """Key-press options for the primary operator's own credential."""
        ticket = self._load_active(db, ticket_id)
        if ticket.status != PENDING:
            raise ApprovalError(f"ticket is {ticket.status}")
        if ticket.primary_authorized_at is not None:
            raise ApprovalError("primary key already pressed")
        if actor_id != ticket.primary_user_id:
            raise ApprovalError("only the primary operator may start this ceremony")
        return self._carrier.begin_assertion(
            db, actor_id, ticket.challenge_nonce.encode("utf-8")
        )

    def authorize_primary(
        self,
        db: Session,
        ticket_id: int,
        actor_id: int,
        credential: dict,
        ip: Optional[str] = None,
    ) -> ApprovalTicket:
        """Record the primary operator's key press."""
        ticket = self._load_active(db, ticket_id)
        if ticket.status != PENDING:
            raise ApprovalError(f"ticket is {ticket.status}")
        if ticket.primary_authorized_at is not None:
            raise ApprovalError("primary key already pressed")
        if actor_id != ticket.primary_user_id:
            raise ApprovalError("only the primary operator may press this key")
        credential_id = self._press(db, actor_id, credential, ticket)
        ticket.primary_credential_id = credential_id
        ticket.primary_authorized_at = datetime.now(timezone.utc)
        self._audit(
            db,
            actor_id=actor_id,
            audit_action="approval_primary_authorized",
            ticket=ticket,
            ip=ip,
            credential_id=credential_id,
            summary=f"primary key pressed for {ticket.action}",
        )
        return ticket

    def begin_reviewer(
        self, db: Session, ticket_id: int, actor_id: int
    ) -> dict:
        """Key-press options for the reviewer's own credential."""
        ticket = self._load_active(db, ticket_id)
        if ticket.status != PENDING:
            raise ApprovalError(f"ticket is {ticket.status}")
        if ticket.primary_authorized_at is None:
            raise ApprovalError("waiting for the primary key")
        if actor_id == ticket.primary_user_id:
            raise ApprovalError("the reviewer must be another person")
        return self._carrier.begin_assertion(
            db, actor_id, ticket.challenge_nonce.encode("utf-8")
        )

    def authorize_reviewer(
        self,
        db: Session,
        ticket_id: int,
        actor_id: int,
        credential: dict,
        ip: Optional[str] = None,
    ) -> ApprovalTicket:
        """Record the reviewer's key press; the ticket becomes approved."""
        ticket = self._load_active(db, ticket_id)
        if ticket.status != PENDING:
            raise ApprovalError(f"ticket is {ticket.status}")
        if ticket.primary_authorized_at is None:
            raise ApprovalError("waiting for the primary key")
        if actor_id == ticket.primary_user_id:
            raise ApprovalError("the reviewer must be another person")
        if ticket.reviewer_user_id is not None:
            raise ApprovalError("reviewer already recorded")
        credential_id = self._press(db, actor_id, credential, ticket)
        ticket.reviewer_user_id = actor_id
        ticket.reviewer_credential_id = credential_id
        ticket.reviewer_authorized_at = datetime.now(timezone.utc)
        ticket.status = APPROVED
        self._audit(
            db,
            actor_id=actor_id,
            audit_action="approval_reviewer_authorized",
            ticket=ticket,
            ip=ip,
            credential_id=credential_id,
            summary=f"reviewer approved {ticket.action}",
        )
        return ticket

    def reject(
        self,
        db: Session,
        ticket_id: int,
        actor_id: int,
        note: str,
        ip: Optional[str] = None,
    ) -> ApprovalTicket:
        """Reviewer refusal; the ticket can never be approved."""
        ticket = self._load_active(db, ticket_id)
        if ticket.status != PENDING:
            raise ApprovalError(f"ticket is {ticket.status}")
        if ticket.primary_authorized_at is None:
            raise ApprovalError("waiting for the primary key")
        if actor_id == ticket.primary_user_id:
            raise ApprovalError("the reviewer must be another person")
        if not note:
            raise ApprovalError("a rejection note is required")
        ticket.reviewer_user_id = actor_id
        ticket.status = REJECTED
        ticket.decision_note = note
        self._audit(
            db,
            actor_id=actor_id,
            audit_action="approval_rejected",
            ticket=ticket,
            ip=ip,
            summary=f"reviewer rejected {ticket.action}",
        )
        return ticket

    def cancel(
        self, db: Session, ticket_id: int, actor_id: int, ip: Optional[str] = None
    ) -> ApprovalTicket:
        """Primary operator withdraws the request before review."""
        ticket = self._load_active(db, ticket_id)
        if ticket.status != PENDING:
            raise ApprovalError(f"ticket is {ticket.status}")
        if actor_id != ticket.primary_user_id:
            raise ApprovalError("only the primary operator may cancel")
        ticket.status = CANCELLED
        self._audit(
            db,
            actor_id=actor_id,
            audit_action="approval_cancelled",
            ticket=ticket,
            ip=ip,
            summary=f"primary cancelled {ticket.action}",
        )
        return ticket

    def consume(
        self,
        db: Session,
        ticket_id: int,
        *,
        action: str,
        payload: Optional[dict] = None,
        actor_id: int,
        ip: Optional[str] = None,
    ) -> ApprovalTicket:
        """Spend an approved ticket; one-shot and binding-checked.

        The operation must present the exact action and payload the
        two keys authorized. Either authorized party (primary or
        reviewer) may execute; the audit entry records who did.
        """
        ticket = self._load_active(db, ticket_id)
        if ticket.status != APPROVED:
            raise ApprovalError(f"ticket is {ticket.status}, not approved")
        if ticket.action != action:
            raise ApprovalError("ticket was issued for a different action")
        if _canonical(payload) != _canonical(ticket.request_payload):
            raise ApprovalError("payload differs from the authorized one")
        if actor_id not in (ticket.primary_user_id, ticket.reviewer_user_id):
            raise ApprovalError("executor is not an authorized party")
        ticket.status = CONSUMED
        ticket.consumed_at = datetime.now(timezone.utc)
        self._audit(
            db,
            actor_id=actor_id,
            audit_action="approval_ticket_consumed",
            ticket=ticket,
            ip=ip,
            summary=f"ticket spent by {action}",
        )
        return ticket

    # -- queries and maintenance ---------------------------------------------

    def get(self, db: Session, ticket_id: int) -> ApprovalTicket:
        """Return the ticket; overdue pending/approved tickets expire."""
        ticket = self._load_active(db, ticket_id)
        return ticket

    def list_tickets(
        self,
        db: Session,
        *,
        status: Optional[str] = None,
        limit: int = 50,
    ) -> list:
        """Recent tickets for the admin surface (newest first)."""
        query = db.query(ApprovalTicket).order_by(ApprovalTicket.id.desc())
        if status is not None:
            query = query.filter_by(status=status)
        return query.limit(limit).all()

    def expire_overdue(self, db: Session) -> int:
        """Expire every pending/approved ticket past its deadline.

        Returns the number of tickets expired. Used by the background
        sweep; transitions happen through the audit-protected path.
        """
        now = datetime.now(timezone.utc)
        overdue = (
            db.query(ApprovalTicket)
            .filter(
                ApprovalTicket.status.in_([PENDING, APPROVED]),
                ApprovalTicket.expires_at <= now,
            )
            .all()
        )
        expired = 0
        for ticket in overdue:
            ticket.status = EXPIRED
            try:
                self._audit(
                    db,
                    actor_id=None,
                    audit_action="approval_expired",
                    ticket=ticket,
                    ip=None,
                    summary=f"ticket expired: {ticket.action}",
                )
                expired += 1
            except ApprovalError:
                # One failed append must not block the sweep of the rest.
                logger.warning(
                    "approval expiry audit failed for ticket %s", ticket.id
                )
        return expired

    # -- internals -------------------------------------------------------------

    def _load_active(self, db: Session, ticket_id: int) -> ApprovalTicket:
        """Load a ticket, expiring it first when its deadline passed."""
        ticket = db.get(ApprovalTicket, ticket_id)
        if ticket is None:
            raise ApprovalError("unknown ticket")
        if ticket.status in (PENDING, APPROVED) and self._deadline_passed(ticket):
            ticket.status = EXPIRED
            self._audit(
                db,
                actor_id=None,
                audit_action="approval_expired",
                ticket=ticket,
                ip=None,
                summary=f"ticket expired: {ticket.action}",
            )
        return ticket

    def _deadline_passed(self, ticket: ApprovalTicket) -> bool:
        expires_at = ticket.expires_at
        if expires_at.tzinfo is None:
            # SQLite round-trips naive datetimes; they are UTC by
            # construction (see the model default).
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        return expires_at <= datetime.now(timezone.utc)

    def _press(
        self, db: Session, user_id: int, credential: dict, ticket: ApprovalTicket
    ) -> str:
        """Verify one key press; failures become plain ApprovalError."""
        try:
            return self._carrier.verify_assertion(
                db,
                user_id,
                credential,
                ticket.challenge_nonce.encode("utf-8"),
            )
        except KeyCarrierError as exc:
            raise ApprovalError(f"key verification failed: {exc}") from exc

    def _audit(
        self,
        db: Session,
        *,
        actor_id: Optional[int],
        audit_action: str,
        ticket: ApprovalTicket,
        ip: Optional[str],
        summary: str,
        credential_id: Optional[str] = None,
    ) -> None:
        """Append the transition to the audit chain; fail closed.

        The append commits the pending ticket transition together with
        the audit entry; on failure the transition is rolled back so no
        approval ever happens without leaving evidence.
        """
        meta: dict = {
            "ticket_id": ticket.id,
            "approval_action": ticket.action,
            "nonce": ticket.challenge_nonce,
        }
        if credential_id is not None:
            meta["credential_id"] = credential_id
        try:
            self._audit_service.append(
                db,
                actor_id=actor_id,
                action=audit_action,
                actor_role="admin",
                target_type=ticket.target_type,
                target_id=ticket.target_id,
                summary=summary,
                meta=meta,
                ip_hash=hash_ip(ip) if ip else None,
            )
        except AuditChainError as exc:
            db.rollback()
            raise ApprovalError("audit recording failed; approval not applied") from exc


async def approval_expiry_task(
    service: ApprovalService, interval_seconds: int
) -> None:
    """Background sweep: expire overdue tickets until shutdown.

    Every iteration failure is swallowed so the loop can never die on
    a transient database problem.
    """
    from app.database import SessionLocal

    while True:
        try:
            db = SessionLocal()
            try:
                expired = service.expire_overdue(db)
                if expired:
                    logger.info("approval sweep expired %d tickets", expired)
            finally:
                db.close()
        except Exception:
            logger.warning("approval expiry sweep failed", exc_info=True)
        await asyncio.sleep(interval_seconds)


approval_service = ApprovalService()

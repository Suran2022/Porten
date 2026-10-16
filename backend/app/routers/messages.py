"""Message router."""

import logging
from typing import List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.database import SessionLocal, get_db
from app.dependencies.auth import get_current_user
from app.models import Conversation, Friendship, GroupMember, Message, User
from app.schemas.common import ResponseModel
from app.schemas.message import MessageCreate, MessageResponse
from app.schemas.security import ModerationDecision
from app.security.singleton import get_security_capabilities
from app.services.message_service import message_service
from app.services.send_precheck_service import (
    PrecheckUnavailable,
    send_precheck_service,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/messages", tags=["messages"])


def _assess_message_behavior(user_id: int, conversation_id: int) -> None:
    """Post-send behavior analysis; never blocks or fails the request.

    Runs as a background task with its own session: if the analyzer is
    absent (lite profile) or fails, sending is unaffected.
    """
    capabilities = get_security_capabilities()
    analyzer = getattr(capabilities, "behavior_analyzer", None)
    if analyzer is None:
        return
    db = SessionLocal()
    try:
        assessment = analyzer.assess(
            db, user_id, "message_send", {"conversation_id": conversation_id}
        )
        if assessment:
            capabilities.event_sink.emit(
                db,
                event_type="behavior_risk",
                severity="warning" if assessment["level"] == "high" else "info",
                user_id=user_id,
                detail=f"behavior risk level={assessment['level']}",
                meta=assessment,
            )
    except Exception:
        logger.warning("behavior assessment failed", exc_info=True)
    finally:
        db.close()


@router.get("/conversation/{conversation_id}", response_model=ResponseModel[List[MessageResponse]])
def get_messages(
    conversation_id: int,
    limit: int = 50,
    before_id: Optional[int] = None,
    after_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get messages for a conversation the current user participates in.

    ``before_id`` returns older messages (used for infinite scroll);
    ``after_id`` returns newer messages (used for syncing local store).
    """
    conversation = db.query(Conversation).filter_by(id=conversation_id).first()
    if not conversation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="conversation not found",
        )

    if conversation.type == "friend":
        is_participant = current_user.id in {
            conversation.user_id,
            conversation.friend_user_id,
        }
        if not is_participant:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="not participant of this conversation",
            )
    elif conversation.type == "group":
        member = (
            db.query(GroupMember)
            .filter_by(group_id=conversation.group_id, user_id=current_user.id)
            .first()
        )
        if not member:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="not member of this group",
            )

    query = db.query(Message).filter_by(conversation_id=conversation_id)
    if after_id:
        # Newer messages: ascending order so they can be appended directly.
        messages = (
            query.filter(Message.id > after_id)
            .order_by(Message.created_at.asc())
            .limit(limit)
            .all()
        )
    else:
        if before_id:
            query = query.filter(Message.id < before_id)
        messages = query.order_by(Message.created_at.desc()).limit(limit).all()
        messages.reverse()

    results = []
    for msg in messages:
        sender: Optional[User] = msg.sender
        results.append(
            MessageResponse(
                id=msg.id,
                conversation_id=msg.conversation_id,
                sender_id=msg.sender_id,
                sender_nickname=sender.nickname if sender else None,
                sender_avatar_url=sender.avatar_url if sender else None,
                content=msg.content,
                extra=msg.extra,
                message_type=msg.message_type,
                created_at=msg.created_at,
            )
        )

    return ResponseModel(data=results)


@router.post("/send", response_model=ResponseModel[MessageResponse])
async def send_message(
    payload: MessageCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Send a message into a conversation and push it in real-time."""
    # Pass 1: synchronous send-time pre-check (confirmed-level block).
    # Runs in the threadpool so rule matching never blocks the event loop.
    try:
        precheck = await run_in_threadpool(
            send_precheck_service.precheck,
            db,
            current_user.id,
            payload.content,
            payload.message_type,
        )
    except PrecheckUnavailable as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="security check in progress, please retry",
        ) from exc

    if precheck.decision == ModerationDecision.BLOCK:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="message blocked by security policy",
        )

    try:
        message = await run_in_threadpool(
            message_service.send_message,
            db,
            sender=current_user,
            conversation_id=payload.conversation_id,
            message_type=payload.message_type,
            content=payload.content,
            extra=payload.extra,
            media_file_id=payload.media_file_id,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    # Push the message asynchronously without blocking the HTTP response
    background_tasks.add_task(message_service.broadcast_message, message.id)
    # Post-send behavior analysis (UEBA); profile-gated, failure-tolerant
    background_tasks.add_task(
        _assess_message_behavior, current_user.id, payload.conversation_id
    )

    results = []
    for msg in [message]:
        sender: Optional[User] = msg.sender
        results.append(
            MessageResponse(
                id=msg.id,
                conversation_id=msg.conversation_id,
                sender_id=msg.sender_id,
                sender_nickname=sender.nickname if sender else None,
                sender_avatar_url=sender.avatar_url if sender else None,
                content=msg.content,
                extra=msg.extra,
                message_type=msg.message_type,
                created_at=msg.created_at,
            )
        )
    return ResponseModel(data=results[0])

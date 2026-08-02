"""Message router."""

from typing import List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app.database import get_db
from app.dependencies.auth import get_current_user
from app.models import Conversation, Friendship, GroupMember, Message, User
from app.schemas.common import ResponseModel
from app.schemas.message import MessageCreate, MessageResponse
from app.services.message_service import message_service

router = APIRouter(prefix="/api/v1/messages", tags=["messages"])


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

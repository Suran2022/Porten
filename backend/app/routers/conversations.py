"""Conversations router."""

from typing import Optional

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.dependencies import get_current_user
from app.models import Message, User
from app.schemas.common import ResponseModel
from app.schemas.conversation import ConversationListResponse, ConversationResponse
from app.services import ConversationService


# Human-readable preview labels for non-text message types. The message
# `content` column for these types stores a URL or other opaque payload,
# which is meaningless as a chat-list preview, so we surface a fixed
# localized label instead.
_NON_TEXT_PREVIEW_LABELS = {
    "image": "[图片]",
    "video": "[视频]",
    "voice": "[语音]",
    "file": "[文件]",
}


def _format_last_message_preview(
    last_message: Optional[Message], current_user_id: int
) -> Optional[str]:
    """Format last-message preview shown on the chat list.

    - system: per-user view (e.g. "X加入营地" / "您已加入...营地...")
    - image / video / voice / file: fixed localized label
    - text: content as-is
    - anything else: "[消息]"
    """
    if last_message is None:
        return None

    msg_type = last_message.message_type or "text"

    if msg_type == "system":
        extra = last_message.extra or {}

        # 组建营地提示：仅创建者可见
        if extra.get("is_creation_notice") and extra.get("creator_id") is not None:
            if int(extra["creator_id"]) == current_user_id:
                return last_message.content
            return None

        # 新人加入营地提示：区分申请者与他人视角
        join_user_id = extra.get("join_user_id")
        group_name = extra.get("group_name")
        if join_user_id is not None and group_name is not None:
            if int(join_user_id) == current_user_id:
                return f"您已加入{group_name}营地，快来和大家分享您的故事趴！"
            join_user_name = extra.get("join_user_name") or "有人"
            return f"{join_user_name}加入营地"

        return last_message.content

    if msg_type in _NON_TEXT_PREVIEW_LABELS:
        return _NON_TEXT_PREVIEW_LABELS[msg_type]

    if msg_type == "text":
        return last_message.content

    return "[消息]"

router = APIRouter(prefix="/api/v1/conversations", tags=["conversations"])
conversation_service = ConversationService()


@router.get(
    "/",
    response_model=ResponseModel[ConversationListResponse],
    status_code=status.HTTP_200_OK,
)
def list_conversations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current user's conversation list."""
    conversations = conversation_service.list_conversations(db, current_user)

    # Batch load last messages to avoid N+1 queries.
    last_message_ids = [
        c.last_message_id for c in conversations if c.last_message_id is not None
    ]
    last_messages = {}
    if last_message_ids:
        last_messages = {
            m.id: m
            for m in db.query(Message).filter(Message.id.in_(last_message_ids)).all()
        }

    items = []
    for conversation in conversations:
        member_count = None
        friend_user_id = None
        if conversation.type == "friend":
            # The friend conversation is shared; show the other participant.
            if conversation.user_id == current_user.id:
                other = conversation.friend_user
                friend_user_id = conversation.friend_user_id
            else:
                other = conversation.user
                friend_user_id = conversation.user_id
            name = other.nickname if other else ""
            avatar = other.avatar_url if other else None
        else:
            name = conversation.group.name if conversation.group else ""
            avatar = conversation.group.avatar_url if conversation.group else None
            member_count = (
                conversation.group.member_count if conversation.group else None
            )

        last_message = last_messages.get(conversation.last_message_id)
        last_message_preview = _format_last_message_preview(
            last_message, current_user.id
        )
        # Fallback for legacy conversations that don't have last_message_id set.
        if last_message_preview is None:
            last_message_preview = conversation.last_message_text

        last_message_sender_id = None
        last_message_sender_name = None
        if last_message is not None:
            last_message_sender_id = last_message.sender_id
            last_message_sender_name = (
                last_message.sender.nickname if last_message.sender else None
            )

        unread_count = conversation_service._get_unread_count(
            db, current_user.id, conversation
        )
        items.append(
            ConversationResponse(
                id=conversation.id,
                type=conversation.type,
                name=name,
                avatar=avatar,
                last_message=last_message_preview,
                last_message_time=conversation.last_message_time,
                last_message_sender_id=last_message_sender_id,
                last_message_sender_name=last_message_sender_name,
                unread_count=unread_count,
                member_count=member_count,
                friend_user_id=friend_user_id,
            )
        )

    return ResponseModel(data=ConversationListResponse(conversations=items))


@router.post(
    "/{conversation_id}/read",
    response_model=ResponseModel,
    status_code=status.HTTP_200_OK,
)
def mark_conversation_read(
    conversation_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mark all messages in a conversation as read for the current user."""
    conversation_service.mark_read(db, current_user.id, conversation_id)
    db.commit()
    return ResponseModel(data=None)

"""Message business logic service."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session, joinedload

from app.database import SessionLocal
from app.models import Conversation, Friendship, GroupMember, MediaFile, Message, User
from app.schemas.message import MessageResponse
from app.services.websocket_manager import manager


class MessageService:
    """Service for sending, persisting and pushing messages."""

    def _is_participant(
        self, db: Session, conversation: Conversation, user_id: int
    ) -> bool:
        if conversation.type == "friend":
            return user_id in {
                conversation.user_id,
                conversation.friend_user_id,
            }
        if conversation.type == "group":
            return (
                db.query(GroupMember)
                .filter_by(group_id=conversation.group_id, user_id=user_id)
                .first()
                is not None
            )
        return False

    def _last_message_preview(self, message: Message) -> str:
        """Return a short preview for the conversation list."""
        if message.message_type == "text":
            return message.content or ""
        if message.message_type == "image":
            return "[图片]"
        if message.message_type == "video":
            return "[视频]"
        if message.message_type == "file":
            return message.content or "[文件]"
        if message.message_type == "voice":
            return "[语音]"
        if message.message_type == "system":
            return message.content or ""
        return "[消息]"

    def send_message(
        self,
        db: Session,
        sender: User,
        conversation_id: int,
        message_type: str,
        content: str,
        extra: Optional[dict] = None,
        media_file_id: Optional[int] = None,
    ) -> Message:
        """Persist a message, update conversation preview, and push it."""
        conversation = (
            db.query(Conversation).filter_by(id=conversation_id).first()
        )
        if not conversation:
            raise ValueError("conversation not found")

        if not self._is_participant(db, conversation, sender.id):
            raise ValueError("not participant of this conversation")

        message = Message(
            conversation_id=conversation_id,
            sender_id=sender.id,
            content=content,
            message_type=message_type,
            extra=extra,
            created_at=datetime.now(timezone.utc),
        )
        db.add(message)
        db.flush()  # populate message.id

        # Associate uploaded media file with this message
        if media_file_id:
            media = db.query(MediaFile).filter_by(id=media_file_id).first()
            if media and media.uploader_id == sender.id:
                media.message_id = message.id

        # Update conversation preview
        preview = self._last_message_preview(message)
        conversation.last_message_text = preview
        conversation.last_message_time = message.created_at
        conversation.last_message_id = message.id

        db.commit()
        db.refresh(message)
        return message

    async def broadcast_message(self, message_id: int) -> None:
        """Push a message to the conversation participants via WebSocket.

        Uses a fresh database session so the push can safely run as a
        background task after the HTTP response has been returned.
        """
        db = SessionLocal()
        try:
            message = (
                db.query(Message)
                .options(
                    joinedload(Message.conversation),
                    joinedload(Message.sender),
                )
                .filter_by(id=message_id)
                .first()
            )
            if not message:
                return

            conversation = message.conversation
            if not conversation:
                return

            user_ids: set[int] = set()
            if conversation.type == "friend":
                if conversation.user_id:
                    user_ids.add(conversation.user_id)
                if conversation.friend_user_id:
                    user_ids.add(conversation.friend_user_id)
            elif conversation.type == "group":
                members = (
                    db.query(GroupMember.user_id)
                    .filter_by(group_id=conversation.group_id)
                    .all()
                )
                user_ids.update(m.user_id for m in members)

            response = self._message_to_response(message)
            await manager.send_to_users(
                list(user_ids), {"type": "new_message", "data": response}
            )
        finally:
            db.close()

    def _message_to_response(self, message: Message) -> MessageResponse:
        sender = message.sender
        return MessageResponse(
            id=message.id,
            conversation_id=message.conversation_id,
            sender_id=message.sender_id,
            sender_nickname=sender.nickname if sender else None,
            sender_avatar_url=sender.avatar_url if sender else None,
            content=message.content,
            extra=message.extra,
            message_type=message.message_type,
            created_at=message.created_at,
        )


message_service = MessageService()

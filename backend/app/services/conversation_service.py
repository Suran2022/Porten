"""Conversation business logic service."""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import case, or_
from sqlalchemy.orm import Session

from app.models import Conversation, ConversationReadState, ConversationType, GroupMember, Message, User


class ConversationService:
    """Service for conversation listing and maintenance."""

    def _create_system_message(
        self,
        db: Session,
        conversation: Conversation,
        content: str,
    ) -> Message:
        """Create a system message in the given conversation."""
        now = datetime.now(timezone.utc)
        message = Message(
            conversation=conversation,
            sender_id=None,
            content=content,
            message_type="system",
            created_at=now,
        )
        db.add(message)
        conversation.last_message_time = now
        return message

    def _conversation_has_messages(self, db: Session, conversation: Conversation) -> bool:
        return (
            db.query(Message)
            .filter_by(conversation_id=conversation.id)
            .first()
            is not None
        )

    def ensure_friend_conversation(
        self,
        db: Session,
        user_id: int,
        friend_user_id: int,
        content: Optional[str] = None,
    ) -> Conversation:
        """
        Create or update a single shared friend conversation for the pair.

        Both participants query the same conversation row, so messages sent by
        either side are visible to the other without duplication.
        """
        a, b = (user_id, friend_user_id) if user_id <= friend_user_id else (friend_user_id, user_id)
        conversation = (
            db.query(Conversation)
            .filter_by(
                type=ConversationType.FRIEND.value,
                user_id=a,
                friend_user_id=b,
            )
            .first()
        )
        now = datetime.now(timezone.utc)
        if not conversation:
            conversation = Conversation(
                type=ConversationType.FRIEND.value,
                user_id=a,
                friend_user_id=b,
                last_message_text=content,
                last_message_time=now if content else None,
            )
            db.add(conversation)
            db.flush()

        if content and not self._conversation_has_messages(db, conversation):
            self._create_system_message(db, conversation, content)
            db.flush()

        return conversation

    def ensure_group_conversation(
        self,
        db: Session,
        group_id: int,
        last_message_text: Optional[str] = None,
    ) -> Conversation:
        """Create or update a group conversation."""
        conversation = (
            db.query(Conversation)
            .filter_by(type=ConversationType.GROUP.value, group_id=group_id)
            .first()
        )
        now = datetime.now(timezone.utc)
        if conversation:
            if last_message_text:
                conversation.last_message_text = last_message_text
                conversation.last_message_time = now
        else:
            conversation = Conversation(
                type=ConversationType.GROUP.value,
                group_id=group_id,
                last_message_text=last_message_text,
                last_message_time=now if last_message_text else None,
            )
            db.add(conversation)
        return conversation

    def update_last_message(
        self,
        db: Session,
        conversation_id: int,
        text: str,
        message_id: Optional[int] = None,
    ) -> Conversation:
        """Update the last message preview for a conversation."""
        conversation = db.query(Conversation).filter_by(id=conversation_id).first()
        if not conversation:
            raise ValueError("conversation not found")
        conversation.last_message_text = text
        conversation.last_message_time = datetime.now(timezone.utc)
        if message_id is not None:
            conversation.last_message_id = message_id
        db.commit()
        db.refresh(conversation)
        return conversation

    def _get_unread_count(
        self, db: Session, user_id: int, conversation: Conversation
    ) -> int:
        """Count messages in the conversation that the user has not read."""
        read_state = (
            db.query(ConversationReadState)
            .filter_by(user_id=user_id, conversation_id=conversation.id)
            .first()
        )
        last_read_id = read_state.last_read_message_id if read_state else None
        query = db.query(Message).filter(
            Message.conversation_id == conversation.id,
            Message.sender_id != user_id,
        )
        if last_read_id is not None:
            query = query.filter(Message.id > last_read_id)
        return query.count()

    def mark_read(
        self, db: Session, user_id: int, conversation_id: int
    ) -> None:
        """Mark all current messages in a conversation as read for the user."""
        latest_message = (
            db.query(Message)
            .filter_by(conversation_id=conversation_id)
            .order_by(Message.id.desc())
            .first()
        )
        latest_id = latest_message.id if latest_message else None

        read_state = (
            db.query(ConversationReadState)
            .filter_by(user_id=user_id, conversation_id=conversation_id)
            .first()
        )
        if read_state:
            read_state.last_read_message_id = latest_id
        else:
            db.add(
                ConversationReadState(
                    user_id=user_id,
                    conversation_id=conversation_id,
                    last_read_message_id=latest_id,
                )
            )

    def list_conversations(self, db: Session, user: User) -> list[Conversation]:
        """
        Return conversations relevant to the user.

        Includes shared friend conversations where the user is one of the two
        participants and group conversations for the user's groups, ordered by
        last message time desc.
        """
        group_ids = (
            db.query(GroupMember.group_id)
            .filter_by(user_id=user.id)
            .subquery()
        )

        friend_conversations = (
            db.query(Conversation)
            .filter(
                Conversation.type == ConversationType.FRIEND.value,
                or_(
                    Conversation.user_id == user.id,
                    Conversation.friend_user_id == user.id,
                ),
            )
        )
        group_conversations = (
            db.query(Conversation)
            .filter(
                Conversation.type == ConversationType.GROUP.value,
                Conversation.group_id.in_(group_ids),
            )
        )

        return (
            friend_conversations.union(group_conversations)
            .order_by(
                case((Conversation.last_message_time.is_(None), 1), else_=0),
                Conversation.last_message_time.desc(),
            )
            .all()
        )

"""Contact/friend business logic service."""

from typing import Optional

from sqlalchemy.orm import Session

from app.models import (
    FriendRequest,
    FriendRequestStatus,
    Friendship,
    User,
)
from app.services.conversation_service import ConversationService


class ContactService:
    """Service for friend search, requests, and contact list."""

    def __init__(self) -> None:
        self.conversation_service = ConversationService()

    def search_user_by_porten_id(
        self, db: Session, porten_id: str
    ) -> Optional[User]:
        """Find an active user by exact Porten ID."""
        return db.query(User).filter_by(porten_id=porten_id, is_active=True).first()

    def search_user_by_nickname(
        self, db: Session, current_user: User, nickname: str
    ) -> Optional[User]:
        """Fuzzy search users by nickname, but only return the current user."""
        if nickname.lower() in current_user.nickname.lower():
            return current_user
        return None

    def _friendship_exists(self, db: Session, user_id: int, friend_id: int) -> bool:
        return (
            db.query(Friendship)
            .filter_by(user_id=user_id, friend_id=friend_id)
            .first()
            is not None
        )

    def _create_friendship_pair(
        self, db: Session, user_id: int, friend_id: int
    ) -> None:
        """Create bidirectional friendship rows if they do not exist."""
        if user_id == friend_id:
            # Self-add: only one row is needed and allowed by the unique index.
            if not self._friendship_exists(db, user_id, friend_id):
                db.add(Friendship(user_id=user_id, friend_id=friend_id))
            return
        if not self._friendship_exists(db, user_id, friend_id):
            db.add(Friendship(user_id=user_id, friend_id=friend_id))
        if not self._friendship_exists(db, friend_id, user_id):
            db.add(Friendship(user_id=friend_id, friend_id=user_id))

    def send_friend_request(
        self,
        db: Session,
        sender: User,
        receiver_porten_id: str,
        message: Optional[str] = None,
    ) -> FriendRequest:
        """
        Send a friend request or auto-accept under special conditions.

        Returns the resulting FriendRequest (status may be pending or accepted).
        """
        if sender.porten_id == receiver_porten_id:
            # Adding self: create friendship and conversation immediately.
            self._create_friendship_pair(db, sender.id, sender.id)
            self_text = f"你与 {sender.nickname} 建立了同胞关系"
            self.conversation_service.ensure_friend_conversation(
                db,
                user_id=sender.id,
                friend_user_id=sender.id,
                content=self_text,
            )
            db.commit()
            existing = (
                db.query(FriendRequest)
                .filter(
                    FriendRequest.sender_id == sender.id,
                    FriendRequest.receiver_id == sender.id,
                )
                .order_by(FriendRequest.id.desc())
                .first()
            )
            if existing:
                existing.status = FriendRequestStatus.ACCEPTED.value
                db.commit()
                db.refresh(existing)
                return existing
            request = FriendRequest(
                sender_id=sender.id,
                receiver_id=sender.id,
                message=message,
                status=FriendRequestStatus.ACCEPTED.value,
                source="通过搜索 Porten 账号添加",
            )
            db.add(request)
            db.commit()
            db.refresh(request)
            return request

        receiver = self.search_user_by_porten_id(db, receiver_porten_id)
        if not receiver:
            raise ValueError("user not found")

        # Already sent pending request: return it.
        existing_sent = (
            db.query(FriendRequest)
            .filter_by(
                sender_id=sender.id,
                receiver_id=receiver.id,
                status=FriendRequestStatus.PENDING.value,
            )
            .first()
        )
        if existing_sent:
            return existing_sent

        # Receiver already sent a pending request to sender: auto accept.
        existing_received = (
            db.query(FriendRequest)
            .filter_by(
                sender_id=receiver.id,
                receiver_id=sender.id,
                status=FriendRequestStatus.PENDING.value,
            )
            .first()
        )
        if existing_received:
            existing_received.status = FriendRequestStatus.ACCEPTED.value
            self._create_friendship_pair(db, sender.id, receiver.id)
            self.conversation_service.ensure_friend_conversation(
                db,
                user_id=sender.id,
                friend_user_id=receiver.id,
                content=f"你与 {receiver.nickname} 建立了同胞关系",
            )
            db.commit()
            db.refresh(existing_received)
            return existing_received

        request = FriendRequest(
            sender_id=sender.id,
            receiver_id=receiver.id,
            message=message,
            status=FriendRequestStatus.PENDING.value,
            source="通过搜索 Porten 账号添加",
        )
        db.add(request)
        db.commit()
        db.refresh(request)
        return request

    def list_received_friend_requests(
        self, db: Session, user: User
    ) -> list[FriendRequest]:
        """Return pending friend requests received by the user."""
        return (
            db.query(FriendRequest)
            .filter_by(
                receiver_id=user.id,
                status=FriendRequestStatus.PENDING.value,
            )
            .order_by(FriendRequest.created_at.desc())
            .all()
        )

    def handle_friend_request(
        self, db: Session, user: User, request_id: int, action: str
    ) -> FriendRequest:
        """Accept or reject a received friend request."""
        request = (
            db.query(FriendRequest)
            .filter_by(id=request_id, receiver_id=user.id)
            .first()
        )
        if not request:
            raise ValueError("friend request not found")
        if request.status != FriendRequestStatus.PENDING.value:
            raise ValueError("request already handled")

        if action == "accept":
            request.status = FriendRequestStatus.ACCEPTED.value
            self._create_friendship_pair(db, user.id, request.sender_id)
            sender = db.query(User).filter_by(id=request.sender_id).first()
            sender_nickname = sender.nickname if sender else ""
            self.conversation_service.ensure_friend_conversation(
                db,
                user_id=user.id,
                friend_user_id=request.sender_id,
                content=f"你与 {sender_nickname} 建立了同胞关系",
            )
        else:
            request.status = FriendRequestStatus.REJECTED.value

        db.commit()
        db.refresh(request)
        return request

    def list_friends(self, db: Session, user: User) -> list[Friendship]:
        """Return all friendships where the user is the subject."""
        return (
            db.query(Friendship)
            .filter_by(user_id=user.id)
            .order_by(Friendship.created_at.desc())
            .all()
        )

    def get_friend_request_by_id(
        self, db: Session, request_id: int
    ) -> Optional[FriendRequest]:
        """Fetch a friend request by id."""
        return db.query(FriendRequest).filter_by(id=request_id).first()

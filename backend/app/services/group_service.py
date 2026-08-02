"""Group/camp business logic service."""

import asyncio
import random
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app.models import (
    Conversation,
    ConversationReadState,
    ConversationType,
    Group,
    GroupMember,
    GroupMemberRole,
    GroupRequest,
    GroupRequestStatus,
    GroupRequestType,
    Message,
    User,
)
from app.services.conversation_service import ConversationService
from app.services.message_service import message_service


def _generate_camp_id(db: Session, max_attempts: int = 100) -> str:
    """Generate a unique camp id like yd123456789 without digits 4 or 8."""
    allowed = [str(d) for d in range(10) if d not in (4, 8)]
    for _ in range(max_attempts):
        digits = "".join(random.choices(allowed, k=9))
        candidate = f"yd{digits}"
        exists = db.query(Group).filter_by(camp_id=candidate).first() is not None
        if not exists:
            return candidate
    raise RuntimeError("Unable to generate a unique camp id")


class GroupService:
    """Service for group search, requests, and membership."""

    def __init__(self) -> None:
        self.conversation_service = ConversationService()

    def create_group(
        self,
        db: Session,
        user: User,
        name: str,
        group_type: str,
        description: Optional[str] = None,
        avatar_url: Optional[str] = None,
        tags: Optional[list[str]] = None,
        discoverable_by: Optional[str] = None,
        max_members: Optional[int] = None,
    ) -> tuple[Group, int]:
        """Create a new camp (group) and set the creator as owner."""
        avatar = avatar_url or user.avatar_url
        searchable_by_name = discoverable_by in (None, "", "name")
        camp_id = _generate_camp_id(db)

        group = Group(
            owner_id=user.id,
            name=name,
            avatar_url=avatar,
            member_count=1,
            tags=",".join(tags) if tags else None,
            group_type=group_type,
            camp_id=camp_id,
            searchable_by_name=searchable_by_name,
            description=description,
            discoverable_by=discoverable_by,
            max_members=max_members,
        )
        db.add(group)
        db.flush()

        owner_member = GroupMember(
            group_id=group.id,
            user_id=user.id,
            role=GroupMemberRole.OWNER.value,
        )
        db.add(owner_member)

        conversation = Conversation(
            type=ConversationType.GROUP.value,
            group_id=group.id,
        )
        db.add(conversation)
        db.flush()

        now = datetime.now(timezone.utc)
        creation_text = f"您已成功组建{group.name}营地"
        creation_message = Message(
            conversation_id=conversation.id,
            sender_id=None,
            content=creation_text,
            message_type="system",
            created_at=now,
            extra={
                "creator_id": user.id,
                "group_name": group.name,
                "is_creation_notice": True,
            },
        )
        db.add(creation_message)
        db.flush()
        conversation.last_message_id = creation_message.id
        conversation.last_message_text = creation_text
        conversation.last_message_time = now
        db.flush()

        read_state = ConversationReadState(
            user_id=user.id,
            conversation_id=conversation.id,
        )
        db.add(read_state)

        db.commit()
        db.refresh(group)
        if creation_message:
            try:
                asyncio.get_running_loop().create_task(
                    message_service.broadcast_message(creation_message.id)
                )
            except RuntimeError:
                pass
        return group, conversation.id

    def update_group(
        self,
        db: Session,
        group: Group,
        user: User,
        name: Optional[str] = None,
        description: Optional[str] = None,
        avatar_url: Optional[str] = None,
        tags: Optional[list[str]] = None,
        discoverable_by: Optional[str] = None,
        max_members: Optional[int] = None,
    ) -> Group:
        """Update camp profile. Only owner or admin can edit."""
        member = (
            db.query(GroupMember)
            .filter_by(group_id=group.id, user_id=user.id)
            .first()
        )
        if not member or member.role not in (
            GroupMemberRole.OWNER.value,
            GroupMemberRole.ADMIN.value,
        ):
            raise ValueError("no permission to edit this camp")

        if name is not None:
            group.name = name
        if description is not None:
            group.description = description
        if avatar_url is not None:
            group.avatar_url = avatar_url
        if tags is not None:
            group.tags = ",".join(tags) if tags else None
        if discoverable_by is not None:
            group.discoverable_by = discoverable_by
            group.searchable_by_name = discoverable_by in ("", "name")
        if max_members is not None:
            group.max_members = max_members

        db.commit()
        db.refresh(group)
        return group

    def search_groups(
        self, db: Session, keyword: str, limit: int = 50
    ) -> list[Group]:
        """Search camps by name or camp id depending on discoverability settings.

        - Camps set to be discovered by name match on name (fuzzy).
        - Camps set to be discovered by camp id match on camp_id (fuzzy).
        - Camps set to not discoverable are excluded.
        """
        keyword = keyword.strip()
        if not keyword:
            return []

        like_pattern = f"%{keyword}%"
        name_searchable = or_(
            Group.discoverable_by.is_(None),
            Group.discoverable_by.in_(["", "name"]),
        )
        id_searchable = Group.discoverable_by == "id"

        return (
            db.query(Group)
            .filter(
                or_(
                    and_(name_searchable, Group.name.ilike(like_pattern)),
                    and_(id_searchable, Group.camp_id.ilike(like_pattern)),
                )
            )
            .order_by(Group.member_count.desc())
            .limit(limit)
            .all()
        )

    def get_group_by_id(self, db: Session, group_id: int) -> Optional[Group]:
        return db.query(Group).filter_by(id=group_id).first()

    def is_group_member(self, db: Session, group_id: int, user_id: int) -> bool:
        return (
            db.query(GroupMember)
            .filter_by(group_id=group_id, user_id=user_id)
            .first()
            is not None
        )

    def is_group_admin_or_owner(
        self, db: Session, group_id: int, user_id: int
    ) -> bool:
        member = db.query(GroupMember).filter_by(
            group_id=group_id, user_id=user_id
        ).first()
        if not member:
            return False
        return member.role in (
            GroupMemberRole.OWNER.value,
            GroupMemberRole.ADMIN.value,
        )

    def apply_join_group(
        self,
        db: Session,
        user: User,
        group_id: int,
        message: Optional[str] = None,
    ) -> GroupRequest:
        """Create a group application request."""
        group = self.get_group_by_id(db, group_id)
        if not group:
            raise ValueError("group not found")

        if self.is_group_member(db, group_id, user.id):
            raise ValueError("already a group member")

        existing = (
            db.query(GroupRequest)
            .filter_by(
                group_id=group_id,
                user_id=user.id,
                status=GroupRequestStatus.PENDING.value,
            )
            .first()
        )
        if existing:
            return existing

        request = GroupRequest(
            group_id=group_id,
            user_id=user.id,
            type=GroupRequestType.APPLY.value,
            message=message,
            status=GroupRequestStatus.PENDING.value,
        )
        db.add(request)
        db.commit()
        db.refresh(request)
        return request

    def list_received_group_requests(
        self, db: Session, user: User
    ) -> list[GroupRequest]:
        """Return pending group requests for groups managed by the user."""
        managed_group_ids = (
            db.query(GroupMember.group_id)
            .filter(
                GroupMember.user_id == user.id,
                GroupMember.role.in_(
                    [GroupMemberRole.OWNER.value, GroupMemberRole.ADMIN.value]
                ),
            )
            .subquery()
        )
        return (
            db.query(GroupRequest)
            .filter(
                GroupRequest.group_id.in_(managed_group_ids),
                GroupRequest.status == GroupRequestStatus.PENDING.value,
            )
            .order_by(GroupRequest.created_at.desc())
            .all()
        )

    def handle_group_request(
        self, db: Session, user: User, request_id: int, action: str
    ) -> GroupRequest:
        """Accept or reject a group membership request."""
        request = db.query(GroupRequest).filter_by(id=request_id).first()
        if not request:
            raise ValueError("group request not found")
        if request.status != GroupRequestStatus.PENDING.value:
            raise ValueError("request already handled")

        if not self.is_group_admin_or_owner(db, request.group_id, user.id):
            raise ValueError("permission denied")

        system_message = None
        group = None
        if action == "accept":
            request.status = GroupRequestStatus.ACCEPTED.value
            group = self.get_group_by_id(db, request.group_id)
            if not self.is_group_member(db, request.group_id, request.user_id):
                member = GroupMember(
                    group_id=request.group_id,
                    user_id=request.user_id,
                    role=GroupMemberRole.MEMBER.value,
                )
                db.add(member)
                # 确保新成员落库后再统计，避免缓存计数偏差。
                db.flush()

            if group:
                group.member_count = (
                    db.query(GroupMember)
                    .filter_by(group_id=group.id)
                    .count()
                )

                conversation = self.conversation_service.ensure_group_conversation(
                    db,
                    group_id=request.group_id,
                )
                now = datetime.now(timezone.utc)
                applicant_name = request.user.nickname if request.user else "有人"
                join_text = f"{applicant_name}加入营地"
                system_message = Message(
                    conversation_id=conversation.id,
                    sender_id=None,
                    content=join_text,
                    message_type="system",
                    created_at=now,
                    extra={
                        "join_user_id": request.user_id,
                        "join_user_name": applicant_name,
                        "group_name": group.name,
                    },
                )
                db.add(system_message)
                db.flush()
                conversation.last_message_id = system_message.id
                conversation.last_message_text = join_text
                conversation.last_message_time = now
        else:
            request.status = GroupRequestStatus.REJECTED.value

        db.commit()
        if group:
            db.refresh(group)
        db.refresh(request)
        if system_message:
            try:
                asyncio.get_running_loop().create_task(
                    message_service.broadcast_message(system_message.id)
                )
            except RuntimeError:
                pass
        return request

    def list_groups_for_user(self, db: Session, user: User) -> list[GroupMember]:
        """Return all group memberships for the user."""
        return (
            db.query(GroupMember)
            .filter_by(user_id=user.id)
            .order_by(GroupMember.created_at.desc())
            .all()
        )

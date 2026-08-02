"""Notification badge and read service."""

from sqlalchemy.orm import Session

from app.models import (
    FriendRequest,
    FriendRequestStatus,
    GroupMember,
    GroupMemberRole,
    GroupRequest,
    GroupRequestStatus,
    User,
)


class NotificationService:
    """Service for notification badge counts and marking read."""

    def get_badge_counts(self, db: Session, user: User) -> dict[str, int]:
        """Return pending friend and group request counts for the user."""
        friend_count = (
            db.query(FriendRequest)
            .filter_by(
                receiver_id=user.id,
                status=FriendRequestStatus.PENDING.value,
                viewed=False,
            )
            .count()
        )

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
        group_count = (
            db.query(GroupRequest)
            .filter(
                GroupRequest.group_id.in_(managed_group_ids),
                GroupRequest.status == GroupRequestStatus.PENDING.value,
                GroupRequest.viewed.is_(False),
            )
            .count()
        )

        return {"friend_requests": friend_count, "group_requests": group_count}

    def mark_read(self, db: Session, user: User, notification_type: str) -> None:
        """Mark all pending requests of the given type as viewed."""
        if notification_type == "friend":
            db.query(FriendRequest).filter_by(
                receiver_id=user.id,
                status=FriendRequestStatus.PENDING.value,
            ).update({"viewed": True}, synchronize_session=False)
        elif notification_type == "group":
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
            db.query(GroupRequest).filter(
                GroupRequest.group_id.in_(managed_group_ids),
                GroupRequest.status == GroupRequestStatus.PENDING.value,
            ).update({"viewed": True}, synchronize_session=False)
        db.commit()

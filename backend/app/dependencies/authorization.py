"""Object-level authorization helpers.

Centralizing object-level checks keeps authorization decisions out of
route bodies and consistent across routers. Missing and unauthorized
objects both return 404 so resource existence is not leaked.
"""

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models import Conversation, Group, GroupMember, User


def get_authorized_conversation(
    db: Session, conversation_id: int, current_user: User
) -> Conversation:
    """Return a conversation the current user participates in.

    Raises:
        HTTPException: 404 when the conversation does not exist or the
            user is not a participant.
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
    elif conversation.type == "group":
        is_participant = (
            db.query(GroupMember)
            .filter_by(group_id=conversation.group_id, user_id=current_user.id)
            .first()
            is not None
        )
    else:
        is_participant = False

    if not is_participant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="conversation not found",
        )

    return conversation


def get_authorized_group(db: Session, group_id: int, current_user: User) -> Group:
    """Return a group the current user is a member of.

    Raises:
        HTTPException: 404 when the group does not exist or the user is
            not a member.
    """
    group = db.query(Group).filter_by(id=group_id).first()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="group not found",
        )

    member = (
        db.query(GroupMember)
        .filter_by(group_id=group_id, user_id=current_user.id)
        .first()
    )
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="group not found",
        )

    return group

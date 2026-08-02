"""Pydantic schemas."""

from app.schemas.auth import (
    DefaultAvatarResponse,
    DefaultNicknameResponse,
    EmailCodeLoginRequest,
    EmailPasswordLoginRequest,
    LoginResponse,
    PortenIdLoginRequest,
    RegisterRequest,
    SendVerificationCodeRequest,
    TokenResponse,
    UserBriefResponse,
)
from app.schemas.common import (
    PaginatedResponse,
    PaginationMeta,
    PaginationParams,
    ResponseModel,
)
from app.schemas.conversation import (
    ConversationListResponse,
    ConversationResponse,
)
from app.schemas.contact import (
    ContactFriendResponse,
    ContactListResponse,
    FriendRequestResponse,
    HandleRequestRequest,
    SearchUserResponse,
    SendFriendRequestRequest,
)
from app.schemas.emotion_diary import (
    EmotionDiaryAuthorBrief,
    EmotionDiaryCreateRequest,
    EmotionDiaryListResponse,
    EmotionDiaryResponse,
    EmotionDiaryViewerItem,
    EmotionDiaryViewerListResponse,
    resolve_mood_label,
)
from app.schemas.group import (
    ContactGroupResponse,
    GroupMemberResponse,
    GroupRequestResponse,
    SearchGroupResponse,
    SendGroupRequestRequest,
)
from app.schemas.notification import BadgeResponse, ReadNotificationRequest
from app.schemas.user import UserProfileResponse

__all__ = [
    "ResponseModel",
    "PaginationParams",
    "PaginationMeta",
    "PaginatedResponse",
    "SendVerificationCodeRequest",
    "RegisterRequest",
    "EmailPasswordLoginRequest",
    "EmailCodeLoginRequest",
    "PortenIdLoginRequest",
    "TokenResponse",
    "UserBriefResponse",
    "LoginResponse",
    "DefaultAvatarResponse",
    "DefaultNicknameResponse",
    "UserProfileResponse",
    "SearchUserResponse",
    "SendFriendRequestRequest",
    "FriendRequestResponse",
    "HandleRequestRequest",
    "ContactFriendResponse",
    "ContactListResponse",
    "SearchGroupResponse",
    "SendGroupRequestRequest",
    "GroupRequestResponse",
    "GroupMemberResponse",
    "ContactGroupResponse",
    "ConversationResponse",
    "ConversationListResponse",
    "BadgeResponse",
    "ReadNotificationRequest",
    "EmotionDiaryAuthorBrief",
    "EmotionDiaryCreateRequest",
    "EmotionDiaryListResponse",
    "EmotionDiaryResponse",
    "EmotionDiaryViewerItem",
    "EmotionDiaryViewerListResponse",
    "resolve_mood_label",
]

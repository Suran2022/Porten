"""API routers."""

from app.routers.agreements import router as agreements_router
from app.routers.assistants import router as assistants_router
from app.routers.auth import router as auth_router
from app.routers.conversations import router as conversations_router
from app.routers.contacts import router as contacts_router
from app.routers.emotion_diary import router as emotion_diary_router
from app.routers.friend_requests import router as friend_requests_router
from app.routers.groups import router as groups_router
from app.routers.messages import router as messages_router
from app.routers.notifications import router as notifications_router
from app.routers.search import router as search_router
from app.routers.system_messages import router as system_messages_router
from app.routers.upload import router as upload_router
from app.routers.user import router as user_router
from app.routers.websocket import router as websocket_router

__all__ = [
    "agreements_router",
    "assistants_router",
    "auth_router",
    "user_router",
    "contacts_router",
    "friend_requests_router",
    "groups_router",
    "conversations_router",
    "messages_router",
    "notifications_router",
    "system_messages_router",
    "upload_router",
    "websocket_router",
    "emotion_diary_router",
    "search_router",
]

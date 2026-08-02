"""FastAPI application entry point."""

import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import ValidationError

from app.config import get_settings
from app.database import engine
from app.database import SessionLocal
from app.models import Base, Friendship, User
from app.routers import (
    agreements_router,
    assistants_router,
    auth_router,
    contacts_router,
    conversations_router,
    emotion_diary_router,
    friend_requests_router,
    groups_router,
    messages_router,
    notifications_router,
    search_router,
    system_messages_router,
    upload_router,
    user_router,
    websocket_router,
)
from app.schemas.common import ResponseModel
from app.services.conversation_service import ConversationService
from app.services.media_cleanup import cleanup_expired_media_task
from app.services.assistant_article_service import AssistantArticleService
from app.services.system_message_service import SystemMessageService

settings = get_settings()
conversation_service = ConversationService()


def _ensure_friendship_conversations() -> None:
    """Create shared conversations for existing friendships on startup."""
    db = SessionLocal()
    try:
        friendships = db.query(Friendship).all()
        for friendship in friendships:
            friend = db.query(User).filter_by(id=friendship.friend_id).first()
            nickname = friend.nickname if friend else ""
            content = (
                f"你与 {nickname} 建立了同胞关系"
                if nickname
                else "你们已建立同胞关系"
            )
            conversation_service.ensure_friend_conversation(
                db,
                user_id=friendship.user_id,
                friend_user_id=friendship.friend_id,
                content=content,
            )
        db.commit()
    finally:
        db.close()


conversation_service = ConversationService()
system_message_service = SystemMessageService()
assistant_article_service = AssistantArticleService()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create database tables on startup and start background tasks."""
    Base.metadata.create_all(bind=engine)

    # Seed built-in system messages on every startup so new versions are
    # published automatically.
    db = SessionLocal()
    try:
        system_message_service.seed_system_messages(db)
        assistant_article_service.seed_articles(db)
    finally:
        db.close()

    _ensure_friendship_conversations()
    asyncio.create_task(cleanup_expired_media_task())
    yield


app = FastAPI(
    title=settings.app_name,
    description="Porten backend API",
    version="0.1.0",
    lifespan=lifespan,
    redirect_slashes=False,
)

# CORS for future frontend and admin dashboard integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


async def _build_validation_response(exc):
    """Build a unified validation error response."""
    errors = []
    for err in exc.errors():
        errors.append(
            {
                "loc": err.get("loc"),
                "msg": err.get("msg"),
                "type": err.get("type"),
            }
        )
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=jsonable_encoder(
            ResponseModel(
                code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                message="validation error",
                data={"errors": errors},
            )
        ),
    )


@app.exception_handler(RequestValidationError)
async def request_validation_exception_handler(request: Request, exc: RequestValidationError):
    """Return a unified response for request validation errors."""
    return await _build_validation_response(exc)


@app.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    """Return a unified response for Pydantic validation errors."""
    return await _build_validation_response(exc)


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Return a unified response for HTTP exceptions."""
    return JSONResponse(
        status_code=exc.status_code,
        content=jsonable_encoder(
            ResponseModel(
                code=exc.status_code,
                message=exc.detail,
                data=None,
            )
        ),
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Catch-all handler to avoid leaking internal errors."""
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=jsonable_encoder(
            ResponseModel(
                code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                message="internal server error",
                data=None,
            )
        ),
    )


@app.get("/health", tags=["health"])
def health_check():
    """Simple health check endpoint."""
    return {"status": "ok"}


# Register routers
app.include_router(auth_router)
app.include_router(agreements_router)
app.include_router(assistants_router)
app.include_router(user_router)
app.include_router(contacts_router)
app.include_router(friend_requests_router)
app.include_router(groups_router)
app.include_router(conversations_router)
app.include_router(messages_router)
app.include_router(notifications_router)
app.include_router(system_messages_router)
app.include_router(upload_router)
app.include_router(emotion_diary_router)
app.include_router(search_router)
app.include_router(websocket_router)

# Serve uploaded media files
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

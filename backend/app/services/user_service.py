"""User business logic service."""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import Friendship, User
from app.models.user import CIS_GENDERS
from app.schemas.auth import LoginResponse, TokenResponse, UserBriefResponse
from app.services.porten_id_service import PortenIdService
from app.utils.security import create_access_token, hash_password, verify_password

settings = get_settings()


class UserService:
    """Service for user registration, login, and profile retrieval."""

    def __init__(self) -> None:
        self.porten_service = PortenIdService()

    def get_user_by_email(self, db: Session, email: str) -> Optional[User]:
        """Fetch a user by email address."""
        return db.query(User).filter_by(email=email, is_active=True).first()

    def get_user_by_porten_id(self, db: Session, porten_id: str) -> Optional[User]:
        """Fetch a user by Porten account number."""
        return db.query(User).filter_by(porten_id=porten_id, is_active=True).first()

    def get_user_by_id(self, db: Session, user_id: int) -> Optional[User]:
        """Fetch a user by primary key."""
        return db.query(User).filter_by(id=user_id, is_active=True).first()

    def update_nickname(self, db: Session, user: User, nickname: str) -> User:
        """Update user nickname."""
        user.nickname = nickname
        db.commit()
        db.refresh(user)
        return user

    def update_avatar(self, db: Session, user: User, avatar_url: str) -> User:
        """Update user avatar URL."""
        user.avatar_url = avatar_url
        db.commit()
        db.refresh(user)
        return user

    def update_background(self, db: Session, user: User, background_url: str) -> User:
        """Update user profile background URL."""
        user.background_url = background_url
        db.commit()
        db.refresh(user)
        return user

    def update_profile(
        self,
        db: Session,
        user: User,
        nickname: Optional[str] = None,
        avatar_url: Optional[str] = None,
        background_url: Optional[str] = None,
        gender: Optional[str] = None,
    ) -> User:
        """Update multiple profile fields."""
        if nickname is not None:
            user.nickname = nickname
        if avatar_url is not None:
            user.avatar_url = avatar_url
        if background_url is not None:
            user.background_url = background_url
        if gender is not None:
            user.gender = gender
        db.commit()
        db.refresh(user)
        return user

    def get_friend_count(self, db: Session, user_id: int) -> int:
        """Return the number of accepted friendships for the user."""
        return (
            db.query(func.count(Friendship.id))
            .filter(
                (Friendship.user_id == user_id)
                & (Friendship.friend_id != user_id)
            )
            .scalar()
            or 0
        )

    def get_trans_days(self, user: User) -> int:
        """Return days since registration if the user is not cisgender, else 0."""
        if not user.gender or user.gender in CIS_GENDERS:
            return 0
        created_at = user.created_at
        if created_at is None:
            return 0
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)
        return max(0, (datetime.now(timezone.utc) - created_at).days)

    def register(
        self,
        db: Session,
        email: str,
        password: str,
    ) -> User:
        """
        Create a new user with a generated Porten ID and default profile.

        Raises:
            ValueError: If the email is already registered.
        """
        if self.get_user_by_email(db, email):
            raise ValueError("email already registered")

        porten_id = self.porten_service.generate_unique(db)
        user = User(
            email=email,
            password_hash=hash_password(password),
            porten_id=porten_id,
            nickname=porten_id,
            avatar_url=settings.default_avatar_url,
            email_verified=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    def authenticate_by_password(self, db: Session, email: str, password: str) -> User:
        """Authenticate a user by email and password."""
        user = self.get_user_by_email(db, email)
        if not user:
            raise ValueError("invalid email or password")
        if not user.password_hash:
            raise ValueError("please use email verification code to login")
        if not verify_password(password, user.password_hash):
            raise ValueError("invalid email or password")
        return user

    def authenticate_by_porten_id(
        self, db: Session, porten_id: str, password: str
    ) -> User:
        """Authenticate a user by Porten ID and password."""
        user = self.get_user_by_porten_id(db, porten_id)
        if not user:
            raise ValueError("invalid Porten ID or password")
        if not user.password_hash:
            raise ValueError("please use email verification code to login")
        if not verify_password(password, user.password_hash):
            raise ValueError("invalid Porten ID or password")
        return user

    def build_login_response(self, user: User) -> LoginResponse:
        """Build a login response with JWT token and user info."""
        token = create_access_token({"sub": str(user.id), "tv": user.token_version})
        return LoginResponse(
            token=TokenResponse(
                access_token=token,
                token_type="bearer",
                expires_in=settings.access_token_expire_minutes * 60,
            ),
            user=UserBriefResponse.model_validate(user),
        )

    def logout(self, db: Session, user: User) -> User:
        """Invalidate all existing tokens by incrementing token_version."""
        user.token_version += 1
        db.commit()
        db.refresh(user)
        return user

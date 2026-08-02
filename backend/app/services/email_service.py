"""Email service for sending verification codes."""

import logging
import random
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage

import aiosmtplib
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from app.config import get_settings
from app.models import VerificationCode

settings = get_settings()


class EmailService:
    """Service for sending verification code emails."""

    CODE_LENGTH = 6
    CODE_TTL_MINUTES = 10
    RESEND_COOLDOWN_SECONDS = 60

    def __init__(self) -> None:
        self.host = settings.smtp_host
        self.port = settings.smtp_port
        self.username = settings.smtp_username
        self.password = settings.smtp_password
        self.sender = settings.sender_address

    def _generate_code(self) -> str:
        """Generate a numeric verification code."""
        return "".join(random.choices("0123456789", k=self.CODE_LENGTH))

    @staticmethod
    def _ensure_utc(value: datetime) -> datetime:
        """Ensure a datetime is timezone-aware in UTC."""
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value

    def _can_send(self, db: Session, email: str, purpose: str) -> bool:
        """Check if enough time has passed since the last code was sent."""
        latest = (
            db.query(VerificationCode)
            .filter_by(email=email, purpose=purpose)
            .order_by(VerificationCode.created_at.desc())
            .first()
        )
        if not latest:
            return True
        cooldown_end = self._ensure_utc(latest.created_at) + timedelta(
            seconds=self.RESEND_COOLDOWN_SECONDS
        )
        return datetime.now(timezone.utc) >= cooldown_end

    def create_verification_code(self, db: Session, email: str, purpose: str) -> str:
        """
        Generate and persist a verification code.

        Raises:
            ValueError: If the resend cooldown has not elapsed.
        """
        if not self._can_send(db, email, purpose):
            raise ValueError("please wait before requesting a new code")

        code = self._generate_code()
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=self.CODE_TTL_MINUTES)

        record = VerificationCode(
            email=email,
            code=code,
            purpose=purpose,
            expires_at=expires_at,
            used=False,
        )
        db.add(record)
        db.commit()
        return code

    async def send_verification_email(self, recipient: str, code: str) -> None:
        """Send the verification code email via SMTP."""
        message = EmailMessage()
        message["From"] = self.sender
        message["To"] = recipient
        message["Subject"] = f"[{settings.app_name}] 您的验证码"
        message.set_content(
            f"您好，\n\n"
            f"您的验证码是：{code}\n"
            f"验证码将在 {self.CODE_TTL_MINUTES} 分钟后失效，请勿泄露给他人。\n\n"
            f"如非本人操作，请忽略此邮件。\n\n"
            f"{settings.app_name} 团队"
        )

        await aiosmtplib.send(
            message,
            hostname=self.host,
            port=self.port,
            username=self.username,
            password=self.password,
            use_tls=True,
            timeout=10,
        )

    async def send_agreement_email(self, recipient: str, subject: str, html_body: str) -> None:
        """Send an agreement email as HTML via SMTP."""
        message = EmailMessage()
        message["From"] = self.sender
        message["To"] = recipient
        message["Subject"] = subject
        message.set_content(
            "您好，这是 Porten 平台发送的协议文本。"
            "如无法查看 HTML 格式，请访问 https://your-domain.com 查看相关协议。\n\n"
            "Porten 团队"
        )
        message.add_alternative(html_body, subtype="html")

        await aiosmtplib.send(
            message,
            hostname=self.host,
            port=self.port,
            username=self.username,
            password=self.password,
            use_tls=True,
            timeout=10,
        )

    def verify_code(self, db: Session, email: str, code: str, purpose: str) -> bool:
        """
        Validate a verification code without consuming it.

        Call consume_code after the dependent operation succeeds.
        """
        record = (
            db.query(VerificationCode)
            .filter_by(email=email, purpose=purpose, used=False)
            .order_by(VerificationCode.created_at.desc())
            .first()
        )
        if not record:
            return False
        expires_at = self._ensure_utc(record.expires_at)
        if expires_at < datetime.now(timezone.utc):
            return False
        return record.code == code

    def consume_code(self, db: Session, email: str, code: str, purpose: str) -> bool:
        """Mark a verification code as used."""
        record = (
            db.query(VerificationCode)
            .filter_by(email=email, purpose=purpose, code=code, used=False)
            .order_by(VerificationCode.created_at.desc())
            .first()
        )
        if not record:
            return False
        record.used = True
        db.commit()
        return True

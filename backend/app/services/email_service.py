"""Email service for sending verification codes."""

import logging
import secrets
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage

import aiosmtplib
import httpx
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
    # Cap failed verification attempts per code so the 6-digit space
    # cannot be brute-forced against a single issued code.
    MAX_VERIFY_ATTEMPTS = 5

    def __init__(self) -> None:
        self.host = settings.smtp_host
        self.port = settings.smtp_port
        self.username = settings.smtp_username
        self.password = settings.smtp_password
        self.sender = settings.sender_address
        self.use_resend_api = settings.use_resend_api

    async def _send_via_resend(
        self,
        recipient: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
    ) -> None:
        """Send an email via the Resend HTTPS API (port 443).

        Railway and comparable platforms block outbound SMTP ports, so the
        HTTP API is the supported delivery path there.
        """
        payload: dict = {
            "from": settings.resend_sender,
            "to": [recipient],
            "subject": subject,
            "text": text_body,
        }
        if html_body:
            payload["html"] = html_body
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                "https://api.resend.com/emails",
                headers={"Authorization": f"Bearer {settings.resend_api_key}"},
                json=payload,
            )
        if response.status_code >= 400:
            raise RuntimeError(
                f"Resend API rejected the message: "
                f"{response.status_code} {response.text}"
            )
        # 应用未配置 logging 级别，root logger 默认只输出 WARNING+，
        # 故成功记录用 warning 级以保证在 Railway 日志可见。
        logger.warning(
            "email sent via Resend API to %s (id=%s)", recipient, response.json().get("id")
        )

    def _generate_code(self) -> str:
        """Generate a numeric verification code using a CSPRNG."""
        return "".join(
            secrets.choice("0123456789") for _ in range(self.CODE_LENGTH)
        )

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
        """Send the verification code email (Resend API if configured, else SMTP)."""
        subject = f"[{settings.app_name}] 您的验证码"
        text_body = (
            f"您好，\n\n"
            f"您的验证码是：{code}\n"
            f"验证码将在 {self.CODE_TTL_MINUTES} 分钟后失效，请勿泄露给他人。\n\n"
            f"如非本人操作，请忽略此邮件。\n\n"
            f"{settings.app_name} 团队"
        )
        if self.use_resend_api:
            await self._send_via_resend(recipient, subject, text_body)
            return

        message = EmailMessage()
        message["From"] = self.sender
        message["To"] = recipient
        message["Subject"] = subject
        message.set_content(text_body)

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
        """Send an agreement email as HTML (Resend API if configured, else SMTP)."""
        text_body = (
            "您好，这是 Porten 平台发送的协议文本。"
            "如无法查看 HTML 格式，请访问 https://your-domain.com 查看相关协议。\n\n"
            "Porten 团队"
        )
        if self.use_resend_api:
            await self._send_via_resend(recipient, subject, text_body, html_body)
            return

        message = EmailMessage()
        message["From"] = self.sender
        message["To"] = recipient
        message["Subject"] = subject
        message.set_content(text_body)
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

        Each failed attempt is counted; after MAX_VERIFY_ATTEMPTS the
        code stops validating and a new one must be requested.

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
        if record.attempts >= self.MAX_VERIFY_ATTEMPTS:
            return False
        if record.code == code:
            return True
        record.attempts += 1
        db.commit()
        return False

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

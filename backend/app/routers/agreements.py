"""Agreement related routers."""

import logging
import time
from typing import Dict

from fastapi import APIRouter, BackgroundTasks, HTTPException, status

from app.schemas.agreements import SendAgreementEmailRequest
from app.schemas.common import ResponseModel
from app.services import EmailService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/agreements", tags=["agreements"])
email_service = EmailService()

# Simple in-memory cooldown per recipient to prevent abuse.
_last_sent: Dict[str, float] = {}
_AGREEMENT_EMAIL_COOLDOWN_SECONDS = 60


async def _background_send_agreement_email(
    recipient: str, subject: str, html_body: str
) -> None:
    """Background task: try to send the agreement email and log failures."""
    try:
        await email_service.send_agreement_email(recipient, subject, html_body)
    except Exception:
        logger.exception("background agreement email failed for %s", recipient)


@router.post(
    "/send-email",
    response_model=ResponseModel[dict],
    status_code=status.HTTP_200_OK,
)
def send_agreement_email(
    payload: SendAgreementEmailRequest,
    background_tasks: BackgroundTasks,
):
    """Send an agreement HTML email to the specified recipient."""
    now = time.time()
    last_sent = _last_sent.get(payload.recipient, 0)
    if now - last_sent < _AGREEMENT_EMAIL_COOLDOWN_SECONDS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="请稍后再试",
        )

    _last_sent[payload.recipient] = now
    background_tasks.add_task(
        _background_send_agreement_email,
        payload.recipient,
        payload.subject,
        payload.html_body,
    )
    return ResponseModel(data={"sent": True})

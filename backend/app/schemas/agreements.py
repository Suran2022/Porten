"""Agreement related schemas."""

from pydantic import BaseModel, EmailStr, Field


class SendAgreementEmailRequest(BaseModel):
    """Request to send an agreement HTML email to a recipient."""

    recipient: EmailStr
    subject: str = Field(..., min_length=1, max_length=256)
    html_body: str = Field(..., min_length=1, max_length=500_000)

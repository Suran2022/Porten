"""Device binding service for token-device binding.

Bindings are upserted at login and checked on every authenticated
request when the token carries a ``did`` claim. Tokens issued before
device binding was introduced carry no claim and are accepted as-is,
so the rollout is backward compatible.
"""

from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.models import DeviceSession, User


class DeviceBindingService:
    """Bind issued tokens to client device identifiers."""

    def bind_device(
        self,
        db: Session,
        user: User,
        device_id: str,
        device_name: Optional[str] = None,
        platform: Optional[str] = None,
    ) -> DeviceSession:
        """Create or refresh the device binding for a login."""
        record = (
            db.query(DeviceSession)
            .filter_by(user_id=user.id, device_id=device_id)
            .first()
        )
        if record:
            record.device_name = device_name or record.device_name
            record.platform = platform or record.platform
            record.last_seen_at = datetime.now(timezone.utc)
            # A re-login reactivates a previously revoked binding.
            record.revoked = False
        else:
            record = DeviceSession(
                user_id=user.id,
                device_id=device_id,
                device_name=device_name,
                platform=platform,
                last_seen_at=datetime.now(timezone.utc),
            )
            db.add(record)
        db.commit()
        db.refresh(record)
        return record

    def is_device_valid(self, db: Session, user_id: int, device_id: str) -> bool:
        """Return True when the device binding exists and is not revoked."""
        record = (
            db.query(DeviceSession)
            .filter_by(user_id=user_id, device_id=device_id)
            .first()
        )
        return record is not None and not record.revoked

    def revoke_device(self, db: Session, user_id: int, device_id: str) -> bool:
        """Revoke a single device binding; returns True when updated."""
        record = (
            db.query(DeviceSession)
            .filter_by(user_id=user_id, device_id=device_id)
            .first()
        )
        if not record or record.revoked:
            return False
        record.revoked = True
        db.commit()
        return True

    def touch_device(
        self,
        db: Session,
        user_id: int,
        device_id: str,
        min_interval_seconds: int = 300,
    ) -> None:
        """Update last_seen_at at most once per interval; failures are non-fatal."""
        try:
            record = (
                db.query(DeviceSession)
                .filter_by(user_id=user_id, device_id=device_id)
                .first()
            )
            if not record or record.revoked:
                return
            now = datetime.now(timezone.utc)
            last = record.last_seen_at
            if last is not None:
                if last.tzinfo is None:
                    last = last.replace(tzinfo=timezone.utc)
                if (now - last).total_seconds() < min_interval_seconds:
                    return
            record.last_seen_at = now
            db.commit()
        except Exception:
            db.rollback()


device_binding_service = DeviceBindingService()

"""Timezone-aware datetime helpers for display formatting.

All timestamps are stored in UTC; user-facing strings are rendered in
the configured ``APP_TIMEZONE`` (default Asia/Shanghai).
"""

from datetime import datetime, timedelta, timezone
from typing import Optional

from zoneinfo import ZoneInfo

from app.config import get_settings


def local_zone() -> ZoneInfo:
    """Return the configured display timezone."""
    return ZoneInfo(get_settings().app_timezone)


def local_now() -> datetime:
    """Return the current time in the display timezone."""
    return datetime.now(timezone.utc).astimezone(local_zone())


def to_local(value: Optional[datetime]) -> Optional[datetime]:
    """Convert a UTC datetime to the display timezone."""
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(local_zone())


def as_utc(value: Optional[datetime]) -> Optional[datetime]:
    """Normalize a datetime to aware UTC.

    Naive values (some drivers, e.g. SQLite, drop tzinfo on read) are
    assumed to already be UTC.
    """
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def format_hm(value: Optional[datetime]) -> Optional[str]:
    """Format a datetime as HH:mm in the display timezone."""
    local = to_local(value)
    if local is None:
        return None
    return local.strftime("%H:%M")


def format_note_time(value: Optional[datetime]) -> str:
    """Format a note timestamp as the mock display string.

    Today -> ``今天 HH:mm``; yesterday -> ``昨天 HH:mm``;
    older -> ``M月D日 HH:mm``.
    """
    local = to_local(value)
    if local is None:
        return ""
    now = local_now()
    hm = local.strftime("%H:%M")
    if local.date() == now.date():
        return f"今天 {hm}"
    if local.date() == now.date() - timedelta(days=1):
        return f"昨天 {hm}"
    return f"{local.month}月{local.day}日 {hm}"


def format_day_offset(days: int) -> str:
    """Describe a whole-day offset the way the mock titles do.

    0 -> ``今天``; 1 -> ``明天``; N -> ``N天后``.
    """
    if days <= 0:
        return "今天"
    if days == 1:
        return "明天"
    return f"{days}天后"

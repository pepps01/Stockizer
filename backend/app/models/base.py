import uuid
from datetime import datetime, timezone
from decimal import Decimal


def new_uuid() -> str:
    return str(uuid.uuid4())


def utcnow() -> datetime:
    """Naive UTC timestamp. MySQL DATETIME has no timezone, so everything is
    stored as UTC and serialised with an explicit 'Z' suffix."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def iso(value: datetime | None) -> str | None:
    return value.isoformat() + "Z" if value else None


def num(value) -> float | None:
    if value is None:
        return None
    return float(value) if isinstance(value, Decimal) else value

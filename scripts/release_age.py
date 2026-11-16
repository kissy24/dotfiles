"""Shared age decision. Adapters supply publication evidence or None."""
import datetime as dt

COOLDOWN_SECONDS = 7 * 86400


def epoch(value):
    if not isinstance(value, str) or not value:
        raise ValueError("Publication time must be an ISO 8601 string")
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("Publication time must include a timezone")
    return int(parsed.timestamp())


def age_error(key, published_at, now):
    if published_at is None:
        return key + ": published_at=null; automatic update held for manual review"
    age = now - epoch(published_at)
    if age < 0:
        return key + ": publication/observation time is in the future"
    if age < COOLDOWN_SECONDS:
        ready = dt.datetime.fromtimestamp(epoch(published_at) + COOLDOWN_SECONDS, dt.timezone.utc)
        return key + ": waiting until " + ready.isoformat()
    return None

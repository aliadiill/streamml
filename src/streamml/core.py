"""Pure transaction validation, feature extraction and deterministic serialization."""
import hashlib
import json
import math
import re
from datetime import datetime, timezone

FIELDS = {"event_id", "occurred_at", "card_id", "amount_cents", "distance_km",
          "attempts_1h", "merchant_risk", "online", "fraud_label"}
ID = re.compile(r"^[a-zA-Z0-9_-]{1,80}$")


class InvalidEvent(ValueError):
    pass


def validate(event):
    if not isinstance(event, dict) or set(event) != FIELDS:
        raise InvalidEvent("Unexpected or missing schema fields")
    for name in ("event_id", "card_id"):
        if not isinstance(event[name], str) or not ID.fullmatch(event[name]):
            raise InvalidEvent(f"Invalid {name}")
    if not isinstance(event["occurred_at"], str):
        raise InvalidEvent("Invalid timestamp")
    try:
        timestamp = datetime.fromisoformat(event["occurred_at"].replace("Z", "+00:00"))
        if timestamp.tzinfo is None:
            raise ValueError("Timezone required")
        timestamp = timestamp.astimezone(timezone.utc)
    except ValueError as exc:
        raise InvalidEvent("Invalid timezone-aware timestamp") from exc
    if not 2020 <= timestamp.year <= 2100:
        raise InvalidEvent("Timestamp out of range")
    ranges = {"amount_cents": (1, 10000000), "distance_km": (0, 20000),
              "attempts_1h": (1, 100), "merchant_risk": (0, 1)}
    for name, (low, high) in ranges.items():
        value = event[name]
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not low <= value <= high:
            raise InvalidEvent(f"Invalid {name}")
    for name in ("amount_cents", "attempts_1h", "online", "fraud_label"):
        if type(event[name]) is not int:
            raise InvalidEvent(f"{name} must be an integer")
    if event["online"] not in (0, 1) or event["fraud_label"] not in (0, 1):
        raise InvalidEvent("Invalid binary field")
    return {**event, "occurred_at": timestamp.isoformat(timespec="microseconds").replace("+00:00", "Z")}


def canonical(event):
    return json.dumps(event, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def digest(event):
    return hashlib.sha256(canonical(event)).hexdigest()


def minute(event):
    return event["occurred_at"][:16]


def rule_anomaly(event):
    """Bootstrap business rule, explicitly distinct from the approved ML model."""
    return int(event["amount_cents"] > 100000 and
               (event["distance_km"] > 800 or event["attempts_1h"] >= 6))

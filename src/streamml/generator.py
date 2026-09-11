"""Synthetic labelled transactions. No real cardholder or payment information."""
import argparse
import json
import random
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path


def generate(count=3000, seed=42, start="2026-01-01T00:00:00Z", drift=False, interval_seconds=2.0):
    if not 1 <= count <= 10000:
        raise ValueError("count must be between 1 and 10000")
    rng = random.Random(seed)
    base = datetime.fromisoformat(start.replace("Z", "+00:00"))
    for index in range(count):
        fraud = int(rng.random() < 0.12)
        # Overlapping populations make the task imperfect rather than label-copying.
        amount = rng.lognormvariate(8.0 + fraud * 2.0 + (1.5 if drift else 0), 0.9)
        yield {
            "event_id": uuid.uuid5(uuid.NAMESPACE_URL, f"streamml:{seed}:{start}:{index}").hex,
            "occurred_at": (base + timedelta(seconds=index * interval_seconds)).astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
            "card_id": f"synthetic-{rng.randrange(250):04d}",
            "amount_cents": min(10000000, max(1, int(amount))),
            "distance_km": round(min(20000, rng.expovariate(1 / (900 if fraud else 80))), 2),
            "attempts_1h": min(100, 1 + int(rng.expovariate(1 / (5 if fraud else 1)))),
            "merchant_risk": round(min(1, max(0, rng.gauss(.65 if fraud else .25, .18))), 4),
            "online": int(rng.random() < (.95 if fraud else .6)),
            "fraud_label": fraud,
        }


def publish(client, stream, events, rate=10):
    if not 1 <= rate <= 25:
        raise ValueError("rate must be 1..25 events/second")
    sent = 0
    for event in events:
        # PutRecord avoids losing partial failures; bounded retries preserve the event ID.
        for attempt in range(4):
            try:
                client.put_record(StreamName=stream, PartitionKey=event["card_id"],
                                  Data=(json.dumps(event) + "\n").encode())
                break
            except Exception:
                if attempt == 3:
                    raise
                time.sleep(2 ** attempt / 2)
        sent += 1
        time.sleep(1 / rate)
    return sent


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=3000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--start", help="Explicit UTC start; defaults to now when publishing, fixed epoch for local datasets")
    parser.add_argument("--output", default=".local/transactions.jsonl")
    parser.add_argument("--stream")
    parser.add_argument("--region", default="us-east-1")
    parser.add_argument("--rate", type=int, default=10)
    parser.add_argument("--drift", action="store_true")
    args = parser.parse_args()
    start = args.start or (datetime.now(timezone.utc).isoformat() if args.stream else "2026-01-01T00:00:00Z")
    records = list(generate(args.count, args.seed, start, args.drift, 1 / args.rate if args.stream else 2.0))
    if args.stream:
        import boto3
        print({"published": publish(boto3.client("kinesis", region_name=args.region), args.stream, records, args.rate)})
    else:
        path = Path(args.output)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("".join(json.dumps(e) + "\n" for e in records), encoding="utf-8")
        print({"records": len(records), "output": str(path)})

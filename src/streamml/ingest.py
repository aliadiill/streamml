"""S3 canonical write before atomic DynamoDB dedup + counters."""
import base64
import json
import logging
import os
import time
from .core import InvalidEvent, canonical, digest, minute, rule_anomaly, validate

LOG = logging.getLogger(__name__)
LOG.setLevel(logging.INFO)


def process(event, store):
    event = validate(event)
    checksum = digest(event)
    # Same ID always resolves to the same key. A different payload is a conflict.
    store.put_raw(event["event_id"], canonical(event), checksum)
    return store.commit(event, checksum)


class AwsStore:
    def __init__(self, s3, ddb, bucket, table):
        self.s3, self.ddb, self.bucket, self.table = s3, ddb, bucket, table

    def put_raw(self, event_id, data, checksum):
        key = f"raw/events/{event_id}.json"
        try:
            self.s3.put_object(Bucket=self.bucket, Key=key, Body=data,
                               ContentType="application/json", IfNoneMatch="*",
                               Metadata={"sha256": checksum}, ServerSideEncryption="AES256")
        except Exception as exc:
            code = getattr(exc, "response", {}).get("Error", {}).get("Code")
            if code not in ("PreconditionFailed", "412"):
                raise
            head = self.s3.head_object(Bucket=self.bucket, Key=key)
            if head.get("Metadata", {}).get("sha256") != checksum:
                raise InvalidEvent("Event ID reused with different content") from exc

    def commit(self, event, checksum):
        marker = {"pk": {"S": "EVENT#" + event["event_id"]}, "sha256": {"S": checksum},
                  "expires_at": {"N": str(int(time.time()) + 7 * 86400)}}
        try:
            self.ddb.transact_write_items(TransactItems=[
                {"Put": {"TableName": self.table, "Item": marker,
                         "ConditionExpression": "attribute_not_exists(pk)"}},
                {"Update": {"TableName": self.table, "Key": {"pk": {"S": "METRIC#" + minute(event)}},
                            "UpdateExpression": "ADD event_count :one, amount_cents :amount, anomalies :anomaly SET expires_at = :ttl",
                            "ExpressionAttributeValues": {":one": {"N": "1"}, ":amount": {"N": str(event["amount_cents"])},
                                ":anomaly": {"N": str(rule_anomaly(event))}, ":ttl": {"N": str(int(time.time()) + 7 * 86400)}}}},
                {"Put": {"TableName": self.table, "Item": {"pk": {"S": "RECENT#" + event["event_id"]},
                         "timeline": {"S": "EVENTS"}, "occurred_at": {"S": event["occurred_at"]},
                         "amount_cents": {"N": str(event["amount_cents"])},
                         "anomaly": {"N": str(rule_anomaly(event))}, "payload": {"S": canonical(event).decode()},
                         "expires_at": {"N": str(int(time.time()) + 86400)}}}}
            ])
            return "processed"
        except Exception as exc:
            reasons = getattr(exc, "response", {}).get("CancellationReasons", [])
            if reasons and reasons[0].get("Code") == "ConditionalCheckFailed":
                item = self.ddb.get_item(TableName=self.table, Key={"pk": marker["pk"]}, ConsistentRead=True).get("Item", {})
                if item.get("sha256", {}).get("S") != checksum:
                    raise InvalidEvent("Duplicate ID content mismatch") from exc
                return "duplicate"
            raise

    def quarantine(self, record_id, message):
        self.s3.put_object(Bucket=self.bucket, Key=f"quarantine/{record_id.replace(':', '_')}.json",
                           Body=json.dumps({"record_id": record_id, "reason": message}).encode(),
                           ServerSideEncryption="AES256", ContentType="application/json")


def handle(event, store):
    failures, counts = [], {"processed": 0, "duplicate": 0, "invalid": 0}
    for record in event.get("Records", []):
        sequence = record["kinesis"]["sequenceNumber"]
        try:
            raw = base64.b64decode(record["kinesis"]["data"], validate=True)
            if len(raw) > 16384:
                raise InvalidEvent("Record exceeds 16 KiB")
            try:
                body = json.loads(raw)
            except (ValueError, UnicodeDecodeError) as exc:
                raise InvalidEvent("Malformed JSON") from exc
            counts[process(body, store)] += 1
        except (InvalidEvent, ValueError) as exc:
            try:
                store.quarantine(record["eventID"], str(exc))
                counts["invalid"] += 1
            except Exception:
                failures.append({"itemIdentifier": sequence})
        except Exception:
            LOG.exception("Transient processing failure", extra={"sequence": sequence})
            failures.append({"itemIdentifier": sequence})
    LOG.info(json.dumps({"metrics": counts, "failed": len(failures)}))
    return {"batchItemFailures": failures}


def handler(event, context):
    import boto3
    return handle(event, AwsStore(boto3.client("s3"), boto3.client("dynamodb"),
                                 os.environ["LAKE_BUCKET"], os.environ["TABLE_NAME"]))

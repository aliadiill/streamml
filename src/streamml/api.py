import json
import os
from datetime import datetime, timedelta, timezone


def handler(event, context):
    import boto3
    # JWT is validated by API Gateway; the route has no anonymous integration.
    claims = event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {})
    if "sub" not in claims:
        return {"statusCode": 401, "body": json.dumps({"error": "Authentication required"})}
    ddb = boto3.client("dynamodb")
    table = os.environ["TABLE_NAME"]
    now = datetime.now(timezone.utc)
    minutes = [(now - timedelta(minutes=i)).strftime("%Y-%m-%dT%H:%M") for i in range(60)]
    result = ddb.batch_get_item(RequestItems={table: {"Keys": [{"pk": {"S": "METRIC#" + m}} for m in minutes]}})
    # Retry bounded unprocessed keys instead of silently presenting partial counters.
    rows = result.get("Responses", {}).get(table, [])
    for _ in range(3):
        pending = result.get("UnprocessedKeys", {})
        if not pending:
            break
        result = ddb.batch_get_item(RequestItems=pending)
        rows.extend(result.get("Responses", {}).get(table, []))
    if result.get("UnprocessedKeys"):
        return {"statusCode": 503, "body": json.dumps({"error": "Metrics temporarily incomplete"})}
    recent = ddb.query(TableName=table, IndexName="timeline", KeyConditionExpression="timeline = :t",
                       ExpressionAttributeValues={":t": {"S": "EVENTS"}, ":now": {"N": str(int(now.timestamp()))}},
                       FilterExpression="expires_at > :now", ScanIndexForward=False, Limit=30)
    totals = {name: sum(int(row.get(name, {}).get("N", 0)) for row in rows)
              for name in ("event_count", "amount_cents", "anomalies")}
    events = [{"id": r["pk"]["S"].removeprefix("RECENT#"), "at": r["occurred_at"]["S"],
               "amount": int(r["amount_cents"]["N"]) / 100, "anomaly": r["anomaly"]["N"] == "1"}
              for r in recent.get("Items", [])]
    return {"statusCode": 200, "headers": {"content-type": "application/json", "cache-control": "no-store"},
            "body": json.dumps({"window_minutes": 60, "generated_at": now.isoformat(),
                                **totals, "events": events, "detector": "bootstrap business rules"})}

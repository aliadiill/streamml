"""Explicitly enabled, cooldown-limited drift-triggered retraining."""
import json
import os
import time
from .model import drift


def should_retrain(report, enabled, previous_breaches):
    return enabled and report["eligible"] and report["score"] >= .75 and previous_breaches >= 1


def handler(event, context):
    import boto3
    s3, ddb, sm = boto3.client("s3"), boto3.client("dynamodb"), boto3.client("sagemaker")
    bucket, table = os.environ["LAKE_BUCKET"], os.environ["TABLE_NAME"]
    try:
        model = json.loads(s3.get_object(Bucket=bucket, Key="ml/baseline/approved.json")["Body"].read())
    except s3.exceptions.NoSuchKey:
        return {"status": "no_approved_baseline"}
    response = ddb.query(TableName=table, IndexName="timeline", KeyConditionExpression="timeline = :t",
                         ExpressionAttributeValues={":t": {"S": "EVENTS"}, ":now": {"N": str(int(time.time()))}},
                         FilterExpression="expires_at > :now", ScanIndexForward=False, Limit=1000)
    rows = [json.loads(i["payload"]["S"]) for i in response.get("Items", []) if "payload" in i]
    report = drift(rows, model)
    if len(rows) >= 500:
        report["eligible"] = report["eligible"] and len({r["fraud_label"] for r in rows}) == 2
    else:
        report["eligible"] = False
    state = ddb.get_item(TableName=table, Key={"pk": {"S": "CONTROL#DRIFT"}}, ConsistentRead=True).get("Item", {})
    breaches = int(state.get("breaches", {}).get("N", 0))
    now = int(time.time())
    report["timestamp"] = now
    s3.put_object(Bucket=bucket, Key=f"ml/drift/reports/{now}.json", Body=json.dumps(report).encode())
    ddb.update_item(TableName=table, Key={"pk": {"S": "CONTROL#DRIFT"}},
                     UpdateExpression="SET breaches = :b", ExpressionAttributeValues={
                         ":b": {"N": str(breaches + 1 if report["score"] >= .75 else 0)}})
    if not should_retrain(report, os.environ.get("AUTO_RETRAIN") == "true", breaches):
        return report
    try:
        ddb.update_item(TableName=table, Key={"pk": {"S": "CONTROL#RETRAIN"}},
            UpdateExpression="SET last_started = :now",
            ConditionExpression="attribute_not_exists(last_started) OR last_started < :cutoff",
            ExpressionAttributeValues={":now": {"N": str(now)}, ":cutoff": {"N": str(now - 86400)}})
    except ddb.exceptions.ConditionalCheckFailedException:
        return {**report, "retrain": "cooldown"}
    key = f"ml/monitoring/{now}/input.jsonl"
    s3.put_object(Bucket=bucket, Key=key, Body="".join(json.dumps(r) + "\n" for r in rows).encode())
    result = sm.start_pipeline_execution(PipelineName=os.environ["PIPELINE_NAME"],
        ClientRequestToken=f"streamml-retrain-{now // 86400:032d}",
        PipelineParameters=[{"Name": "TrainingDataUri", "Value": f"s3://{bucket}/{key}"}],
        ParallelismConfiguration={"MaxParallelExecutionSteps": 1})
    return {**report, "execution": result["PipelineExecutionArn"]}

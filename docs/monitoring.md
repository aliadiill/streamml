# Monitoring, operations and recovery

## Implemented observations

CloudWatch log groups retain Lambda, API and CodeBuild logs for seven days. Ingest logs contain processed, duplicate, invalid and failed-batch counts without logging complete records. Native alarms watch Lambda errors, stream iterator age above 60 seconds for two minutes, and visible failed-batch messages. SageMaker execution failure events go to the operations topic.

The dashboard shows unique processed events, aggregate synthetic value, rule-flagged events and mean event rate for the last hour. It refreshes every ten seconds and labels eventual consistency. It does not display invented processing-latency, model quality or live pipeline-status telemetry. API access logs and native CloudWatch latency metrics are the current sources for timing.

## Triage

1. For missing counters, confirm the producer wrote current timestamps. A fixed historical local dataset will not appear in a current-hour counter.
2. Check Lambda errors, iterator age and the failure queue. Compare raw S3 writes with DynamoDB markers; do not count raw-object presence alone as a completed transaction.
3. Check the quarantine prefix for a record ID and schema reason. Correct the producer instead of repeatedly retrying malformed data.
4. For failed-batch metadata, preserve the failure event and inspect stream data while still retained. Do not purge the queue before deciding replay/recovery.
5. For a failed ML run, read the evaluation report and Fail-step reason. Model rejection is expected behavior when a criterion fails; the old approved baseline remains unchanged.

## Drift and retraining

Create the approved baseline by completing an authorized batch inference first. The drift schedule and retraining remain disabled initially. The monitor reads at most 1,000 recent labelled events. It needs at least 500, both classes, two consecutive threshold breaches and a full-day cooldown before starting one training execution.

If starting a pipeline fails after the cooldown reservation, the conservative reservation remains. Investigate permissions/quota and the current execution list, then reset the CONTROL record only with an explicit operating decision. Repeated automatic resets could create unwanted training charges.

## Recovery and rollback

For an interrupted approved transform, inspect its real status; request stop if required and wait for a terminal state. Delete the transient SageMaker model after the job is terminal. No endpoint should exist in this architecture.

S3 versioning can recover overwritten configuration/assets; DynamoDB PITR can restore to a new table. Test a restoration before relying on it. Restore the previous app artifact or pipeline definition after a bad deployment. Approval of a new registry version does not delete the previous version.

SNS has no destination subscription by default. Until subscription confirmation and a real delivery test, describe notifications as configured routing, not delivered alerts.


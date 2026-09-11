# Monitoring, operations and recovery

## Implemented observations

I set Lambda, API and CodeBuild log retention to seven days. Ingest logs contain processed, duplicate, invalid and failed-batch counts without logging complete records. Native alarms watch Lambda errors, stream iterator age above 60 seconds for two minutes, and visible failed-batch messages. SageMaker execution failure events go to the operations topic.

I designed the dashboard to show unique processed events, aggregate synthetic value, rule-flagged events and mean event rate for the last hour. It refreshes every ten seconds and labels eventual consistency. It does not display invented processing-latency, model quality or live pipeline-status telemetry. API access logs and native CloudWatch latency metrics are the current sources for timing.

## Triage

1. For missing counters, I would confirm the producer wrote current timestamps. A fixed historical local dataset will not appear in a current-hour counter.
2. I would check Lambda errors, iterator age and the failure queue. Compare raw S3 writes with DynamoDB markers; do not count raw-object presence alone as a completed transaction.
3. I would check the quarantine prefix for a record ID and schema reason. Correct the producer instead of repeatedly retrying malformed data.
4. For failed-batch metadata, I would preserve the failure event and inspect stream data while still retained. Do not purge the queue before deciding replay/recovery.
5. For a failed ML run, I would read the evaluation report and Fail-step reason. Model rejection is expected behavior when a criterion fails; the old approved baseline remains unchanged.

## Drift and retraining

I require a completed batch inference using an approved model before creating the drift baseline. The drift schedule and retraining remain disabled initially. The monitor reads at most 1,000 recent labelled events. It needs at least 500, both classes, two consecutive threshold breaches and a full-day cooldown before starting one training execution.

I preserve the cooldown reservation if a pipeline start fails. Before resetting the CONTROL record, I would investigate IAM permissions, quota and the execution list. Repeated automatic resets could create unwanted training charges.

## Recovery and rollback

For an interrupted approved transform, I would inspect its status, stop it if needed, wait for a terminal state and then delete the transient model. No endpoint should exist in this architecture.

I included S3 versioning to recover overwritten configuration/assets; DynamoDB PITR can restore to a new table. I have not run a full-stack restoration rehearsal yet. My rollback approach is to restore the previous application artifact or pipeline definition. Approval of a new registry version does not delete the previous version.

I left SNS without a destination subscription. I have configured routing, but I still need to confirm a subscription and test delivery before relying on alerts.


# Cost controls and teardown

The owner's limit is **USD 100 total promotional-credit use, not USD 100 per month**, with **zero personal/out-of-pocket spending now or in the future**. Retain the Free plan; a paid plan upgrade is not authorized. Kinesis is currently unavailable under the account's service eligibility, so the complete StreamML stack stays undeployed. This source implementation itself makes no billable AWS calls.

The limits below do not promise that credits cover every service or that an alarm prevents charges. Any separately authorized bounded component test must fit within the aggregate promotional-credit ceiling and the existing Free-plan protection. Consult the [AWS pricing calculator](https://calculator.aws/) for current rates before such a test; no price quote is invented here.

| Component | Implemented limit | Residual/accidental-running cost |
| --- | --- | --- |
| Kinesis | One provisioned shard; 24-hour retention | Continues charging while stream exists, even with no producer |
| Producer | ≤10,000 events/run; ≤25 events/s | No background producer or scheduler is created |
| Lambda | 256 MiB; short timeouts; no reservation under the small shared quota | Invocations, retries and logs can still consume credits |
| DynamoDB | Pay-per-request; seven-day marker/counter TTL, one-day recent TTL | Storage/PITR and delayed TTL deletion remain billable |
| Athena | 10 MiB per-query scan ceiling | A failed capped query can still incur scanned-data cost |
| SageMaker | One ml.m5.large per job, 600-second processing/training runtime limit | Startup/managed overhead, quotas and storage still apply |
| Batch transform | One instance, 1 MiB input, client deadline | Client termination defeats the client-side stop timer; verify AWS state |
| Drift/automatic training | Both disabled by default; two breaches and 24-hour cooldown | Enabling recurring jobs adds recurring cost |
| Logs and S3 | Logs seven days; version/lifecycle rules in Terraform | Current ML artifacts and tagged images require deliberate teardown |
| CI/CD | CodeBuild small workers, 20-minute timeout | Builds and pipeline executions cost money; don't use training for every UI edit |

Kinesis and SageMaker dominate the deliberate-demo decision. Run a short, scheduled window; produce a bounded dataset; perform one experiment and one approved transform; then stop. Do not leave a stream running while doing unrelated interview preparation.

## Teardown sequence

1. Stop the producer, disable automatic retraining and the scheduled monitor.
2. Stop or wait for active training/processing/transform jobs and CodeBuild executions. Record actual terminal states and the evaluation evidence.
3. Preserve source, selected evaluation reports and genuine screenshots. Keep private account evidence outside the public repository.
4. Inspect a Terraform destroy plan scoped to this project's state. Default bucket `force_destroy=false` prevents silent data erasure.
5. After reviewing those exact project buckets, empty their object versions and delete markers, remove project model-package versions and transient model resources as required, and empty the project ECR repository after checking approved model references.
6. Apply the reviewed destroy plan. Preserve the shared state bucket and any shared CodeConnections connection.
7. Verify that the stream, billable jobs and project resources are gone. Revisit billing after its reporting delay. Deleting infrastructure does not erase already accrued charges.

No blanket account cleanup or state-independent destructive script is included.

# My cost controls and teardown approach

I kept lab runs short and aimed for a **one-time $100 credit budget**. I used the Free plan and avoided ongoing infrastructure where it added little to the demonstration. Kinesis was unavailable under my account eligibility, so I left the full streaming stack undeployed.

I ran three short CodeBuild container experiments. My final image passed every gate, and I removed the temporary ECR repository, source/artifact bucket, build project, IAM role and logs. I verified their absence at 06:23:58 UTC on 2026-09-11. I recorded the results in [container evidence](evidence/container-execution.json). My [published static preview](pages-preview.md) makes no AWS connection.

I treated the limits below as engineering controls, not hard dollar caps. Before another experiment, I would check current rates in the [AWS pricing calculator](https://calculator.aws/), available credits and expected runtime. I also allow for billing delay when comparing an experiment with my budget. My [credit snapshot](credit-budget-verification.md) separates posted figures from the final cost still to settle.

| Component | My implemented limit | Remaining cost consideration |
| --- | --- | --- |
| Kinesis | One provisioned shard; 24-hour retention | A stream accrues cost while it exists, even with no producer |
| Producer | ≤10,000 events/run; ≤25 events/s | I created no background producer or scheduler |
| Lambda | 256 MiB; short timeouts; no reservation under the small shared quota | Invocations, retries and logs can consume credits |
| DynamoDB | Pay-per-request; seven-day marker/counter TTL; one-day recent TTL | Storage, PITR and delayed TTL deletion remain billable |
| Athena | 10 MiB per-query scan ceiling | A capped query can still incur scanned-data cost |
| SageMaker | One ml.m5.large per job; 600-second processing/training limit | Startup, quotas and storage still apply; these jobs remain unrun |
| Batch transform | One instance; 1 MiB input; client deadline | The stop loop depends on the client staying alive |
| Drift/retraining | Disabled defaults; two breaches; 24-hour cooldown | Recurring jobs would add recurring usage |
| Logs and S3 | Seven-day logs; version/lifecycle rules | Referenced model artifacts and tagged images need deliberate cleanup |
| Main CI/CD | Small CodeBuild workers; 20-minute timeout | I avoid retraining for routine UI changes |
| Isolated container experiment | Small worker; ten-minute build and queue caps; three actual attempts | I deleted the temporary resources after evidence capture |

For a future full-stack experiment, I would use a short window: a bounded dataset, one training experiment, one approved transform and immediate teardown. I would not leave a stream running between lab sessions.

## My teardown checklist

1. I stop the producer and disable scheduled monitoring and retraining.
2. I stop or wait for active processing, training, transform and build jobs, then record their terminal states.
3. I preserve source, evaluation reports and actual screenshots while keeping private account evidence outside the repository.
4. I inspect a destroy plan scoped to the project state. My buckets default to `force_destroy=false` to expose nonempty storage before deletion.
5. I check exact artifact references, remove project object versions and delete markers, and remove temporary images/models only when no required reference remains.
6. I apply the saved destroy plan and preserve shared state storage or connections.
7. I verify resource absence and later review posted billing. Teardown does not erase usage already incurred.

I used this approach for the completed container experiment: six object versions and three recorded image digests were removed, then Terraform destroyed twelve remaining resources. The source object was the thirteenth managed resource. I verified zero remaining managed resources and no running known build. The full-stack recovery and teardown sequence remains future work.

# Interview explanations

## 30 seconds

I built StreamML as a transaction analytics and MLOps engineering lab. I implemented Kinesis ingestion, retry-safe Lambda processing, private storage, an authenticated dashboard and gated SageMaker Pipelines. I verified the code locally and ran the actual Docker preprocessing, training, evaluation and HTTP inference on AWS CodeBuild. Two image scans blocked release before an Alpine correction passed. I removed the temporary AWS infrastructure after preserving evidence and published a labelled static dashboard. The full Kinesis/SageMaker integration remains blocked by account eligibility and quotas.

## One minute

The problem I focused on most was correctness under retries. The processor first writes a canonical S3 event with a conditional content hash, then commits a DynamoDB dedup marker and counters together. If the process fails between systems, the same event can finish safely on retry. I explicitly limit the guarantee to the marker's seven-day retention.

On the ML side, the training set fits the scaler and coefficients, validation selects the threshold, and a newer test set decides whether the candidate meets quality/support criteria. Passing quality registers PendingManualApproval; it does not deploy. This gives me a concrete way to explain the differences among app CI/CD, infrastructure delivery, model quality and MLOps.

## Five-minute discussion outline

I begin with the payments-operations scenario and synthetic-data limitation, then trace my implemented validation, canonical S3 write and DynamoDB transaction. I show tested duplicate/failure cases and the confusion matrix I reproduced inside Docker. I explain the designed DAG and model approval controls, the two failed scans, my Alpine correction, verified teardown and published Pages preview. I finish with the batch/drift integrations I have not run and the account and cost limits that shaped the experiment.

## Questions and answers

**Why Kinesis instead of a queue?** Per-partition ordering and a bounded replay window suit the transaction stream. SQS would be reasonable for independent work items but would change the explicitly requested architecture.

**Is processing exactly once?** No blanket claim. Conditional storage and an atomic dedup/counter transaction provide idempotent effects inside the seven-day marker horizon. A later replay can count again after marker expiry.

**Why write S3 first?** It preserves a canonical payload before committing counters. A crash can leave raw data awaiting commit; a retry can finish. Writing a permanent dedup marker first could incorrectly suppress an unfinished S3 write.

**Why is high F1 not enough?** Synthetic quality may not generalize. F1 trades precision/recall; support, false-positive rate, human review, data provenance and business costs still matter.

**How is leakage prevented?** Time-ordered disjoint sets, equal timestamps kept together, train-only scaling and coefficients, validation-only threshold selection, no label/identifier features. Real deployment also needs mature labels and rolling backtests.

**What does drift mean here?** A normalized feature-mean change. It signals distribution movement, not necessarily degraded predictive performance. Actual performance needs trusted outcome labels.

**What limits retraining cost?** Disabled defaults, bounded labelled sample, two breaches, conditional daily cooldown, one parallel pipeline step and job runtime ceilings. These are controls, not a guaranteed dollar cap.

**How is authentication enforced?** Cognito PKCE login and an HTTP API JWT authorizer with an explicit scope. CloudFront forwards Authorization and disables API caching.

**How would it scale?** Partition and compact raw files, shard hot metric buckets, reconsider the global recent-feed index, increase streaming capacity from measured demand and add load/integration tests.

**What remains unverified?** I have not tested full Kinesis-to-Lambda ingestion, Cognito integration, IAM negative tests, SageMaker and main CodePipeline executions, notification delivery and full-stack recovery. I have verified the isolated AWS Docker execution, ECR scan, temporary-infrastructure teardown and public Pages deployment.

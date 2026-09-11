# Architecture decisions

## ADR 001 — Transaction anomalies
Choose a single synthetic payments-operations story to connect producer realism, stream ordering, near-real-time counters and model evaluation. This is safer and more reproducible for a portfolio than importing unknown cardholder data. The limitation is that synthetic quality does not measure real-world fraud effectiveness.

## ADR 002 — Managed services without a custom VPC
The application has no private compute/database dependency requiring subnet placement. Use private IAM-protected managed storage and service endpoints, avoiding idle NAT and instance charges. Add private networking only when a concrete data source or threat model requires it.

## ADR 003 — Canonical S3 first, transactional counters second
S3 and DynamoDB cannot share a native transaction. A deterministic S3 key plus a verified hash supports replay; the DynamoDB marker and counters commit together. Declare the seven-day dedup horizon rather than claiming global exactly-once delivery.

## ADR 004 — Simple logistic baseline
A deterministic, interpretable model keeps the experiment portable and the pipeline easy to inspect. Fixed initialization, chronological splits and train-only scaling make failure/leakage discussion concrete. More complex algorithms are not justified until the data or baseline error analysis requires them.

## ADR 005 — Approval plus batch transform
Quality and human approval are independent decisions. Batch inference demonstrates actual model consumption while avoiding an always-running endpoint. The client deadline is a guardrail that still requires job-state monitoring.

## ADR 006 — Separate infrastructure and model controls
Terraform plan/apply governs resource changes. CodePipeline tests and a manual deployment stage govern application/pipeline-definition delivery. The SageMaker condition governs quality, Registry governs approval, and explicit monitoring switches govern retraining. These controls are intentionally not collapsed into one green button.

## ADR 007 — Region
Use us-east-1 to keep the integrated stack and documented service availability consistent. A Canadian data-residency requirement would justify a Canadian region after confirming all services, quotas, price and compliance needs. No real customer data is stored by this lab.


# What I learned while troubleshooting

I collected the failures I encountered and the checks I would use for full-stack behavior that remains unrun. My build journal contains the actual image-scan failures and correction results.

| Symptom | Likely boundary | Next action |
| --- | --- | --- |
| Kinesis SubscriptionRequiredException / OptInRequired | Account plan/service eligibility | I kept the Free plan, left the full stack undeployed and preserved the tested implementation |
| Terraform init socket denied | Local network access | I corrected provider-download access and reran initialization |
| botocore.session unavailable in tests | Local package/filesystem access | Install requirements in the active venv; do not skip API-shape tests and call them passed |
| Dashboard says connection required | Missing public auth configuration | Use real Terraform outputs or open labelled sample preview |
| Hosted login fails callback | URL/client mismatch | Match the exact registered base callback including trailing slash |
| API 401/403 | Token expiry, issuer/client/scope | Sign in again; confirm streamml/read, without logging tokens |
| Counters empty after publishing | Historical timestamps, processing failure, or eventual reads | Use current producer start, inspect logs, then verify markers |
| S3 object exists but counter absent | Crash before transaction or transient DynamoDB failure | Retry the exact canonical event inside the dedup horizon |
| Duplicate ID quarantined | ID reused with different content | Fix producer identity semantics; never overwrite canonical data |
| Preprocess fails | Too few/too many rows, schema conflict, equal-time split | Correct the input dataset; preserve chronological boundaries |
| QualityGate fails | Poor held-out quality or inadequate support | Inspect confusion counts; do not relax thresholds solely to turn a demo green |
| Retraining does not fire | Disabled switch, missing approved baseline, insufficient data or cooldown | Inspect the explicit control states and drift report |
| Destroy blocked by nonempty storage | Deliberate data-loss safeguard | Review exact project artifacts, preserve evidence and remove them intentionally |

I labelled the UI values as sample data and the governance panel as workflow design. Neither is a source of live pipeline state. I could add a read-only execution/status endpoint after reviewing its IAM scope and information exposure.

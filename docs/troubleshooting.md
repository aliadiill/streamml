# Troubleshooting

| Symptom | Likely boundary | Next action |
| --- | --- | --- |
| Kinesis SubscriptionRequiredException / OptInRequired | Account plan/service eligibility | Keep the Free plan and the user's zero-out-of-pocket constraint; leave the full stack undeployed and preserve the tested source |
| Terraform init socket denied | Local network sandbox | Permit provider download; this is not an AWS account permission |
| botocore.session unavailable in tests | Local package/filesystem access | Install requirements in the active venv; do not skip API-shape tests and call them passed |
| Dashboard says connection required | Missing public auth configuration | Use real Terraform outputs or open labelled sample preview |
| Hosted login fails callback | URL/client mismatch | Match the exact registered root callback including trailing slash |
| API 401/403 | Token expiry, issuer/client/scope | Sign in again; confirm streamml/read, without logging tokens |
| Counters empty after publishing | Historical timestamps, processing failure, or eventual reads | Use current producer start, inspect logs, then verify markers |
| S3 object exists but counter absent | Crash before transaction or transient DynamoDB failure | Retry the exact canonical event inside the dedup horizon |
| Duplicate ID quarantined | ID reused with different content | Fix producer identity semantics; never overwrite canonical data |
| Preprocess fails | Too few/too many rows, schema conflict, equal-time split | Correct the input dataset; preserve chronological boundaries |
| QualityGate fails | Poor held-out quality or inadequate support | Inspect confusion counts; do not relax thresholds solely to turn a demo green |
| Retraining does not fire | Disabled switch, missing approved baseline, insufficient data or cooldown | Inspect the explicit control states and drift report |
| Destroy blocked by nonempty storage | Deliberate data-loss safeguard | Review exact project artifacts, preserve evidence and remove them intentionally |

The UI's sample values are illustrative and its governance panel describes workflow design. Neither is a source of live pipeline state. A future extension can add a read-only execution/status endpoint after its IAM and information-exposure boundaries are reviewed.

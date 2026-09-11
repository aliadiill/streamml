# Verification record

Recorded on 2026-09-11 UTC. These results describe local execution only.

## Completed locally

- **16 Python tests passed**, including duplicate handling, conflicting duplicate rejection, invalid/poison-record handling, recovery after S3-write/DynamoDB-commit interruption, content-hash conditional writes, transaction structure, deterministic bounded generation, chronological disjoint splits, excluded label/identity features, training reproducibility, quality rejection, drift controls, unapproved-model denial and SageMaker API-argument shape validation.
- The API-shape check used an installed botocore SageMaker service model, with no credentials or AWS request. Initial sandbox runs could not read the shared package directory; running the same offline test with package filesystem access resolved that environment limitation.
- The **React/TypeScript production build passed**. npm dependency installation audited 120 packages and reported **zero vulnerabilities** at that time.
- Terraform formatting and provider initialization completed with AWS provider 6.64.0 and archive provider 2.8.0. Final validation status is recorded below after the current validation pass.

The injected transient-failure test intentionally logs an exception before a successful retry; its test result is passing.

## Deterministic ML result

| Measurement | Actual local result |
| --- | ---: |
| Total synthetic rows | 3,000 |
| Train / validation / test | 1,800 / 600 / 600 |
| Test positives / negatives | 56 / 544 |
| True positive / false positive | 53 / 5 |
| False negative / true negative | 3 / 539 |
| Precision | 0.913793 |
| Recall | 0.946429 |
| F1 | 0.929825 |
| False-positive rate | 0.009191 |
| All quality criteria | Passed |

`python scripts/local_demo.py` reruns the actual generator, validation, splitting, training and evaluation. It saves the machine-readable report under ignored `.local/`; the summarized verified figures above are suitable for public documentation.

## Cloud acceptance checklist — all unrun

The lead verified additional account blockers on 2026-09-11 UTC: Kinesis returned SubscriptionRequiredException, and us-east-1 quotas for ml.m5.large **training, processing and transform were each zero**. Full streaming deployment and those ML jobs therefore cannot run in the current account. No paid plan upgrade or quota increase was requested. These are observed account limits, not failed model quality or an application-code test result.

| Test | Expected evidence |
| --- | --- |
| Stream → Lambda → S3/DynamoDB | Bounded input count, raw writes, unique markers and counters |
| Exact replay within seven days | Same accepted counter after identical events |
| Malformed and transient records | Real quarantine object, retry trace and failure-destination behavior |
| Authentication | No-token/invalid-scope denied, valid Cognito user allowed |
| Athena | Correct aggregate and enforced scan cap |
| SageMaker valid run | Actual graph execution, report, pending package |
| SageMaker deliberately bad candidate | Fail step and unchanged approved baseline |
| Approved inference | Real bounded transform output and terminal job |
| Drift | Baseline, report, two-breach/cooldown behavior |
| CI/CD | GitHub event, passing/failing gates, manual review, deployment result |
| Security | Private-bucket denial, scoped IAM negative tests, HTTPS and JWT checks |
| Recovery/teardown | Restore rehearsal, removed billable resources, delayed billing review |

Local mock tests establish code behavior. They do not establish AWS IAM correctness, account quotas, provider acceptance during apply, integration ordering, real end-to-end latency or financial model validity. Do not mark these rows complete without real evidence.

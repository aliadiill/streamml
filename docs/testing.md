# Verification record

I recorded these results on 2026-09-11 UTC. I tested the code locally, ran an isolated AWS container experiment and verified the published Pages preview. I kept those results separate from full-stack tests I have not run.

I preserved machine-readable evidence: [verification summary](evidence/local-verification.json) and [actual local evaluation](evidence/local-evaluation.json).

## Completed locally

- I ran **16 Python tests, all passing**, including duplicate handling, conflicting duplicate rejection, invalid/poison-record handling, recovery after S3-write/DynamoDB-commit interruption, content-hash conditional writes, transaction structure, deterministic bounded generation, chronological disjoint splits, excluded label/identity features, training reproducibility, quality rejection, drift controls, unapproved-model denial and SageMaker API-argument shape validation.
- I checked API argument shapes with an installed botocore SageMaker service model, with no credentials or AWS request. I initially hit a filesystem-access issue in the shared package directory, then corrected it and reran the same offline test.
- I successfully built the **React/TypeScript production bundle**. npm dependency installation audited 120 packages and reported **zero vulnerabilities** at that time.
- I passed Terraform formatting, provider initialization and validation with AWS provider 6.64.0 and archive provider 2.8.0. The provider emitted two DynamoDB legacy key-schema deprecation warnings; they are compatibility notices, not validation errors. No Terraform plan/apply or AWS service call was part of those local checks.

I deliberately injected a transient failure; the test logs an exception and then verifies a successful retry.

I also validated the independent CodeBuild container configuration through Terraform initialization, formatting and validation without warnings. All three shell scripts passed Bash syntax checks. A deterministic allowlist source ZIP was prepared.

## Actual AWS container demonstration

I applied a 13-resource create-only plan for the independent container experiment. I ran three CodeBuild executions, each capped at ten minutes, covering Docker preprocessing, training, held-out evaluation, deliberate bad-model rejection and HTTP inference successfully. The first two Debian attempts failed the ECR gate with 6 critical and 11 high findings. The final Alpine attempt **SUCCEEDED**, with the same functional checks and a **COMPLETE ECR scan reporting zero findings**. The same held-out metrics below were reproduced inside all three containers. Actual attempts and exact digests are preserved in the [container proof](container-build.md) and [sanitized evidence](evidence/container-execution.json). This validates an actual Docker workload on AWS CodeBuild; it does not establish a SageMaker Pipeline execution or the full streaming integration.

I successfully built both the Pages and normal dashboard variants. The Pages artifact passed checks for `/streamml/` asset paths and its browser connection-blocking policy. The [Pages workflow 34569734895](https://github.com/aliadiill/streamml/actions/runs/34569734895) then **SUCCEEDED** for commit `fc2a698`. A real browser check verified the [published preview](https://aliadiill.github.io/streamml/), its automatic sample-mode labels, dashboard and navigation. [Screenshot](screenshots/streamml-github-pages.png) and [deployment evidence](evidence/pages-deployment.json) preserve that distinct result.

I verified the isolated container teardown at 06:23:58 UTC: its ECR repository, artifact bucket, build project, IAM role and log group were absent; all known builds were terminal or removed, and its Terraform state had zero managed resources. This is completed teardown evidence for the container demonstration only; the unrun full-stack recovery checklist below remains separate.

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

## Full-stack cloud acceptance checklist — all unrun

On 2026-09-11 UTC, I found Kinesis SubscriptionRequiredException, and us-east-1 quotas for ml.m5.large **training, processing and transform were each zero**. A full applied-quota listing found nonzero processing quotas for ml.t3.medium (4), ml.t3.large (4) and ml.t3.xlarge (2), but no positive training or transform instance quota. An alternative isolated processing job could be considered separately; it does not unblock the specified pipeline. Full streaming deployment and the selected ML jobs remain unrun. I kept the Free plan and left those full-stack tests unrun.

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

I use local mock tests to establish code behavior. They do not establish AWS IAM correctness, account quotas, provider acceptance during apply, integration ordering, real end-to-end latency or financial model validity. I will mark these rows complete only after collecting execution evidence.

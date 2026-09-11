# Build journal: observed failures and engineering decisions

Recorded 2026-09-11 UTC. This journal distinguishes source completeness, locally tested behavior, actual AWS container execution and blocked integrations. It records problems rather than replacing failed evidence with a success narrative.

## The account could not run the requested full stack

Kinesis returned `SubscriptionRequiredException` in the Free-plan learning account. The owner authorized up to USD 100 total promotional-credit use and zero out-of-pocket spending, with no paid upgrade. The complete Terraform root was therefore left unapplied. The Kinesis implementation remains in source because it is part of the intended architecture; a local dashboard screenshot is not evidence that it ingested live events.

The selected SageMaker ml.m5.large processing, training and transform quotas were each zero in us-east-1. A broader applied-quota read found processing alternatives: ml.t3.medium=4, ml.t3.large=4 and ml.t3.xlarge=2. No training or transform instance quota was positive in that response. These observations support the narrower conclusion that the specified full ML pipeline was blocked. They do not mean that every SageMaker operation is unavailable. No quota-increase request or SageMaker job was submitted during the container demonstration.

## Local tooling required environment fixes

The installed Python dependency directory could not initially be read from the sandbox. The bundled interpreter also required explicitly adding that directory to its import path. Re-running the same offline tests with the permitted package access produced 16 passing tests, including botocore validation of Processing, Training and model-registration argument shapes. This was an environment-access issue, not an AWS API success.

Terraform provider downloads/cache initialization required network and filesystem access. Both Terraform roots subsequently validated. The main root reported DynamoDB legacy key-schema deprecation notices; the independent bootstrap validated without warnings. The full application's provider validation does not prove IAM permissions or deployment success.

Adding the Vite configuration triggered an esbuild sandbox directory-access error. Re-running the local build with permitted access resolved it. The first Pages artifact assertion expected literal quote characters, while Vite correctly HTML-encoded them in the security-policy meta element. The check was corrected to decode those entities; the policy itself was not weakened.

## Docker had to run on transient AWS compute

Neither Docker nor Podman was installed locally. An independent Terraform root created exactly 13 bootstrap resources: private source/artifact storage, an immutable image repository, a small transient CodeBuild project, scoped IAM and short-retention logs. It had no Kinesis, SageMaker job or full application dependency. The reviewed plan contained only creates; build and queue limits were each ten minutes. This isolated path produced real Docker evidence without starting continuous compute.

All attempts used 3,000 deterministic synthetic transactions and the same real container entrypoints. The functional checks covered preprocessing, chronological splitting, training, held-out evaluation, deliberate model rejection, the inference server health route and three actual HTTP predictions. Held-out F1 was 0.929825, with 53 true positives, 5 false positives, 3 false negatives and 539 true negatives. The deliberately always-positive model failed quality checks with a false-positive rate of 1.0.

| Attempt | Change and observed result |
| --- | --- |
| Initial Debian slim image | Functional Docker tests passed. ECR scanning completed with 6 critical and 11 high findings. The overall build failed at the release gate. |
| Debian security update | Ran package index refresh and upgrade. The repositories reported zero packages to upgrade. Functional checks passed again; the same 6 critical and 11 high findings kept the build failed. |
| Alpine alternative | The pure-Python standard-library workload moved to a Python Alpine base with package upgrades. The same functional tests passed, ECR scanning completed with zero reported findings, and the final build SUCCEEDED in about two minutes. This is a distinct remediation using musl rather than glibc. |

The Debian findings included glibc, Perl, SQLite, PCRE2 and zlib packages inherited from the base image. The report was preserved. No suppression, scanner bypass or severity-threshold change was made. A successful Docker build alone is insufficient for release; an unsupported or failed scanner is also not a passing result.

Alpine reduces this workload's dependency surface, but it is a tradeoff: packages with native extensions may require musl-compatible wheels or compilation, and behavior can differ from glibc-based images. The current model uses Python's standard library. Every base change must repeat functional and security checks. The source archive is deterministic and the image tag immutable, while the upstream base tag can change over time; the recorded digest identifies the actual tested result.

See [sanitized execution evidence](evidence/container-execution.json) for observed attempt statuses, digests, scan counts and metrics. Account-specific logs and artifacts remain private. Cleanup is recorded only after exact bootstrap resources are verified removed.

The teardown ownership check initially rejected a manually shortened expected image tag before deleting anything. Expected tags were then read directly from the saved source manifests and cross-checked against the three recorded digests. The exact six owned object versions and three images were removed, followed by a reviewed destroy-only plan for the twelve remaining Terraform resources. The source object accounted for the thirteenth managed resource. At 06:23:58 UTC, AWS verified the repository, bucket, project, role and logs absent, and the local state had zero managed resources. All known builds were terminal or removed. This removed the temporary demonstration storage and compute path after its evidence was preserved.

## The public preview has a different purpose from the AWS application

The GitHub Pages build uses `/streamml/`, opens directly into clearly labelled sample data and disables login, token processing and API polling. Its browser policy also sets `connect-src 'none'`, preventing fetch/WebSocket connections. No credentials or AWS configuration are needed to publish it. The normal application build retains authenticated AWS integration code.

The Pages workflow builds an artifact, verifies its repository path and network policy, and deploys through a `github-pages` environment so GitHub records deployment history. [Run 34569734895](https://github.com/aliadiill/streamml/actions/runs/34569734895) succeeded for commit `fc2a698`. The browser then verified the [published preview](https://aliadiill.github.io/streamml/), its automatic sample labels, dashboard and navigation; the [actual capture](screenshots/streamml-github-pages.png) is public. This establishes successful static-site publication separately from the completed AWS Docker test and the unrun full stack. The workflow follows [GitHub's custom Pages workflow guidance](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## What the model does not establish

The synthetic generator and deterministic labels make this a repeatable engineering demonstration, not a validated payment-fraud model. The holdout follows the same generator family as training; it does not measure performance on real customer behavior, adversarial fraud, shifting class prevalence or external datasets. Chronological splits and train-only normalization prevent specific forms of leakage but cannot remove every bias. The dashboard's live counters use explicit bootstrap rules; a SageMaker model is not silently substituted into that path. Human approval, actual cloud integration testing and wider validation remain separate requirements.

# Build journal: observed failures and engineering decisions

I recorded this journal on 2026-09-11 UTC to explain what I built, the failures I encountered and how I verified the result. I kept local tests, actual AWS execution and blocked integrations separate.

## The account could not run the requested full stack

Kinesis returned `SubscriptionRequiredException` in my Free-plan account. I aimed for a one-time $100 credit budget and left the full Terraform configuration unapplied. I kept Kinesis in the implementation because it is part of my intended architecture, while clearly separating the static dashboard from live streaming evidence.

I found that the selected SageMaker ml.m5.large processing, training and transform quotas were each zero in us-east-1. A broader applied-quota read found processing alternatives: ml.t3.medium=4, ml.t3.large=4 and ml.t3.xlarge=2. No training or transform instance quota was positive in that response. These observations support the narrower conclusion that the specified full ML pipeline was blocked. They do not mean that every SageMaker operation is unavailable. I used a standalone container experiment and did not start a SageMaker job.

## Local tooling required environment fixes

I initially hit a filesystem-access problem reading the installed Python dependencies. I also had to add that directory to the Python import path. After correcting the environment, I reran the same offline tests and obtained 16 passing tests, including botocore validation of Processing, Training and model-registration argument shapes. This was an environment-access issue, not an AWS API success.

I resolved network and filesystem access problems with Terraform provider initialization. Both configurations then validated. My main configuration reported DynamoDB legacy key-schema deprecation notices; the independent bootstrap validated without warnings. The full application's provider validation does not prove IAM permissions or deployment success.

When I added the Vite configuration, esbuild encountered a local directory-access error. I corrected the access issue and reran the build. My first Pages artifact assertion expected literal quote characters, while Vite correctly HTML-encoded them in the security-policy meta element. I corrected the check to decode those entities and kept the browser security policy unchanged.

## Docker had to run on transient AWS compute

I did not have Docker or Podman installed locally, so I used a separate Terraform configuration to create exactly 13 temporary resources: private source/artifact storage, an immutable image repository, a small transient CodeBuild project, scoped IAM and short-retention logs. It had no Kinesis, SageMaker job or full application dependency. The reviewed plan contained only creates; build and queue limits were each ten minutes. This isolated path produced real Docker evidence without starting continuous compute.

I used 3,000 deterministic synthetic transactions and the same container entrypoints in all three attempts. The functional checks covered preprocessing, chronological splitting, training, held-out evaluation, deliberate model rejection, the inference server health route and three actual HTTP predictions. Held-out F1 was 0.929825, with 53 true positives, 5 false positives, 3 false negatives and 539 true negatives. The deliberately always-positive model failed quality checks with a false-positive rate of 1.0.

| Attempt | Change and observed result |
| --- | --- |
| Initial Debian slim image | Functional Docker tests passed. ECR scanning completed with 6 critical and 11 high findings. The overall build failed at the release gate. |
| Debian security update | Ran package index refresh and upgrade. The repositories reported zero packages to upgrade. Functional checks passed again; the same 6 critical and 11 high findings kept the build failed. |
| Alpine alternative | The pure-Python standard-library workload moved to a Python Alpine base with package upgrades. The same functional tests passed, ECR scanning completed with zero reported findings, and the final build SUCCEEDED in about two minutes. This is a distinct remediation using musl rather than glibc. |

I found Debian vulnerabilities in glibc, Perl, SQLite, PCRE2 and zlib packages inherited from the base image. I preserved the reports and kept the same scanner and severity threshold. A successful Docker build alone is insufficient for release; an unsupported or failed scanner is also not a passing result.

I chose Alpine to reduce this workload's dependency surface, accepting a tradeoff: packages with native extensions may require musl-compatible wheels or compilation, and behavior can differ from glibc-based images. The current model uses Python's standard library. Every base change must repeat functional and security checks. The source archive is deterministic and the image tag immutable, while the upstream base tag can change over time; the recorded digest identifies the actual tested result.

I published [sanitized execution evidence](evidence/container-execution.json) with attempt statuses, digests, scan counts and metrics. I kept account-specific logs private and verified resource removal before recording cleanup.

My teardown check caught a manually shortened expected image tag before deleting anything. I corrected the check to read tags from saved source manifests and cross-check the three recorded digests. I removed the six recorded object versions and three images, then applied a reviewed destroy-only plan for the twelve remaining Terraform resources. The source object accounted for the thirteenth managed resource. At 06:23:58 UTC, AWS verified the repository, bucket, project, role and logs absent, and the local state had zero managed resources. All known builds were terminal or removed. This removed the temporary demonstration storage and compute path after its evidence was preserved.

## The public preview has a different purpose from the AWS application

I configured the GitHub Pages build to use `/streamml/`; it opens directly into clearly labelled sample data and disables login, token processing and API polling. Its browser policy also sets `connect-src 'none'`, preventing fetch/WebSocket connections. No credentials or AWS configuration are needed to publish it. The normal application build retains authenticated AWS integration code.

I configured the Pages workflow to build an artifact, verify its repository path and network policy, and deploy through a `github-pages` environment so GitHub records deployment history. [Run 34569734895](https://github.com/aliadiill/streamml/actions/runs/34569734895) succeeded for commit `fc2a698`. I then used the browser to verify the [published preview](https://aliadiill.github.io/streamml/), its automatic sample labels, dashboard and navigation; the [actual capture](screenshots/streamml-github-pages.png) is public. This establishes successful static-site publication separately from the completed AWS Docker test and the unrun full stack. The workflow follows [GitHub's custom Pages workflow guidance](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## What the model does not establish

I use the deterministic generator to make the engineering experiment repeatable. I have not validated it as a payment-fraud model. The holdout follows the same generator family as training; it does not measure performance on real customer behavior, adversarial fraud, shifting class prevalence or external datasets. Chronological splits and train-only normalization prevent specific forms of leakage but cannot remove every bias. The dashboard's live counters use explicit bootstrap rules; a SageMaker model is not silently substituted into that path. Human approval, actual cloud integration testing and wider validation remain separate requirements.

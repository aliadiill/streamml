# Isolated container proof on CodeBuild

The full StreamML stack is blocked by Kinesis subscription eligibility and zero quotas for the selected SageMaker ml.m5.large jobs. This independent Terraform root provisions only a private source/artifact bucket, an immutable ECR repository, a small transient CodeBuild project, scoped IAM and seven-day logs. It has no Kinesis, SageMaker job, CodePipeline, Lambda or always-running instance dependency.

This is a bounded way to demonstrate the actual Docker workload without implying that a SageMaker Pipeline executed. The authorized execution stays within the owner's USD 100 total promotional-credit ceiling, zero-out-of-pocket constraint and existing Free-plan service eligibility. See the actual execution record below.

## What the build does

1. Generate 3,000 deterministic synthetic transactions.
2. Build/push the actual ML Docker image, tagged by the deterministic source-archive SHA-256. Repeated identical sources pull the previously tested immutable image.
3. Run the real preprocessing entrypoint in a network-disabled container, creating chronological train/validation/test channels.
4. Run the actual training entrypoint in another container and save its model artifact.
5. Run held-out evaluation in a container and require the quality gate to pass.
6. Deliberately replace the model with an always-positive predictor and prove that its evaluation fails the gate.
7. Start the actual inference server temporarily, test /ping and three /invocations records over loopback, and stop the container.
8. Wait up to three minutes for ECR scanning, save the scan and digest, and fail the build for critical/high findings.

The CodeBuild build timeout is ten minutes, queue timeout ten minutes, and compute is BUILD_GENERAL1_SMALL. The runtime uses Docker privilege because it must start sibling containers; its role cannot create SageMaker jobs or alter the full application. Privileged CodeBuild should consume only the owner's reviewed source.

## Prepare and validate

From the project root:

```bash
python scripts/package_container_source.py
terraform -chdir=bootstrap/container-build init -backend=false
terraform -chdir=bootstrap/container-build fmt -check
terraform -chdir=bootstrap/container-build validate
terraform -chdir=bootstrap/container-build plan -out=reviewed.tfplan
```

The source packager uses an explicit file allowlist and fixed ZIP timestamps. It excludes Git metadata, credentials, local datasets, Terraform state, node_modules and screenshots. Inspect its manifest and review the exact plan before any apply.

## Authorized one-build execution

The operator applies the reviewed independent plan, reads the project_name output, starts one CodeBuild execution and records its real build ID/status. There is no scheduled trigger or automatic rerun.

```bash
terraform -chdir=bootstrap/container-build apply reviewed.tfplan
terraform -chdir=bootstrap/container-build output -json
aws codebuild start-build --project-name YOUR_PROJECT_NAME --region us-east-1
aws codebuild batch-get-builds --ids YOUR_RETURNED_BUILD_ID --region us-east-1
```

Inspect CloudWatch logs and the actual S3 artifact location returned by CodeBuild. The evidence ZIP contains the normal and rejected evaluation reports, three inference predictions, test summary, image digest, image inspection and ECR vulnerability report. If the scan fails, preserve that failure and do not describe the image as cleared for release.

Private artifacts can contain account-specific registry URLs and build identifiers. Publish a sanitized summary and selected true screenshots; do not blindly copy the entire artifact archive to a public repository.

## Teardown

After collecting evidence, verify the build is terminal. Review and delete this bootstrap's image and exact bucket versions/delete markers, then destroy this independent state. The resources deliberately default to force_destroy/force_delete false. Preserve the main project's source and any shared infrastructure. The source and logs expire after seven days if accidentally left behind; ECR tagged images still need explicit deletion.

## Evidence status

On 2026-09-11 UTC the independent bootstrap plan created exactly 13 managed resources with no updates or deletions. The first real CodeBuild ran from 06:00:07 to 06:01:16 UTC and reached artifact upload. Docker preprocessing, training, held-out evaluation, deliberate bad-model rejection and three real HTTP predictions passed. The trained model's held-out F1 was 0.929825; the deliberately bad model had F1 0.170732 and a false-positive rate of 1.0, so it correctly failed quality checks.

The first build status was **FAILED** because ECR scanning completed with **6 critical and 11 high** findings in the base image. The second attempt ran Debian security updates, but the repositories reported no upgrades and the same findings kept release blocked. Both attempts passed functional tests and preserved their failed scans.

The final authorized attempt switched this standard-library-only workload to `python:3.12-alpine` with `apk upgrade --no-cache`. It ran from **06:13:56 to 06:15:55 UTC** and was **SUCCEEDED**. The same Docker tests passed and ECR scanning reached **COMPLETE with zero reported findings**. The exact tested image digest was `sha256:ac2c4849c03b2b1f14149438df77b3a081513bb8045d5c14cae92190ac8c3593`. The security threshold was never lowered. See the [build journal](build-journal.md) for the musl/native-dependency tradeoff and actual failed attempts.

Public, sanitized evidence: [container execution](evidence/container-execution.json). Full artifacts and account-specific logs remain private. This scan describes the tested digest at that time; it is not a permanent vulnerability guarantee. No full StreamML deployment or SageMaker execution is claimed. Bootstrap teardown status is tracked in the evidence record.

# Isolated container proof on CodeBuild

I encountered Kinesis subscription restrictions and zero quotas for the selected SageMaker ml.m5.large jobs. To test the container independently, I built a separate Terraform configuration with only a private source/artifact bucket, an immutable ECR repository, a small transient CodeBuild project, scoped IAM and seven-day logs. It has no Kinesis, SageMaker job, CodePipeline, Lambda or always-running instance dependency.

I used this small experiment to demonstrate the actual Docker workload while the SageMaker execution was blocked. I kept each build under a ten-minute limit as part of my one-time $100 credit-budget approach. My execution record below includes both failures and the successful correction.

## What I tested

1. Generate 3,000 deterministic synthetic transactions.
2. Build/push the actual ML Docker image, tagged by the deterministic source-archive SHA-256. Repeated identical sources pull the previously tested immutable image.
3. Run the real preprocessing entrypoint in a network-disabled container, creating chronological train/validation/test channels.
4. Run the actual training entrypoint in another container and save its model artifact.
5. Run held-out evaluation in a container and require the quality gate to pass.
6. Deliberately replace the model with an always-positive predictor and prove that its evaluation fails the gate.
7. Start the actual inference server temporarily, test /ping and three /invocations records over loopback, and stop the container.
8. Wait up to three minutes for ECR scanning, save the scan and digest, and fail the build for critical/high findings.

I selected BUILD_GENERAL1_SMALL and set both build and queue timeouts to ten minutes. The runtime uses Docker privilege because it must start sibling containers; its role cannot create SageMaker jobs or alter the full application. I supplied an explicit source-file allowlist to the privileged build.

## Prepare and validate

I prepared and validated the source from the project directory:

```bash
python scripts/package_container_source.py
terraform -chdir=bootstrap/container-build init -backend=false
terraform -chdir=bootstrap/container-build fmt -check
terraform -chdir=bootstrap/container-build validate
terraform -chdir=bootstrap/container-build plan -out=reviewed.tfplan
```

I wrote the source packager with an explicit file allowlist and fixed ZIP timestamps. It excludes Git metadata, credentials, local datasets, Terraform state, node_modules and screenshots. I checked its manifest and Terraform plan before applying.

## My bounded build sequence

I applied the independent plan, read the project_name output and started a build manually. I recorded each build ID and terminal status. I made two bounded corrective attempts after the first image failed scanning; I added no scheduled trigger or automatic retry loop.

```bash
terraform -chdir=bootstrap/container-build apply reviewed.tfplan
terraform -chdir=bootstrap/container-build output -json
aws codebuild start-build --project-name YOUR_PROJECT_NAME --region us-east-1
aws codebuild batch-get-builds --ids YOUR_RETURNED_BUILD_ID --region us-east-1
```

I inspected CloudWatch logs and downloaded the artifacts from the location returned by CodeBuild. The evidence ZIP contains the normal and rejected evaluation reports, three inference predictions, test summary, image digest, image inspection and ECR vulnerability report. I preserved both failed scans and kept those images blocked from release.

I kept account-specific registry URLs and build identifiers in private artifacts, then published sanitized metrics and selected actual screenshots.

## Teardown

After collecting evidence, I verified terminal build states, checked the recorded image digests and bucket versions, emptied the temporary data and destroyed the independent configuration. The resources deliberately default to force_destroy/force_delete false. I preserved my source and shared infrastructure. The source and logs expire after seven days if accidentally left behind; ECR tagged images still need explicit deletion.

## Evidence status

On 2026-09-11 UTC, I applied a plan that created exactly 13 managed resources with no updates or deletions. The first real CodeBuild ran from 06:00:07 to 06:01:16 UTC and reached artifact upload. Docker preprocessing, training, held-out evaluation, deliberate bad-model rejection and three real HTTP predictions passed. The trained model's held-out F1 was 0.929825; the deliberately bad model had F1 0.170732 and a false-positive rate of 1.0, so it correctly failed quality checks.

My first build status was **FAILED** because ECR scanning completed with **6 critical and 11 high** findings in the base image. The second attempt ran Debian security updates, but the repositories reported no upgrades and the same findings kept release blocked. Both attempts passed functional tests and preserved their failed scans.

For my final attempt, I switched this standard-library-only workload to `python:3.12-alpine` with `apk upgrade --no-cache`. It ran from **06:13:56 to 06:15:55 UTC** and was **SUCCEEDED**. The same Docker tests passed and ECR scanning reached **COMPLETE with zero reported findings**. The exact tested image digest was `sha256:ac2c4849c03b2b1f14149438df77b3a081513bb8045d5c14cae92190ac8c3593`. The security threshold was never lowered. See the [build journal](build-journal.md) for the musl/native-dependency tradeoff and actual failed attempts.

I published sanitized evidence: [container execution](evidence/container-execution.json). I kept full artifacts and account-specific logs private. This scan describes the tested digest at that time; it is not a permanent vulnerability guarantee. I have not deployed the full StreamML stack or executed SageMaker.

At **06:23:58 UTC**, I verified the exact bootstrap ECR repository, S3 bucket, CodeBuild project, IAM role and CloudWatch log group absent. All three known builds were terminal or removed and the Terraform state contained zero managed resources. Six owned object versions and three recorded image digests were deleted before Terraform destroyed the twelve remaining resources; the thirteenth managed resource was the source object already removed during bucket emptying. I kept the teardown limited to this temporary configuration.

# CI/CD and MLOps are separate controls

## Source and verification

I defined CodePipeline to consume one GitHub branch through CodeConnections. CodeBuild verifies Python tests, the deterministic model experiment, Python compilation, TypeScript/React production build, npm audit, Terraform formatting, provider initialization and validation. Failure stops the pipeline before the manual deployment review.

The provider lock and npm lock belong in Git. No Terraform state, credentials, dashboard local environment file, tokens or private AWS evidence belong in Git.

## Deployment

After a human reviews the concrete source change, test output and cost implication, the deploy build prepares Lambda packaging, frontend assets and the ML image, scans the image, and compiles the pipeline definition before mutating the application. It updates the three functions, uploads static assets, invalidates the HTML entry, and updates the existing SageMaker pipeline definition.

I kept infrastructure changes in a separate Terraform plan/apply workflow. This CI role does not have broad account administrator or IAM provisioning permissions. The default pipeline does not retrain on every commit. `run_training_after_deploy` is a separate, initially false switch.

I added deployment gates, but I have not implemented a multi-resource atomic release. If an AWS update fails after another succeeded, inspect the execution and restore the previous known source artifact. A production rollout should add Lambda aliases/version routing, integration smoke tests with a controlled machine identity, and automated canary rollback. I have not implemented those rollout extensions.

## ML promotion

I separated model release from application delivery: training creates a candidate, evaluates unseen data and may register a version. Registry registration sets PendingManualApproval. That is a distinct decision from the CodePipeline deployment review. A human reviews quality, error costs, provenance and the prior model before approving a package.

I made the batch script reject a pending or rejected package before creating infrastructure. Drift can start a new training pipeline only under the explicit switches, data/support requirements, two-breach requirement and cooldown. It cannot approve or deploy its own replacement.

## Verification status

I have not run the main GitHub-triggered AWS CodePipeline, full application deployment, SageMaker execution or rollback. Separately, I used the isolated AWS CodeBuild configuration to run three actual Docker builds: two Debian images failed the strict vulnerability gate, then the Alpine image passed functional tests and completed ECR scanning with zero reported findings. I removed its temporary infrastructure and verified absence. See [container evidence](container-build.md).

I also ran the separate static dashboard workflow [34569734895](https://github.com/aliadiill/streamml/actions/runs/34569734895). It succeeded and published the [browser-verified Pages preview](https://aliadiill.github.io/streamml/). It uses the `github-pages` deployment environment, requires no AWS credentials, and blocks AWS connection requests. See [Pages delivery and verification](pages-preview.md).

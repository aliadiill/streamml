# CI/CD and MLOps are separate controls

## Source and verification

The Terraform-defined CodePipeline consumes one configured GitHub branch through an existing authorized CodeConnections connection. CodeBuild verifies Python tests, the deterministic model experiment, Python compilation, TypeScript/React production build, npm audit, Terraform formatting, provider initialization and validation. Failure stops the pipeline before the manual deployment review.

The provider lock and npm lock belong in Git. No Terraform state, credentials, dashboard local environment file, tokens or private AWS evidence belong in Git.

## Deployment

After a human reviews the concrete source change, test output and cost implication, the deploy build prepares Lambda packaging, frontend assets and the ML image, scans the image, and compiles the pipeline definition before mutating the application. It updates the three functions, uploads static assets, invalidates the HTML entry, and updates the existing SageMaker pipeline definition.

Infrastructure creation and destructive changes remain a separately reviewed Terraform plan/apply. This CI role does not have broad account administrator or IAM provisioning permissions. The default pipeline does not retrain on every commit. `run_training_after_deploy` is a separate, initially false switch.

The deployment is gated but not a multi-resource atomic release. If an AWS update fails after another succeeded, inspect the execution and restore the previous known source artifact. A production rollout should add Lambda aliases/version routing, integration smoke tests with a controlled machine identity, and automated canary rollback. Those capabilities are not claimed here.

## ML promotion

Training creates a candidate, evaluates unseen data and may register a version. Registry registration sets PendingManualApproval. That is a distinct decision from the CodePipeline deployment review. A human reviews quality, error costs, provenance and the prior model before approving a package.

The batch script rejects a pending or rejected package before creating infrastructure. Drift can start a new training pipeline only under the explicit switches, data/support requirements, two-breach requirement and cooldown. It cannot approve or deploy its own replacement.

## Verification status

The configuration and scripts were validated locally as recorded in testing. No actual GitHub-triggered CodePipeline execution, ECR scan, deployment, SageMaker execution or rollback has been run by this implementation task. Capture those results during the authorized cloud acceptance phase.


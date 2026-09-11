# Deployment and configuration

## Eligibility and boundaries

The full StreamML Terraform root remains unapplied because account checks returned a Kinesis subscription/plan restriction. A separate [container-test bootstrap](container-build.md) was applied, successfully ran real Docker ML/HTTP checks and ECR scanning, and was then fully removed with absence verified. The [static Pages preview](pages-preview.md) is published and browser-verified. Neither demonstration establishes the full streaming integration.

The owner requires zero personal spending and permits at most USD 100 total promotional-credit use. A paid plan upgrade is not authorized. The complete stack must remain undeployed while Kinesis is unavailable under those constraints. The steps below are a reproducible deployment runbook for an eligible environment, not an instruction to apply in the currently restricted account. This repository does not change the account's plan, billing, organization, or administrative users.

Use `us-east-1` and short-lived IAM/federated credentials. Confirm Kinesis availability, SageMaker Processing/Training/Transform quotas for `ml.m5.large`, Lambda concurrency, remaining credits and an intended teardown time. No credentials belong in Terraform variables or Git.

On 2026-09-11 UTC account checks verified that ml.m5.large training, processing and transform quotas are all zero in us-east-1. The applied-quota listing showed processing alternatives ml.t3.medium=4, ml.t3.large=4 and ml.t3.xlarge=2, but no positive training or transform instance quota. These alternatives do not unblock the specified full pipeline. Along with the Kinesis subscription restriction, this blocks the full live demonstration. Keep the source and observed evidence; no quota increase or paid plan change is requested by this runbook.

## 1. Build and validate locally

```bash
python -m pip install -r requirements.txt
python -m unittest discover -s tests -v
python scripts/package.py
cd dashboard
npm ci
npm run build
cd ..
terraform -chdir=infra init -backend=false
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
```

For durable state, copy `infra/backend.tf.example` to `backend.tf` and supply an approved encrypted, versioned, private S3 state bucket through init options. Native S3 lockfiles are enabled. The state bucket is deliberately separate from application buckets so application teardown does not destroy state. Local state is acceptable only for a single-operator initial lab and must remain private.

## 2. Initial infrastructure

Copy the example variables to a local ignored file. Keep the ML image empty, monitoring disabled, retraining disabled and CI disabled for initial creation. Review a Terraform plan, including its total ongoing services and resource deletions, before applying that exact saved plan.

```bash
terraform -chdir=infra plan -out=reviewed.tfplan
terraform -chdir=infra apply reviewed.tfplan
terraform -chdir=infra output -json > build/outputs.json
```

If Kinesis eligibility is blocked, stop. Do not substitute a local queue and claim that the required streaming integration is deployed.

## 3. Container, model workflow and source pipeline

Build `ml/Dockerfile` using the project root as context. Tag the image with a source commit, authenticate Docker to the project ECR registry using temporary AWS credentials, and push. Inspect the image scan before use. Set `ml_image_uri` to that immutable image URI and apply a separately reviewed plan to create the SageMaker pipeline.

Create or reuse an authorized GitHub CodeConnections connection, complete its GitHub installation, and supply the exact repository, connection ARN and branch. Set `enable_ci=true` only after the ML pipeline exists. Leave `run_training_after_deploy=false` for ordinary code iterations. Account identifiers and the actual connection ARN should remain in local configuration.

The project operations SNS topic has no email/chat subscription by default. Configure only the owner's confirmed authorized destination, confirm any subscription, and exercise notification delivery before treating alarms as delivered.

## 4. Dashboard and first events

Use Terraform outputs to configure the public Cognito client ID, hosted UI domain, and redirect URL. In the deployed dashboard, `VITE_API_URL` is empty because CloudFront routes `/api/*` to the authenticated HTTP API. For local development, set the API Gateway URL and use the registered localhost callback.

Create a learning user through Cognito's administrative flow. The pool disallows public self-signup. Complete the initial password change and use TOTP MFA where practical. Sign in through the hosted authorization-code/PKCE flow; do not paste tokens into documentation.

Publish at most 1,000 current-time events initially:

```bash
PYTHONPATH=src python -m streamml.generator --count 1000 --stream YOUR_STREAM --region us-east-1 --rate 10
```

For Windows PowerShell, set `$env:PYTHONPATH="src"` before the Python command. Verify accepted counts, raw objects, quarantine handling, dashboard authentication and stream lag. Re-submit the exact same seed/start events within seven days and confirm no double-count.

## 5. ML experiment

A pipeline needs at least 500 unique labelled records and a meaningful chronological split. Start one execution with maximum parallel steps set to one. Record the execution ARN privately, real status, evaluation report, registered package version and rejection/approval evidence.

Review and approve a qualifying package. Upload one bounded inference JSONL file to a dedicated ML input location and invoke `scripts/batch_approved.py` with its exact bucket, package, SageMaker role and output location. Inspect the produced scores; never infer success from a submitted job ID.

Only after baseline creation and cloud validation should you consider enabling the scheduled monitor. Automatic retraining remains a separate explicit switch.

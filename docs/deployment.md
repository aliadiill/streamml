# Deployment and configuration

## Eligibility and boundaries

I left the full StreamML Terraform configuration unapplied after Kinesis returned a subscription restriction. I applied a separate [container-test configuration](container-build.md), ran Docker ML/HTTP tests and ECR scanning, then removed it and verified cleanup. I also published and browser-tested the [Pages preview](pages-preview.md). I have not yet tested the full streaming integration.

I aimed for a one-time $100 credit budget, stayed on the Free plan and used short experiments. The sequence below is my plan for reproducing the full stack in an eligible environment. I distinguish those future steps from the completed container and Pages deployments.

I chose `us-east-1` and temporary IAM credentials. Before a full deployment, I would check Kinesis availability, SageMaker Processing/Training/Transform quotas for `ml.m5.large`, Lambda concurrency, remaining credits and an intended teardown time. No credentials belong in Terraform variables or Git.

On 2026-09-11 UTC, I verified that ml.m5.large training, processing and transform quotas are all zero in us-east-1. The applied-quota listing showed processing alternatives ml.t3.medium=4, ml.t3.large=4 and ml.t3.xlarge=2, but no positive training or transform instance quota. These alternatives do not unblock the specified full pipeline. Along with the Kinesis subscription restriction, this blocks the full live demonstration. I kept the implementation and observed evidence while leaving the full pipeline unrun.

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

For a durable deployment, I would copy `infra/backend.tf.example` to `backend.tf` and supply an encrypted, versioned, private S3 state bucket through init options. Native S3 lockfiles are enabled. The state bucket is deliberately separate from application buckets so application teardown does not destroy state. Local state is acceptable only for a single-operator initial lab and must remain private.

## 2. Initial infrastructure

For the future full-stack deployment, I would copy the example variables to a local ignored file and keep the ML image empty, monitoring disabled, retraining disabled and CI disabled for initial creation. Review a Terraform plan, including its total ongoing services and resource deletions, before applying that exact saved plan.

```bash
terraform -chdir=infra plan -out=reviewed.tfplan
terraform -chdir=infra apply reviewed.tfplan
terraform -chdir=infra output -json > build/outputs.json
```

I stopped before full-stack provisioning when Kinesis eligibility was blocked. My container demonstration does not substitute for the unrun streaming integration.

## 3. Container, model workflow and source pipeline

I build `ml/Dockerfile` using the project directory as context. Tag the image with a source commit, authenticate Docker to the project ECR registry using temporary AWS credentials, and push. Inspect the image scan before use. Set `ml_image_uri` to that immutable image URI and apply a separately reviewed plan to create the SageMaker pipeline.

For AWS CI/CD, I would configure a GitHub CodeConnections connection, complete its GitHub installation, and supply the exact repository, connection ARN and branch. Set `enable_ci=true` only after the ML pipeline exists. Leave `run_training_after_deploy=false` for ordinary code iterations. Account identifiers and the actual connection ARN should remain in local configuration.

I left the operations SNS topic without an email/chat subscription. Before relying on alerts, I would configure a destination, confirm the subscription and test delivery.

## 4. Dashboard and first events

For the AWS dashboard, I would use Terraform outputs to configure the public Cognito client ID, hosted UI domain, and redirect URL. In the deployed dashboard, `VITE_API_URL` is empty because CloudFront routes `/api/*` to the authenticated HTTP API. For local development, set the API Gateway URL and use the registered localhost callback.

I would create a learning user through Cognito's administrative flow. The pool disallows public self-signup. Complete the initial password change and use TOTP MFA where practical. Sign in through the hosted authorization-code/PKCE flow; do not paste tokens into documentation.

My first streaming test would publish at most 1,000 current-time events:

```bash
PYTHONPATH=src python -m streamml.generator --count 1000 --stream YOUR_STREAM --region us-east-1 --rate 10
```

In Windows PowerShell, I set `$env:PYTHONPATH="src"` before the Python command. Verify accepted counts, raw objects, quarantine handling, dashboard authentication and stream lag. Re-submit the exact same seed/start events within seven days and confirm no double-count.

## 5. ML experiment

I require at least 500 unique labelled records and a meaningful chronological split. My first SageMaker test would start one execution with maximum parallel steps set to one. Record the execution ARN privately, real status, evaluation report, registered package version and rejection/approval evidence.

I would inspect the held-out report before approving a qualifying model package. Upload one bounded inference JSONL file to a dedicated ML input location and invoke `scripts/batch_approved.py` with its exact bucket, package, SageMaker role and output location. Inspect the produced scores; never infer success from a submitted job ID.

I would enable the scheduled monitor only after baseline creation and cloud validation. Automatic retraining remains a separate explicit switch.

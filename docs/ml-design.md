# Model, pipeline and release gates

## Baseline

The standard-library implementation is logistic regression with fixed initialization and full-batch gradient descent. Features are log amount, log distance, attempts in the past hour, merchant risk, and online status. No ground-truth label, card identity, event ID, or post-outcome field becomes a feature.

Synthetic fraud populations overlap with normal activity. Merchant risk, distance, transaction value and velocity carry signal; the label is not copied into the model. Synthetic distributions still make this much simpler than real fraud detection. The model is evidence of an implemented engineering workflow, not evidence of commercial predictive validity.

## Reproducibility and leakage control

The generator has a fixed seed and timestamp for local datasets. Publishing defaults to the current UTC time so live dashboard windows are meaningful. Record the explicit seed and start value when reproducing a streaming demo.

Preprocessing validates, deduplicates and chronologically orders events. Conflicting IDs fail the job. The oldest 60% train the model, the next 20% select an operating threshold, and the final 20% form the untouched test set. Equal timestamps stay together. Training computes means and scales using training rows only; held-out data cannot affect normalization or coefficient fitting.

The five numerical features do not use card identity. A real deployment should additionally consider delayed labels, rolling backtests, merchant/card cohort holdouts and changing fraud tactics. These are documented extensions, not tests claimed here.

## Actual SageMaker DAG

`ml/build_pipeline.py` compiles the SageMaker JSON DAG, and `infra/pipeline.json.tftpl` is generated from the same function. The compiler makes no network call and can be tested without credentials. Terraform supplies the project role, immutable ECR image, bucket and package group.

1. **Preprocess / Processing:** read the bounded raw input and produce train, validation, and test channels.
2. **Train / Training:** fit coefficients on train; select threshold on validation; write `model.json` to the SageMaker model directory.
3. **Evaluate / Processing:** unpack only the expected bounded model member, evaluate the held-out channel, and write `evaluation.json`.
4. **QualityGate / Condition:** require F1 ≥ 0.80, recall ≥ 0.70, false-positive rate ≤ 0.10, at least 100 test rows, at least five positives, and at least five negatives.
5. **Pass / RegisterModel:** create a version in the project registry with `PendingManualApproval`.
6. **Reject / Fail:** stop the execution with a clear rejection message. An EventBridge rule routes pipeline failure events to the operations SNS topic; no destination subscription or delivery is claimed.

This is the DAG structure required by [SageMaker pipeline definitions](https://docs.aws.amazon.com/sagemaker/latest/dg/define-pipeline.html); model registration is a distinct [registry operation](https://docs.aws.amazon.com/sagemaker/latest/dg/model-registry-version.html).

## Human approval and bounded inference

A human reviews the held-out report and marks one package version Approved. `scripts/batch_approved.py` checks that state before creating any model or transform job. The script requires input/output in the project's ML prefix and limits the exact input object to 1 MiB. It provisions one `ml.m5.large`, one concurrent request, a 1 MiB payload ceiling and bounded invocation retries.

The caller runs a deadline loop, requesting StopTransformJob after 15 minutes by default (maximum allowed 30). If the caller is terminated, the client deadline cannot run; this is not a server-side hard spending cap. Use the monitoring runbook to verify jobs are terminal. No inference endpoint is created.

After a completed transform, the script stores the approved model's normalization reference under `ml/baseline/approved.json`. Only this approved baseline drives drift comparison. A rejected candidate, failed transform, or pending registry version cannot silently replace it.

## Drift and controlled retraining

The monitor compares each current feature mean with its approved training mean in units of the training standard deviation. A shift of 0.75 or more is a signal, not proof of performance failure. It requires at least 500 labelled recent rows, both classes, two consecutive monitor breaches, explicit enablement and a conditional 24-hour cooldown.

Both the schedule and automatic retraining are off by default. A retraining attempt snapshots its bounded input, uses an idempotent pipeline request token, and retains the same quality and manual approval gates. A failed start preserves the cooldown conservatively rather than repeatedly retrying a billable operation. Investigate the logs before resetting it.

Ground-truth performance metrics are computed in evaluation. The current drift monitor does not automatically score a newly labelled production holdout or report AUC/calibration. Add those only with suitable real labels and a clear business objective.


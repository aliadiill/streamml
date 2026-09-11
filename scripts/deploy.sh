#!/usr/bin/env bash
set -euo pipefail
# Prepare and verify every artifact before mutating a running application.
python scripts/package.py
export PYTHONPATH=src:ml
python -m unittest discover -s tests -v
(cd dashboard && npm ci && npm run build && npm audit --audit-level=high)
tag="${CODEBUILD_RESOLVED_SOURCE_VERSION:0:12}"
test -n "$tag"
registry="${ECR_REPOSITORY%%/*}"
aws ecr get-login-password | docker login --username AWS --password-stdin "$registry"
if ! aws ecr describe-images --repository-name "$ECR_NAME" --image-ids "imageTag=$tag" > /dev/null 2>&1; then
  docker build -f ml/Dockerfile -t "$ECR_REPOSITORY:$tag" .
  docker push "$ECR_REPOSITORY:$tag"
fi
aws ecr wait image-scan-complete --repository-name "$ECR_NAME" --image-id "imageTag=$tag"
aws ecr describe-image-scan-findings --repository-name "$ECR_NAME" --image-id "imageTag=$tag" > build/image-scan.json
python -c 'import json; r=json.load(open("build/image-scan.json")); c=r["imageScanFindings"].get("findingSeverityCounts", {}); assert not(c.get("CRITICAL",0) or c.get("HIGH",0)), "Image vulnerability gate failed"'
python ml/build_pipeline.py --role "$SAGEMAKER_ROLE" --image "$ECR_REPOSITORY:$tag" --bucket "$LAKE_BUCKET" --group "$PROJECT_NAME"
# All local/security gates above have passed. Infrastructure remains a reviewed Terraform apply.
for component in ingest api monitor; do
  aws lambda update-function-code --function-name "$PROJECT_NAME-$component" --zip-file fileb://build/lambda.zip > /dev/null
  aws lambda wait function-updated --function-name "$PROJECT_NAME-$component"
done
aws s3 sync dashboard/dist/ "s3://$WEB_BUCKET/" --delete --cache-control max-age=300
aws s3 cp dashboard/dist/index.html "s3://$WEB_BUCKET/index.html" --cache-control no-cache
aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths /index.html > /dev/null
aws sagemaker update-pipeline --pipeline-name "$PROJECT_NAME" --role-arn "$SAGEMAKER_ROLE" --pipeline-definition file://build/pipeline.json > /dev/null
if [ "$RUN_TRAINING" = true ]; then
  aws sagemaker start-pipeline-execution --pipeline-name "$PROJECT_NAME" --parallelism-configuration MaxParallelExecutionSteps=1
fi

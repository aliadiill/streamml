#!/usr/bin/env bash
set -euo pipefail
# This build uses Docker on transient CodeBuild compute. It never starts a SageMaker job.
mkdir -p build/container/{input,processed,model,model-artifact,evaluation,bad-model,bad-artifact,rejected,results}
export PYTHONPATH=src
python -m streamml.generator --count 3000 --seed 42 --output build/container/input/transactions.jsonl
image="$ECR_REPOSITORY:$IMAGE_TAG"
registry="${ECR_REPOSITORY%%/*}"
aws ecr get-login-password | docker login --username AWS --password-stdin "$registry"
if aws ecr describe-images --repository-name "$ECR_NAME" --image-ids "imageTag=$IMAGE_TAG" > /dev/null 2>&1; then
  docker pull "$image"
else
  docker build --pull -f ml/Dockerfile -t "$image" .
  docker push "$image"
fi
docker image inspect "$image" > build/container/results/docker-image.json
docker version --format '{{json .}}' > build/container/results/docker-version.json
docker run --rm --network none \
  -v "$PWD/build/container/input:/opt/ml/processing/input/data:ro" \
  -v "$PWD/build/container/processed:/opt/ml/processing/output" "$image" preprocess
docker run --rm --network none \
  -v "$PWD/build/container/processed/train:/opt/ml/input/data/train:ro" \
  -v "$PWD/build/container/processed/validation:/opt/ml/input/data/validation:ro" \
  -v "$PWD/build/container/model:/opt/ml/model" "$image" train
tar -czf build/container/model-artifact/model.tar.gz -C build/container/model model.json
docker run --rm --network none \
  -v "$PWD/build/container/model-artifact:/opt/ml/processing/input/model:ro" \
  -v "$PWD/build/container/processed/test:/opt/ml/processing/input/test:ro" \
  -v "$PWD/build/container/evaluation:/opt/ml/processing/output/evaluation" "$image" evaluate
cp build/container/evaluation/evaluation.json build/container/results/evaluation.json
python - <<'PY'
import json
from pathlib import Path
report = json.loads(Path("build/container/results/evaluation.json").read_text())
assert report["passed"], report
model = json.loads(Path("build/container/model/model.json").read_text())
model["weights"] = [0.0 for _ in model["weights"]]
model["bias"] = 20.0
Path("build/container/bad-model/model.json").write_text(json.dumps(model))
PY
tar -czf build/container/bad-artifact/model.tar.gz -C build/container/bad-model model.json
docker run --rm --network none \
  -v "$PWD/build/container/bad-artifact:/opt/ml/processing/input/model:ro" \
  -v "$PWD/build/container/processed/test:/opt/ml/processing/input/test:ro" \
  -v "$PWD/build/container/rejected:/opt/ml/processing/output/evaluation" "$image" evaluate
cp build/container/rejected/evaluation.json build/container/results/rejected-evaluation.json
python -c 'import json; r=json.load(open("build/container/results/rejected-evaluation.json")); assert r["passed"] is False, "Bad model unexpectedly passed"'
container=""
cleanup() { if [ -n "$container" ]; then docker stop "$container" > /dev/null || true; fi; }
trap cleanup EXIT
container=$(docker run --rm --detach -p 127.0.0.1:18080:8080 \
  -v "$PWD/build/container/model:/opt/ml/model:ro" "$image" serve)
curl --fail --silent --show-error --retry 8 --retry-connrefused --retry-delay 1 http://127.0.0.1:18080/ping > /dev/null
head -n 3 build/container/processed/test/data.jsonl > build/container/inference.jsonl
curl --fail --silent --show-error -H 'Content-Type: application/jsonlines' \
  --data-binary @build/container/inference.jsonl http://127.0.0.1:18080/invocations > build/container/results/predictions.jsonl
python - <<'PY'
import json, os
from datetime import datetime, timezone
from pathlib import Path
rows = [json.loads(line) for line in Path("build/container/results/predictions.jsonl").read_text().splitlines()]
assert len(rows) == 3 and all(0 <= r["probability"] <= 1 and isinstance(r["anomaly"], bool) for r in rows)
Path("build/container/results/test-summary.json").write_text(json.dumps({
    "timestamp": datetime.now(timezone.utc).isoformat(), "source_hash": os.environ["SOURCE_HASH"],
    "preprocess": "passed", "training": "passed", "heldout_quality": "passed",
    "bad_model_rejection": "passed", "http_predictions": len(rows),
    "execution_kind": "Docker containers on AWS CodeBuild; not a SageMaker pipeline execution"
}, indent=2))
PY
cleanup
container=""
# Bound the scan wait inside the ten-minute CodeBuild timeout. Scan failure is visible.
timeout 180s aws ecr wait image-scan-complete --repository-name "$ECR_NAME" --image-id "imageTag=$IMAGE_TAG"
aws ecr describe-image-scan-findings --repository-name "$ECR_NAME" --image-id "imageTag=$IMAGE_TAG" > build/container/results/image-scan.json
aws ecr describe-images --repository-name "$ECR_NAME" --image-ids "imageTag=$IMAGE_TAG" > build/container/results/ecr-image.json
python - <<'PY'
import json
from pathlib import Path
scan = json.loads(Path("build/container/results/image-scan.json").read_text())
counts = scan["imageScanFindings"].get("findingSeverityCounts", {})
image = json.loads(Path("build/container/results/ecr-image.json").read_text())["imageDetails"][0]
Path("build/container/results/image-digest.txt").write_text(image["imageDigest"] + "\n")
assert not counts.get("CRITICAL", 0) and not counts.get("HIGH", 0), "Container vulnerability gate failed; inspect image-scan.json"
PY


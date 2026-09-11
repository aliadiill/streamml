"""One container supports SageMaker Processing, Training, and batch inference."""
import argparse
import json
import os
import tarfile
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from model import drift, metrics, predict, quality, split, train

# Validation code is shipped in the same image; labels never enter model.features().
from streamml.core import validate


def read_rows(path):
    files = [path] if path.is_file() else sorted(p for p in path.rglob("*") if p.is_file() and p.suffix in (".json", ".jsonl"))
    rows = []
    for file in files:
        for line in file.read_text(encoding="utf-8").splitlines():
            if line.strip():
                rows.append(validate(json.loads(line)))
                if len(rows) > 10000:
                    raise ValueError("Dataset exceeds 10000-record budget")
    return rows


def write_rows(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(r) + "\n" for r in rows), encoding="utf-8")


def serve():
    model = json.loads(Path("/opt/ml/model/model.json").read_text())
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200 if self.path == "/ping" else 404)
            self.end_headers()
        def do_POST(self):
            if self.path != "/invocations":
                self.send_error(404)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 1 <= length <= 1048576:
                    raise ValueError("Payload size")
                rows = [validate(json.loads(line)) for line in self.rfile.read(length).decode().splitlines() if line]
                output = "\n".join(json.dumps({"event_id": r["event_id"], "probability": predict(model, r),
                                              "anomaly": predict(model, r) >= model["threshold"]}) for r in rows)
                self.send_response(200)
                self.send_header("Content-Type", "application/jsonlines")
                self.end_headers()
                self.wfile.write(output.encode())
            except (ValueError, KeyError):
                self.send_error(400, "Invalid transaction input")
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["preprocess", "train", "evaluate", "serve"])
    args = parser.parse_args()
    if args.mode == "serve":
        serve()
    elif args.mode == "preprocess":
        groups = split(read_rows(Path("/opt/ml/processing/input/data")))
        for name, rows in zip(("train", "validation", "test"), groups):
            write_rows(Path(f"/opt/ml/processing/output/{name}/data.jsonl"), rows)
    elif args.mode == "train":
        model = train(read_rows(Path("/opt/ml/input/data/train")),
                      read_rows(Path("/opt/ml/input/data/validation")))
        target = Path(os.environ.get("SM_MODEL_DIR", "/opt/ml/model"))
        target.mkdir(parents=True, exist_ok=True)
        (target / "model.json").write_text(json.dumps(model))
    else:
        artifact = next(Path("/opt/ml/processing/input/model").glob("*.tar.gz"))
        with tarfile.open(artifact) as archive:
            member = archive.getmember("model.json")
            if not member.isfile() or member.size > 1048576:
                raise ValueError("Invalid model artifact")
            model = json.load(archive.extractfile(member))
        report = metrics(read_rows(Path("/opt/ml/processing/input/test")), model)
        report["passed"] = quality(report)
        path = Path("/opt/ml/processing/output/evaluation")
        path.mkdir(parents=True, exist_ok=True)
        (path / "evaluation.json").write_text(json.dumps(report))
        print(json.dumps(report))


if __name__ == "__main__":
    main()


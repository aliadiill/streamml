"""Run the actual generator, split, trainer, evaluator and drift detector offline."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "src"), str(ROOT / "ml")]
from streamml.generator import generate
from streamml.core import validate
from model import drift, metrics, quality, split, train

rows = [validate(row) for row in generate(3000)]
train_rows, validation, test = split(rows)
model = train(train_rows, validation)
report = metrics(test, model)
report["passed"] = quality(report)
report["split"] = {"train": len(train_rows), "validation": len(validation), "test": len(test)}
report["drifted_sample"] = drift(list(generate(500, seed=99, drift=True)), model)
target = ROOT / ".local"
target.mkdir(exist_ok=True)
(target / "model.json").write_text(json.dumps(model, indent=2))
(target / "evaluation.json").write_text(json.dumps(report, indent=2))
(target / "transactions.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))
print(json.dumps(report, indent=2))


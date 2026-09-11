"""Assemble Lambda source and compile the Terraform pipeline template, locally."""
import json
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ml"))
from build_pipeline import build


def package():
    target = ROOT / "build" / "lambda" / "streamml"
    target.mkdir(parents=True, exist_ok=True)
    for file in (ROOT / "src" / "streamml").glob("*.py"):
        shutil.copy2(file, target / file.name)
    with zipfile.ZipFile(ROOT / "build" / "lambda.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for file in target.glob("*.py"):
            archive.write(file, "streamml/" + file.name)
    definition = build("${role_arn}", "${image_uri}", "${bucket_name}", "${package_group}")
    (ROOT / "infra" / "pipeline.json.tftpl").write_text(json.dumps(definition, indent=2), encoding="utf-8")


if __name__ == "__main__":
    package()

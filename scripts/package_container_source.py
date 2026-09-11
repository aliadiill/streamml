"""Build a deterministic, explicit allowlist archive without credentials or local data."""
import hashlib
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def package(output=None):
    files = [ROOT / "buildspec-container.yml", ROOT / "scripts" / "container_test.sh"]
    files += list((ROOT / "src" / "streamml").glob("*.py"))
    files += [ROOT / "ml" / name for name in ("Dockerfile", "job.py", "model.py", "build_pipeline.py")]
    target = Path(output) if output else ROOT / "build" / "container-source.zip"
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(files):
            relative = file.relative_to(ROOT).as_posix()
            metadata = zipfile.ZipInfo(relative, date_time=(2026, 1, 1, 0, 0, 0))
            metadata.compress_type = zipfile.ZIP_DEFLATED
            metadata.create_system = 3
            metadata.external_attr = 0o644 << 16
            archive.writestr(metadata, file.read_bytes().replace(b"\r\n", b"\n"))
    return {"archive": str(target), "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
            "files": [p.relative_to(ROOT).as_posix() for p in sorted(files)]}


if __name__ == "__main__":
    print(json.dumps(package(), indent=2))

"""Freeze observed live screenshots as development regression, never a training bank."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "backend/tests/fixtures/student_potential_f3_live"
CASES = [
    ("mika-basic-2560", "debug/scanner_f3_live/00-initial.png", "basic", 90, 5, [25,25,25]),
    ("mika-stat-2560", "debug/scanner_f3_live/mika-stat-roundtrip-retry/opened.png", "stat", 90, 5, [25,25,25]),
    ("hina-basic-2560", "debug/scanner_f3_live/05-next-student.png", "basic", 90, 5, [25,25,0]),
    ("hina-stat-2560", "debug/scanner_f3_live/hina-stat-roundtrip/opened.png", "stat", 90, 5, [25,25,0]),
    ("miyu-basic-2560", "debug/scanner_f3_live/03-last-student.png", "basic", 1, 3, [0,0,0]),
    ("mika-basic-1280", "debug/scanner_f2_live/05-basic-restored.png", "basic", 90, 5, [25,25,25]),
]


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    assets = []
    for name, source, panel, level, star, values in CASES:
        path = DEST / (name+".png")
        shutil.copy2(ROOT/source, path)
        assets.append(dict(file=path.name, source=source, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                           panel=panel, level=level, student_star=star, potential=values))
    (DEST/"manifest.json").write_text(json.dumps(dict(version=1,
        partition="development_regression_not_holdout_or_runtime_learning",
        note="Real client captures; 1280 sample from F2. Expected values visually reviewed. Template-derived unit tests are separate.",
        assets=assets), indent=2)+"\n",encoding="utf-8")


if __name__ == "__main__": main()

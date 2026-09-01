"""Freeze native1280 F3 recheck and F4 level-tab development regression screenshots."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "backend/tests/fixtures/student_level_f4_live"
CASES = [
    ("f3-mika-basic", "debug/scanner_f3_1280_live/00-basic.png", "basic", None, [25,25,25]),
    ("f3-mika-stat", "debug/scanner_f3_1280_live/mika-stat/opened.png", "stat", None, [25,25,25]),
    ("f3-hina-stat", "debug/scanner_f3_1280_live/hina-stat/opened.png", "stat", None, [25,25,0]),
    ("mika-basic", "debug/scanner_f4_live/00-mika.png", "basic", 90, None),
    ("mika-level", "debug/scanner_f4_live/mika-level/opened.png", "level", 90, None),
    ("mika-return", "debug/scanner_f4_live/mika-level/returned.png", "basic", 90, None),
    ("miyu-basic", "debug/scanner_f4_live/01-miyu.png", "basic", 1, None),
    ("miyu-level", "debug/scanner_f4_live/miyu-level/opened.png", "level", 1, None),
    ("miyu-return", "debug/scanner_f4_live/miyu-level/returned.png", "basic", 1, None),
]


def main():
    DEST.mkdir(parents=True,exist_ok=True)
    rows = []
    for name, source, state, level, potential in CASES:
        path = DEST/(name+".png")
        shutil.copy2(ROOT/source,path)
        rows.append(dict(file=path.name,source=source,state=state,level=level,potential=potential,
                         sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (DEST/"manifest.json").write_text(json.dumps(dict(version=1,actual_client_size=[1280,720],
        partition="development_regression_not_holdout_or_runtime_learning",assets=rows),indent=2)+"\n",encoding="utf-8")


if __name__ == "__main__": main()

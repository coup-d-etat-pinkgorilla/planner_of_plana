"""Install the student-stat catalog and formula tables built from the JP client into the app.

Source (produced by data/extracted/pipeline/run_all.py, local files only):
  data/extracted/student-stats-jp.json          -> backend/data/student_stats/v1/catalog.json
  data/extracted/student-stat-formula-jp.json   -> backend/data/student_stats/v1/formula.json

Both files are validated with the v1 DTOs before anything is replaced, and written atomically.
This supersedes sync_student_stats_from_schaledb.py for the planner's stat data; SchaleDB is no
longer the calculation source (GAME_RULES.md section 4).

usage: py -3.11 tools/sync_student_stats_from_extracted.py [--extracted ../data/extracted] [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from core.student_stats_types import StudentStatCatalogV1, StudentStatFormulaV1  # noqa: E402

TARGET_DIR = ROOT / "data" / "student_stats" / "v1"
PAIRS = (("student-stats-jp.json", "catalog.json", StudentStatCatalogV1),
         ("student-stat-formula-jp.json", "formula.json", StudentStatFormulaV1))


def _atomic_write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--extracted", type=Path, default=ROOT.parent / "data" / "extracted")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    loaded = []
    for source_name, target_name, dto in PAIRS:
        source = args.extracted / source_name
        raw = source.read_bytes()
        parsed = dto.from_dict(json.loads(raw))          # raises on any contract violation
        loaded.append((source, TARGET_DIR / target_name, raw, parsed))
    catalog, formula = loaded[0][3], loaded[1][3]
    print(f"catalog: {len(catalog.students)} students, {len(catalog.equipment)} equipment rows "
          f"({catalog.source.get('students', '?')})")
    print(f"formula: {len(formula.level_interpolation)} interpolation rows ({formula.source.get('tables', '?')})")
    if args.dry_run:
        print("dry run: nothing written")
        return 0
    for source, target, raw, _ in loaded:
        _atomic_write(target, raw)
        print(f"wrote {target} <- {source}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

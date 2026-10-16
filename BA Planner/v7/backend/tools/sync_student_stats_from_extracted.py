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


def load_store_pairs(reader, kind):
    # Verify both documents before the caller can write either target.
    loaded = []
    for source_name, target_name, dto in PAIRS:
        raw = reader.read_extract('jp', kind, source_name)
        parsed = dto.from_dict(json.loads(raw))
        loaded.append((source_name, target_name, raw, parsed))
    return loaded


def main() -> int:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group()
    source.add_argument('--extracted', type=Path)
    source.add_argument('--from-store', metavar='KIND')
    parser.add_argument('--lock', type=Path, default=ROOT.parent / 'ba-data.lock')
    parser.add_argument('--store-root', type=Path)
    parser.add_argument('--output-dir', type=Path, default=TARGET_DIR)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    loaded = []
    provenance = None
    if args.from_store:
        from core.client_data_store import ClientDataStore
        import hashlib
        from datetime import datetime, timezone
        reader = ClientDataStore(args.lock, args.store_root)
        if args.output_dir.resolve().is_relative_to(reader.root):
            raise ValueError('sync output must be outside the read-only store')
        pairs = load_store_pairs(reader, args.from_store)
        stamp = datetime.now(timezone.utc).isoformat()
        provenance = {}
        for source_name, target_name, raw, parsed in pairs:
            loaded.append((source_name, args.output_dir / target_name, raw, parsed))
            value = json.loads(raw)
            row_sha = hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                separators=(',', ':'), allow_nan=False).encode()).hexdigest()
            provenance[target_name] = {'value': value, 'provenance': {'kind': args.from_store,
                'versionId': reader.lock['pins']['jp']['version_id'], 'table': source_name,
                'rowSha': row_sha, 'tool': 'sync-student-stats-store-v1', 'extractedAt': stamp}}
    else:
        extracted = args.extracted or ROOT.parent / 'data' / 'extracted'
        for source_name, target_name, dto in PAIRS:
            source = extracted / source_name
            raw = source.read_bytes()
            parsed = dto.from_dict(json.loads(raw))
            loaded.append((source, args.output_dir / target_name, raw, parsed))
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
    if provenance is not None:
        _atomic_write(args.output_dir / 'store-provenance.json',
            (json.dumps(provenance, ensure_ascii=False, indent=2) + '\n').encode())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

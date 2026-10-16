"""One-way bootstrap/export of the BA Planner canonical metadata catalog."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from core import student_meta_data
from core.canonical_metadata import CanonicalMetadataCatalog, write_catalog
from core.runtime_paths import PACKAGED_METADATA_CATALOG_PATH


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=PACKAGED_METADATA_CATALOG_PATH)
    parser.add_argument('--from-store', action='store_true')
    parser.add_argument('--lock', type=Path, default=BACKEND_DIR.parent / 'ba-data.lock')
    parser.add_argument('--store-root', type=Path)
    parser.add_argument('--catalog', type=Path, default=PACKAGED_METADATA_CATALOG_PATH)
    parser.add_argument('--crosswalk', type=Path)
    parser.add_argument('--preview', type=Path)
    args = parser.parse_args()
    if args.from_store:
        if args.preview is None:
            parser.error('--from-store requires --preview; catalog apply is not implemented')
        import json
        from core.client_data_store import ClientDataStore
        from core.canonical_metadata import load_catalog
        from tools.metadata_store_preview import preview
        mapping = json.loads(args.crosswalk.read_text(encoding='utf-8')) if args.crosswalk else None
        result = preview(load_catalog(args.catalog), ClientDataStore(args.lock, args.store_root), mapping)
        destination = args.preview.resolve()
        if destination in {args.catalog.resolve(), args.lock.resolve()} or destination.is_relative_to(ClientDataStore(args.lock, args.store_root).root):
            parser.error('preview output must not overwrite the catalog, lock, or store')
        destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print('store preview only; Schale removal comparison: blocked')
        return 0
    if args.preview or args.crosswalk:
        parser.error('--preview/--crosswalk require --from-store')
    catalog = CanonicalMetadataCatalog.from_legacy(
        students=student_meta_data.STUDENTS,
        forms=student_meta_data.MULTI_FORM_STUDENTS,
        jp_only_student_ids=student_meta_data.JP_ONLY_STUDENT_IDS,
        favorite_item_student_ids=student_meta_data.FAVORITE_ITEM_STUDENT_IDS,
        favorite_item_max_tier=student_meta_data.FAVORITE_ITEM_MAX_TIER,
    )
    write_catalog(catalog, args.output.resolve())
    print(f"wrote {args.output}: {len(catalog.students)} students")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

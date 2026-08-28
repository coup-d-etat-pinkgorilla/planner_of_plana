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
    args = parser.parse_args()
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

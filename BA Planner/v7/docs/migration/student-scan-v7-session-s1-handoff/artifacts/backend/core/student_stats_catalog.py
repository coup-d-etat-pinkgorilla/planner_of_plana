"""Load the generated v1 student-stat catalog and resolve v7 student/form refs."""

from __future__ import annotations

from functools import lru_cache
import json
from pathlib import Path

from core import student_meta
from core.schale_merge_paths import SCHALE_MERGE_PATHS
from core.student_stats_types import StudentStatCatalogV1, StudentStatRecordV1


DEFAULT_STUDENT_STAT_CATALOG_PATH = (
    Path(__file__).resolve().parents[1] / "data" / "student_stats" / "v1" / "catalog.json"
)


@lru_cache(maxsize=4)
def load_student_stat_catalog(
    path: str | Path = DEFAULT_STUDENT_STAT_CATALOG_PATH,
) -> StudentStatCatalogV1:
    resolved = Path(path).resolve()
    with resolved.open("r", encoding="utf-8") as handle:
        return StudentStatCatalogV1.from_dict(json.load(handle))


def student_stat_record(
    student_id: str,
    form_index: int = 1,
    *,
    catalog: StudentStatCatalogV1 | None = None,
) -> StudentStatRecordV1:
    selected = catalog or load_student_stat_catalog()
    normalized_form = student_meta.normalize_form_index(student_id, form_index)
    merge_paths = SCHALE_MERGE_PATHS.get(student_id, ())
    if merge_paths:
        path_index = min(normalized_form - 1, len(merge_paths) - 1)
        schaledb_id = selected.paths.get(merge_paths[path_index].casefold())
    else:
        schaledb_id = student_meta.schaledb_id(student_id)
    if schaledb_id is None or schaledb_id not in selected.students:
        raise KeyError(f"student stat data not found: {student_id}#{normalized_form}")
    return selected.students[schaledb_id]

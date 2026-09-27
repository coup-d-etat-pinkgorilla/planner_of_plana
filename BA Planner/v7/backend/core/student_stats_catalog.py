"""Load the generated v1 student-stat catalog and formula tables, and resolve v7 student/form refs."""

from __future__ import annotations

from functools import lru_cache
import json
from pathlib import Path

from core import student_meta
from core.schale_merge_paths import SCHALE_MERGE_PATHS
from core.student_stats_types import StudentStatCatalogV1, StudentStatFormulaV1, StudentStatRecordV1


DEFAULT_STUDENT_STAT_CATALOG_PATH = (
    Path(__file__).resolve().parents[1] / "data" / "student_stats" / "v1" / "catalog.json"
)
DEFAULT_STUDENT_STAT_FORMULA_PATH = DEFAULT_STUDENT_STAT_CATALOG_PATH.with_name("formula.json")


@lru_cache(maxsize=4)
def load_student_stat_formula(
    path: str | Path = DEFAULT_STUDENT_STAT_FORMULA_PATH,
) -> StudentStatFormulaV1:
    resolved = Path(path).resolve()
    with resolved.open("r", encoding="utf-8") as handle:
        return StudentStatFormulaV1.from_dict(json.load(handle))


@lru_cache(maxsize=4)
def load_student_stat_catalog(
    path: str | Path = DEFAULT_STUDENT_STAT_CATALOG_PATH,
) -> StudentStatCatalogV1:
    resolved = Path(path).resolve()
    with resolved.open("r", encoding="utf-8") as handle:
        return StudentStatCatalogV1.from_dict(json.load(handle))


def student_stat_record(
    student_id: str,
    form_index: int | None = None,
    *,
    catalog: StudentStatCatalogV1 | None = None,
) -> StudentStatRecordV1:
    selected = catalog or load_student_stat_catalog()
    base_student_id, parsed_form = student_meta.split_form_ref(student_id)
    requested_form = parsed_form if form_index is None else form_index
    normalized_form = student_meta.normalize_form_index(base_student_id, requested_form)
    merge_paths = SCHALE_MERGE_PATHS.get(base_student_id, ())
    if merge_paths:
        path_index = min(normalized_form - 1, len(merge_paths) - 1)
        schaledb_id = selected.paths.get(merge_paths[path_index].casefold())
    else:
        schaledb_id = student_meta.schaledb_id(base_student_id)
        if schaledb_id is None:
            schaledb_id = selected.paths.get(base_student_id.casefold())
    if schaledb_id is None or schaledb_id not in selected.students:
        raise KeyError(f"student stat data not found: {base_student_id}#{normalized_form}")
    return selected.students[schaledb_id]

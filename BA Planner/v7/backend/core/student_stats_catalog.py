"""Load the generated v1 student-stat catalog and formula tables, and resolve v7 student/form refs."""

from __future__ import annotations

from functools import lru_cache
import json
from pathlib import Path

from core import student_meta
from core.client_character_refs import character_id
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
    schaledb_id = character_id(base_student_id, normalized_form)
    if schaledb_id is None or schaledb_id not in selected.students:
        raise KeyError(f"student stat data not found: {base_student_id}#{normalized_form}")
    return selected.students[schaledb_id]

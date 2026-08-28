"""BA Planner-owned canonical student metadata catalog.

Provider-specific references and imported affinity values are stored outside
the core student records.  ``legacy_*`` accessors exist only to preserve the
pre-canonical runtime API while callers migrate incrementally.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
import json
import os
from pathlib import Path
import re
import tempfile
from typing import Any, Mapping

from core.runtime_paths import resolve_metadata_catalog_path


SCHEMA_VERSION = 1
_STUDENT_ID_RE = re.compile(r"^[a-z0-9_]+$")
_PROVIDER_FIELDS = frozenset({"schaledb_id", "favor_item_tags", "favor_item_unique_tags"})


class CanonicalMetadataError(ValueError):
    """Raised when the canonical catalog violates its versioned contract."""


def _mapping(value: object, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise CanonicalMetadataError(f"{label} must be an object")
    return {str(key): item for key, item in value.items()}


def _string_list(value: object, label: str) -> list[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
        raise CanonicalMetadataError(f"{label} must be a string array")
    return list(value)


@dataclass(frozen=True)
class CanonicalMetadataCatalog:
    students: dict[str, dict[str, Any]]
    forms: dict[str, tuple[dict[str, Any], ...]]
    jp_only_student_ids: frozenset[str]
    favorite_item_student_ids: frozenset[str]
    favorite_item_max_tier: str
    provider_student_ids: dict[str, dict[str, int]]
    gift_affinities: dict[str, dict[str, list[str]]]

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "CanonicalMetadataCatalog":
        if payload.get("version") != SCHEMA_VERSION:
            raise CanonicalMetadataError(
                f"unsupported canonical metadata version: {payload.get('version')!r}"
            )
        required_sections = {
            "students",
            "forms",
            "server_availability",
            "favorite_items",
            "provider_refs",
            "gift_affinities",
        }
        missing_sections = required_sections - payload.keys()
        if missing_sections:
            raise CanonicalMetadataError(
                f"canonical metadata sections missing: {sorted(missing_sections)}"
            )
        raw_students = _mapping(payload.get("students"), "students")
        students: dict[str, dict[str, Any]] = {}
        for student_id, raw in raw_students.items():
            if not _STUDENT_ID_RE.fullmatch(student_id):
                raise CanonicalMetadataError(f"invalid student id: {student_id}")
            record = _mapping(raw, f"students.{student_id}")
            leaked = _PROVIDER_FIELDS & set(record)
            if leaked:
                raise CanonicalMetadataError(
                    f"students.{student_id} contains provider-owned fields: {sorted(leaked)}"
                )
            for required in ("display_name", "template_name", "group"):
                if not isinstance(record.get(required), str) or not record[required]:
                    raise CanonicalMetadataError(f"students.{student_id}.{required} is required")
            students[student_id] = record

        raw_forms = _mapping(payload.get("forms", {}), "forms")
        forms: dict[str, tuple[dict[str, Any], ...]] = {}
        for student_id, raw in raw_forms.items():
            if student_id not in students:
                raise CanonicalMetadataError(f"forms references unknown student: {student_id}")
            if not isinstance(raw, list) or any(not isinstance(item, dict) for item in raw):
                raise CanonicalMetadataError(f"forms.{student_id} must be an object array")
            forms[student_id] = tuple(dict(item) for item in raw)

        availability = _mapping(payload.get("server_availability", {}), "server_availability")
        favorites = _mapping(payload.get("favorite_items", {}), "favorite_items")
        jp_only = frozenset(_string_list(availability.get("jp_only_student_ids", []), "server_availability.jp_only_student_ids"))
        favorite_ids = frozenset(_string_list(favorites.get("student_ids", []), "favorite_items.student_ids"))
        for label, values in (("jp_only", jp_only), ("favorite item", favorite_ids)):
            unknown = values - students.keys()
            if unknown:
                raise CanonicalMetadataError(f"{label} references unknown students: {sorted(unknown)}")
        max_tier = favorites.get("max_tier", "T2")
        if not isinstance(max_tier, str) or not max_tier:
            raise CanonicalMetadataError("favorite_items.max_tier must be a non-empty string")

        provider_refs = _mapping(payload.get("provider_refs", {}), "provider_refs")
        provider_student_ids: dict[str, dict[str, int]] = {}
        for provider, raw in provider_refs.items():
            provider_payload = _mapping(raw, f"provider_refs.{provider}")
            raw_ids = _mapping(provider_payload.get("student_ids", {}), f"provider_refs.{provider}.student_ids")
            ids: dict[str, int] = {}
            for student_id, external_id in raw_ids.items():
                if student_id not in students:
                    raise CanonicalMetadataError(
                        f"provider_refs.{provider} references unknown student: {student_id}"
                    )
                if not isinstance(external_id, int) or isinstance(external_id, bool):
                    raise CanonicalMetadataError(
                        f"provider_refs.{provider}.student_ids.{student_id} must be an integer"
                    )
                ids[student_id] = external_id
            provider_student_ids[provider] = ids

        raw_affinities = _mapping(payload.get("gift_affinities", {}), "gift_affinities")
        affinities: dict[str, dict[str, list[str]]] = {}
        for student_id, raw in raw_affinities.items():
            if student_id not in students:
                raise CanonicalMetadataError(f"gift_affinities references unknown student: {student_id}")
            affinity = _mapping(raw, f"gift_affinities.{student_id}")
            affinities[student_id] = {
                "preferred_tags": _string_list(affinity.get("preferred_tags", []), f"gift_affinities.{student_id}.preferred_tags"),
                "unique_tags": _string_list(affinity.get("unique_tags", []), f"gift_affinities.{student_id}.unique_tags"),
            }
        return cls(
            students=students,
            forms=forms,
            jp_only_student_ids=jp_only,
            favorite_item_student_ids=favorite_ids,
            favorite_item_max_tier=max_tier,
            provider_student_ids=provider_student_ids,
            gift_affinities=affinities,
        )

    @classmethod
    def from_legacy(
        cls,
        *,
        students: Mapping[str, Mapping[str, Any]],
        forms: Mapping[str, tuple[Mapping[str, Any], ...]],
        jp_only_student_ids: set[str] | frozenset[str],
        favorite_item_student_ids: set[str] | frozenset[str],
        favorite_item_max_tier: str,
    ) -> "CanonicalMetadataCatalog":
        core_students: dict[str, dict[str, Any]] = {}
        schaledb_ids: dict[str, int] = {}
        affinities: dict[str, dict[str, list[str]]] = {}
        for student_id, raw in students.items():
            record = dict(raw)
            external_id = record.pop("schaledb_id", None)
            preferred = record.pop("favor_item_tags", None)
            unique = record.pop("favor_item_unique_tags", None)
            core_students[student_id] = record
            if isinstance(external_id, int) and not isinstance(external_id, bool):
                schaledb_ids[student_id] = external_id
            if preferred is not None or unique is not None:
                affinities[student_id] = {
                    "preferred_tags": [str(item) for item in preferred or []],
                    "unique_tags": [str(item) for item in unique or []],
                }
        return cls.from_payload({
            "version": SCHEMA_VERSION,
            "students": core_students,
            "forms": {key: [dict(item) for item in value] for key, value in forms.items()},
            "server_availability": {"jp_only_student_ids": sorted(jp_only_student_ids)},
            "favorite_items": {
                "student_ids": sorted(favorite_item_student_ids),
                "max_tier": favorite_item_max_tier,
            },
            "provider_refs": {"schaledb": {"student_ids": schaledb_ids}},
            "gift_affinities": affinities,
        })

    def legacy_students(self) -> dict[str, dict[str, Any]]:
        result = {student_id: dict(record) for student_id, record in self.students.items()}
        for student_id, external_id in self.provider_student_ids.get("schaledb", {}).items():
            result[student_id]["schaledb_id"] = external_id
        for student_id, affinity in self.gift_affinities.items():
            result[student_id]["favor_item_tags"] = list(affinity["preferred_tags"])
            result[student_id]["favor_item_unique_tags"] = list(affinity["unique_tags"])
        return result

    def with_legacy_students(
        self,
        students: Mapping[str, Mapping[str, Any]],
        jp_only_student_ids: set[str] | frozenset[str] | None = None,
    ) -> "CanonicalMetadataCatalog":
        return self.from_legacy(
            students=students,
            forms={key: value for key, value in self.forms.items() if key in students},
            jp_only_student_ids=self.jp_only_student_ids if jp_only_student_ids is None else jp_only_student_ids,
            favorite_item_student_ids=self.favorite_item_student_ids & students.keys(),
            favorite_item_max_tier=self.favorite_item_max_tier,
        )

    def with_forms(self, forms: Mapping[str, tuple[Mapping[str, Any], ...]]) -> "CanonicalMetadataCatalog":
        return replace(self, forms={key: tuple(dict(item) for item in value) for key, value in forms.items()})

    def to_payload(self) -> dict[str, Any]:
        return {
            "version": SCHEMA_VERSION,
            "students": self.students,
            "forms": {key: list(value) for key, value in self.forms.items()},
            "server_availability": {"jp_only_student_ids": sorted(self.jp_only_student_ids)},
            "favorite_items": {
                "student_ids": sorted(self.favorite_item_student_ids),
                "max_tier": self.favorite_item_max_tier,
            },
            "provider_refs": {
                provider: {"student_ids": ids}
                for provider, ids in sorted(self.provider_student_ids.items())
            },
            "gift_affinities": self.gift_affinities,
        }


def load_catalog(path: Path | None = None) -> CanonicalMetadataCatalog:
    catalog_path = path or resolve_metadata_catalog_path()
    try:
        payload = json.loads(catalog_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CanonicalMetadataError(f"could not load canonical metadata: {catalog_path}") from exc
    return CanonicalMetadataCatalog.from_payload(_mapping(payload, "catalog"))


def write_catalog(catalog: CanonicalMetadataCatalog, path: Path | None = None) -> None:
    catalog_path = path or resolve_metadata_catalog_path()
    content = json.dumps(
        catalog.to_payload(), ensure_ascii=False, indent=2, sort_keys=True
    ) + "\n"
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{catalog_path.name}.", suffix=".tmp", dir=catalog_path.parent
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, catalog_path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)

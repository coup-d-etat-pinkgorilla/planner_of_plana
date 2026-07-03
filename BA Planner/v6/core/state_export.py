from __future__ import annotations

import base64
import gzip
import json
from collections.abc import Iterable, Mapping
from datetime import datetime, timezone
from typing import Any


EXPORT_FORMAT = "ba_planner_state"
EXPORT_VERSION = 1
EXPORT_PREFIX = "BAPSTATE1:"


def build_state_export_payload(
    *,
    students: Iterable[Mapping[str, Any]],
    inventory: Mapping[str, Mapping[str, Any]],
    resources: Mapping[str, Any] | None = None,
    profile_name: str | None = None,
    app_version: str | None = None,
    generated_at: str | None = None,
) -> dict[str, Any]:
    student_rows = sorted(
        (_clean_mapping(row) for row in students if row.get("student_id")),
        key=lambda row: str(row.get("student_id") or ""),
    )
    inventory_rows = {
        str(key): _clean_mapping(value)
        for key, value in sorted((inventory or {}).items(), key=lambda item: str(item[0]))
        if isinstance(value, Mapping)
    }
    resource_rows = {
        str(key): _clean_value(value)
        for key, value in sorted((resources or {}).items(), key=lambda item: str(item[0]))
    }
    return {
        "format": EXPORT_FORMAT,
        "version": EXPORT_VERSION,
        "meta": {
            "generated_at": generated_at or datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "profile_name": profile_name,
            "app_version": app_version,
        },
        "summary": {
            "student_count": len(student_rows),
            "inventory_count": len(inventory_rows),
            "resource_count": len(resource_rows),
        },
        "students": student_rows,
        "inventory": inventory_rows,
        "resources": resource_rows,
    }


def encode_state_export_payload(payload: Mapping[str, Any]) -> str:
    raw = json.dumps(
        _clean_value(payload),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    compressed = gzip.compress(raw, compresslevel=9, mtime=0)
    token = base64.urlsafe_b64encode(compressed).decode("ascii").rstrip("=")
    return f"{EXPORT_PREFIX}{token}"


def encode_state_export(
    *,
    students: Iterable[Mapping[str, Any]],
    inventory: Mapping[str, Mapping[str, Any]],
    resources: Mapping[str, Any] | None = None,
    profile_name: str | None = None,
    app_version: str | None = None,
    generated_at: str | None = None,
) -> str:
    return encode_state_export_payload(
        build_state_export_payload(
            students=students,
            inventory=inventory,
            resources=resources,
            profile_name=profile_name,
            app_version=app_version,
            generated_at=generated_at,
        )
    )


def decode_state_export(token: str) -> dict[str, Any]:
    text = str(token or "").strip()
    if text.startswith(EXPORT_PREFIX):
        text = text[len(EXPORT_PREFIX):]
    padding = "=" * (-len(text) % 4)
    compressed = base64.urlsafe_b64decode((text + padding).encode("ascii"))
    raw = gzip.decompress(compressed)
    payload = json.loads(raw.decode("utf-8"))
    if payload.get("format") != EXPORT_FORMAT:
        raise ValueError("Unsupported BA Planner state export format")
    if payload.get("version") != EXPORT_VERSION:
        raise ValueError("Unsupported BA Planner state export version")
    return payload


def _clean_mapping(row: Mapping[str, Any]) -> dict[str, Any]:
    return {str(key): _clean_value(value) for key, value in row.items()}


def _clean_value(value: Any) -> Any:
    if isinstance(value, Mapping):
        return _clean_mapping(value)
    if isinstance(value, (list, tuple)):
        return [_clean_value(item) for item in value]
    if hasattr(value, "value"):
        return value.value
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return str(value)

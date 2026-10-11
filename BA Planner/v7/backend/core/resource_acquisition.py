"""Read-only reviewed KR acquisition metadata; no inventory/store/scanner mutation."""
from __future__ import annotations

from copy import deepcopy
from datetime import date
import hashlib
import json
from pathlib import Path
import re
from typing import Callable, Iterable


METHOD_FIELDS = frozenset({"method_id", "kind", "label", "weekly_quantity", "selector_resource_keys", "source"})
KINDS = frozenset({"stage", "shop", "conversion", "selector", "other"})


class AcquisitionDataError(ValueError):
    pass


class AcquisitionQueryError(ValueError):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def _object(value: object, fields: set | frozenset, label: str) -> dict:
    if not isinstance(value, dict) or set(value) != fields:
        raise AcquisitionDataError(f"{label} must contain exactly {sorted(fields)}")
    return value


def _text(value: object, label: str, *, maximum: int = 1024) -> str:
    if not isinstance(value, str):
        raise AcquisitionDataError(f"{label} must be a string")
    try:
        size = len(value.encode("utf-8"))
    except UnicodeEncodeError as error:
        raise AcquisitionDataError(f"{label} must be valid Unicode") from error
    if not 1 <= size <= maximum:
        raise AcquisitionDataError(f"{label} must be 1..{maximum} UTF-8 bytes")
    return value


def validate_acquisition_query(payload: object) -> str:
    try:
        data = _object(payload, {"resource_key"}, "acquisition query")
        return _text(data["resource_key"], "resource_key")
    except AcquisitionDataError as error:
        raise AcquisitionQueryError("invalid_payload", str(error)) from error


def resolve_acquisition_resource_key(resource_key: str, catalog_keys: Iterable[str],
                                     canonicalize: Callable[[str], str]) -> str:
    key = canonicalize(resource_key)
    if key not in set(catalog_keys):
        raise AcquisitionQueryError("resource_not_found", "Resource is not present in the inventory catalog")
    return key


def _unique_json_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise AcquisitionDataError("Acquisition JSON has duplicate object keys")
        result[key] = value
    return result


def validate_resource_acquisition(value: object, catalog_keys: Iterable[str]) -> dict:
    data = _object(value, {"version", "resources"}, "acquisition table")
    if type(data["version"]) is not int or data["version"] != 1:
        raise AcquisitionDataError("Unsupported acquisition table version")
    if not isinstance(data["resources"], dict):
        raise AcquisitionDataError("resources must be an object")
    known = frozenset(catalog_keys)
    for resource_key, raw in data["resources"].items():
        _text(resource_key, "resource_key")
        if resource_key not in known:
            raise AcquisitionDataError("Acquisition table resource key must be canonical and present in the catalog")
        row = _object(raw, {"methods"}, "acquisition resource")
        if not isinstance(row["methods"], list):
            raise AcquisitionDataError("methods must be an array")
        method_ids = set()
        for raw_method in row["methods"]:
            method = _object(raw_method, METHOD_FIELDS, "acquisition method")
            identity = _text(method["method_id"], "method_id", maximum=128)
            if not re.fullmatch(r"[a-z0-9][a-z0-9._-]*", identity) or identity in method_ids:
                raise AcquisitionDataError("method_id must be stable and unique within its resource")
            method_ids.add(identity)
            if not isinstance(method["kind"], str) or method["kind"] not in KINDS:
                raise AcquisitionDataError("Unknown acquisition method kind")
            _text(method["label"], "label")
            quantity = method["weekly_quantity"]
            if quantity is not None and (not isinstance(quantity, str) or len(quantity) > 1024 or not re.fullmatch(r"0|[1-9][0-9]*", quantity)):
                raise AcquisitionDataError("weekly_quantity must be null or a canonical base-10 integer string")
            selectors = method["selector_resource_keys"]
            if selectors is not None:
                if not isinstance(selectors, list):
                    raise AcquisitionDataError("selector_resource_keys must be null or an array")
                seen = set()
                for selector in selectors:
                    key = _text(selector, "selector resource key")
                    if key not in known or key in seen:
                        raise AcquisitionDataError("Selector keys must be unique canonical catalog identities")
                    seen.add(key)
            source = _object(method["source"], {"server", "reference", "reviewed_at"}, "acquisition source")
            if source["server"] != "KR":
                raise AcquisitionDataError("Acquisition source must explicitly target KR")
            _text(source["reference"], "source.reference")
            reviewed = source["reviewed_at"]
            if not isinstance(reviewed, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", reviewed):
                raise AcquisitionDataError("reviewed_at must be a calendar date YYYY-MM-DD")
            try:
                date.fromisoformat(reviewed)
            except ValueError as error:
                raise AcquisitionDataError("reviewed_at must be a real calendar date") from error
    # A returned response cannot mutate the caller's original metadata table.
    return deepcopy(data)


def load_resource_acquisition_bytes(raw: bytes, catalog_keys: Iterable[str]) -> dict:
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_json_object)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise AcquisitionDataError("Acquisition table is not valid UTF-8 JSON") from error
    return validate_resource_acquisition(value, catalog_keys)


def load_packaged_resource_acquisition(catalog_keys: Iterable[str]) -> dict:
    """Read only the packaged v1 hand-reviewed table. Missing/corrupt is not an empty table."""
    path = Path(__file__).resolve().parent.parent / "data" / "metadata" / "v1" / "resource_acquisition.json"
    try:
        raw = path.read_bytes()
    except OSError as error:
        raise AcquisitionDataError("Packaged acquisition table is unavailable") from error
    return load_resource_acquisition_bytes(raw, catalog_keys)


def resource_acquisition_payload(resource_key: str, table: dict) -> dict:
    canonical = json.dumps(table, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    revision = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return {"resource_key": resource_key,
            "methods": deepcopy(table["resources"].get(resource_key, {"methods": []})["methods"]),
            "acquisition_revision": revision}

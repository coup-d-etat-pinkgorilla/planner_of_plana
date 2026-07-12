"""Helpers for account-local, resolution-specific inventory answer samples."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Iterable


_RESOLUTION_RE = re.compile(r"^(\d{2,5})x(\d{2,5})$")


def inventory_resolution_key(value: object) -> str | None:
    """Return a safe ``WIDTHxHEIGHT`` key, or ``None`` for unknown sizes."""
    if isinstance(value, str):
        text = value.strip().lower().replace(" ", "")
        match = _RESOLUTION_RE.fullmatch(text)
        if not match:
            return None
        width, height = int(match.group(1)), int(match.group(2))
    else:
        try:
            width, height = value  # type: ignore[misc]
            width, height = int(width), int(height)
        except (TypeError, ValueError):
            return None
    if width <= 0 or height <= 0:
        return None
    return f"{width}x{height}"


def resolution_sample_dir(root: Path, resolution: object, profile_id: str, item_id: str | None = None) -> Path | None:
    key = inventory_resolution_key(resolution)
    if key is None or not profile_id:
        return None
    path = Path(root) / key / profile_id
    return path / item_id if item_id else path


def resolution_sample_catalog(root: Path, resolution: object, profile_id: str) -> dict[str, list[str]]:
    """Load all PNG samples grouped by canonical item id."""
    base = resolution_sample_dir(root, resolution, profile_id)
    if base is None or not base.exists():
        return {}
    result: dict[str, list[str]] = {}
    for item_dir in sorted(path for path in base.iterdir() if path.is_dir()):
        paths = [str(path) for path in sorted(item_dir.glob("*.png"))]
        if paths:
            result[item_dir.name] = paths
    return result


def merge_answer_samples(
    base_catalog: Iterable[tuple[str, str]],
    samples_by_id: dict[str, list[str]],
    *,
    excluded_prefixes: tuple[str, ...] = (),
) -> list[tuple[str, str]]:
    """Put answer samples first while retaining bundled assets as a safe fallback."""
    catalog: list[tuple[str, str]] = []
    base_ids: set[str] = set()
    for item_id, path in base_catalog:
        base_ids.add(item_id)
        if not item_id.startswith(excluded_prefixes):
            catalog.extend((item_id, sample) for sample in samples_by_id.get(item_id, ()))
        catalog.append((item_id, path))
    for item_id, paths in samples_by_id.items():
        if item_id in base_ids or item_id.startswith(excluded_prefixes):
            continue
        catalog.extend((item_id, sample) for sample in paths)
    return catalog

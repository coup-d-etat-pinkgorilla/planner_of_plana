"""
Check for whole-app updates published as GitHub Release zip files.
"""

from __future__ import annotations

import json
import re
import urllib.request
from pathlib import Path

from core.config import APP_DIR, BASE_DIR

APP_MANIFEST_NAME = "app_manifest.json"


def _manifest_candidates() -> tuple[Path, ...]:
    return (
        APP_DIR / APP_MANIFEST_NAME,
        BASE_DIR / APP_MANIFEST_NAME,
    )


def load_app_manifest() -> dict:
    for path in _manifest_candidates():
        if not path.exists():
            continue
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def _download_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def load_latest_app_manifest(base_manifest: dict | None = None) -> dict:
    manifest = dict(base_manifest or load_app_manifest())
    manifest_url = str(manifest.get("manifest_url") or "").strip()
    if not manifest_url:
        return manifest
    try:
        latest = _download_json(manifest_url)
    except Exception:
        return manifest
    return latest if isinstance(latest, dict) else manifest


def _version_key(version: str) -> tuple[tuple[int, object], ...]:
    parts: list[tuple[int, object]] = []
    for token in re.findall(r"\d+|[A-Za-z]+", version.casefold()):
        if token.isdigit():
            parts.append((0, int(token)))
        else:
            parts.append((1, token))
    return tuple(parts)


def _is_newer(latest_version: str, current_version: str) -> bool:
    if not latest_version or not current_version:
        return False
    if latest_version == current_version:
        return False
    return _version_key(latest_version) > _version_key(current_version)


def check_for_app_update() -> dict | None:
    current = load_app_manifest()
    latest = load_latest_app_manifest(current)
    current_version = str(current.get("app_version") or "")
    latest_version = str(latest.get("app_version") or "")
    if not _is_newer(latest_version, current_version):
        return None
    return latest

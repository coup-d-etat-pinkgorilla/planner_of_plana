"""Read-only runtime paths for the first v7 backend slice."""

from __future__ import annotations

import os
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parent.parent
V7_DIR = BACKEND_DIR.parent
PACKAGED_PLANNING_DATA_DIR = BACKEND_DIR / "data" / "planning"


def _external_asset_dir() -> Path:
    override = os.environ.get("BA_PLANNER_ASSET_DIR")
    if override:
        return Path(override).expanduser()

    user_override = os.environ.get("BA_PLANNER_USER_DIR")
    if user_override:
        return Path(user_override).expanduser() / "assets" / "current"

    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        return Path(local_app_data) / "BA Planner" / "assets" / "current"
    return V7_DIR / "assets" / "current"


DEFAULT_ASSET_DIR = _external_asset_dir()


def resolve_planning_data_dir() -> Path:
    external = DEFAULT_ASSET_DIR / "data" / "planning"
    if external.is_dir():
        return external
    return PACKAGED_PLANNING_DATA_DIR


PLANNING_DATA_DIR = resolve_planning_data_dir()


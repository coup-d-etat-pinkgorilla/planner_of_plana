"""Optional, untruncated golden diagnostics; this does not alter comparisons."""
from __future__ import annotations

import difflib
import hashlib
import json
import os
from pathlib import Path
import re


DUMP_ENV = "BA_PLANNER_GOLDEN_DUMP_DIR"


def dump_comparison(scenario_id: str, expected: str, actual: str,
                    directory: str | Path | None = None) -> Path | None:
    """Save the exact compared strings and full diff when explicitly enabled.

    Each scenario is immutable within a dump directory. Identical reruns are
    allowed; changed payloads require a fresh directory rather than overwriting
    earlier evidence. This module uses only the Python standard library.
    """
    directory = directory if directory is not None else os.environ.get(DUMP_ENV)
    if not directory:
        return None
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", scenario_id):
        raise ValueError(f"Invalid golden scenario id: {scenario_id!r}")
    root = Path(directory)
    expected_bytes, actual_bytes = expected.encode("utf-8"), actual.encode("utf-8")
    diff = "".join(difflib.unified_diff(expected.splitlines(True), actual.splitlines(True),
                                     "golden", "replay", n=3))
    metadata = {
        "scenario": scenario_id,
        "expected_bytes": len(expected_bytes),
        "expected_sha256": hashlib.sha256(expected_bytes).hexdigest(),
        "actual_bytes": len(actual_bytes),
        "actual_sha256": hashlib.sha256(actual_bytes).hexdigest(),
        "strict_equal": expected == actual,
    }
    files = {
        root / "expected" / f"{scenario_id}.json": expected_bytes,
        root / "actual" / f"{scenario_id}.json": actual_bytes,
        root / "full-diff" / f"{scenario_id}.diff": (diff or "No differences\n").encode("utf-8"),
        root / "comparisons" / f"{scenario_id}.json":
            (json.dumps(metadata, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
    }
    # Check all existing files before writing any new ones.
    for path, data in files.items():
        if path.exists() and path.read_bytes() != data:
            raise FileExistsError(f"Golden dump differs at {path}; use a fresh dump directory")
    for path, data in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        try:
            with path.open("xb") as handle:
                handle.write(data)
        except FileExistsError:
            if path.read_bytes() != data:
                raise
    return root

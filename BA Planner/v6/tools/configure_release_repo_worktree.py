from __future__ import annotations

import argparse
import fnmatch
import subprocess
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent

LOCAL_ONLY_TRACKED_PATTERNS = (
    "config.json",
    "__pycache__/*",
    "*/__pycache__/*",
    "profiles/*",
    "artifacts/*",
    "*.db",
    "*.db-*",
    "*.pyc",
    "*.pyo",
)


def _run_git(args: list[str]) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=ROOT_DIR,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def _tracked_files() -> list[str]:
    raw = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=ROOT_DIR,
        check=True,
        capture_output=True,
    ).stdout
    return [part.decode("utf-8") for part in raw.split(b"\0") if part]


def _is_local_only(path: str) -> bool:
    normalized = path.replace("\\", "/")
    return any(fnmatch.fnmatchcase(normalized, pattern) for pattern in LOCAL_ONLY_TRACKED_PATTERNS)


def _local_only_tracked_files() -> list[str]:
    return sorted(path for path in _tracked_files() if _is_local_only(path))


def _batch_update(flag: str, paths: list[str]) -> None:
    batch_size = 100
    for index in range(0, len(paths), batch_size):
        batch = paths[index : index + batch_size]
        subprocess.run(["git", "update-index", flag, "--", *batch], cwd=ROOT_DIR, check=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Mark tracked local workspace files as skip-worktree for this release-focused checkout."
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--list", action="store_true", help="List tracked local-only files.")
    group.add_argument("--apply", action="store_true", help="Mark tracked local-only files as skip-worktree.")
    group.add_argument("--clear", action="store_true", help="Clear skip-worktree for tracked local-only files.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    paths = _local_only_tracked_files()
    if args.list:
        for path in paths:
            print(path)
        print(f"{len(paths)} tracked local-only file(s)")
        return 0

    if args.apply:
        _batch_update("--skip-worktree", paths)
        print(f"Marked {len(paths)} tracked local-only file(s) as skip-worktree.")
        return 0

    if args.clear:
        _batch_update("--no-skip-worktree", paths)
        print(f"Cleared skip-worktree on {len(paths)} tracked local-only file(s).")
        return 0

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

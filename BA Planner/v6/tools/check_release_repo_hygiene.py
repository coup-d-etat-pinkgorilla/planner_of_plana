from __future__ import annotations

import argparse
import fnmatch
import subprocess
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent

LOCAL_ONLY_PATTERNS = (
    "config.json",
    "__pycache__/*",
    "*/__pycache__/*",
    "profiles/*",
    "artifacts/*",
    "debug/*",
    "logs/*",
    "scan_results/*",
    "release/*",
    "build/*",
    "dist/*",
    "*.db",
    "*.db-*",
    "*.pyc",
    "*.pyo",
    "*.log",
    ".edge-headless/*",
    ".cache_*",
    "cache/*",
    ".local/*",
    "local/*",
    "incoming_assets/*",
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


def _git_prefix() -> str:
    return _run_git(["rev-parse", "--show-prefix"]).replace("\\", "/").strip()


def _project_path(path: str, prefix: str) -> str:
    normalized = path.replace("\\", "/")
    if prefix and normalized.startswith(prefix):
        return normalized[len(prefix) :]
    return normalized


def _run_git_bytes(args: list[str]) -> bytes:
    result = subprocess.run(
        ["git", *args],
        cwd=ROOT_DIR,
        check=True,
        capture_output=True,
    )
    return result.stdout


def _parse_porcelain_z(raw: bytes, prefix: str) -> list[tuple[str, str]]:
    parts = [part.decode("utf-8") for part in raw.split(b"\0") if part]
    entries: list[tuple[str, str]] = []
    index = 0
    while index < len(parts):
        item = parts[index]
        status = item[:2]
        path = item[3:]
        if status[0] in ("R", "C") or status[1] in ("R", "C"):
            index += 1
            if index < len(parts):
                path = parts[index]
        entries.append((status, _project_path(path, prefix)))
        index += 1
    return entries


def _is_local_only(path: str) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in LOCAL_ONLY_PATTERNS)


def _status_entries(include_ignored: bool) -> list[tuple[str, str]]:
    args = ["status", "--porcelain=v1", "-z", "--untracked-files=all"]
    if include_ignored:
        args.append("--ignored")
    return _parse_porcelain_z(_run_git_bytes(args), _git_prefix())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check that the release repository is not about to include local workspace files."
    )
    parser.add_argument(
        "--include-ignored",
        action="store_true",
        help="Also show ignored local files. This is noisy but useful for audits.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    entries = _status_entries(args.include_ignored)
    local_only = [(status, path) for status, path in entries if _is_local_only(path)]
    other = [(status, path) for status, path in entries if not _is_local_only(path)]

    if local_only:
        print("Local-only files are visible to Git:")
        for status, path in local_only:
            print(f"  {status} {path}")
        print()
        print("Run tools/configure_release_repo_worktree.py --apply for already tracked local files,")
        print("or move/remove untracked workspace files before preparing a release commit.")
    else:
        print("OK: no local-only files are visible to Git.")

    if other:
        print()
        print("Other working tree changes still need intentional review:")
        for status, path in other:
            print(f"  {status} {path}")

    return 1 if local_only else 0


if __name__ == "__main__":
    raise SystemExit(main())

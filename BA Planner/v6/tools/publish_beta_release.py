from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT_DIR = Path(__file__).resolve().parent.parent
RELEASE_DIR = ROOT_DIR / "release"
APP_ARCHIVE_BASENAME = "ba-planner-windows"
ASSET_ARCHIVE_BASENAME = "ba-planner-assets"
APP_MANIFEST_NAME = "app_manifest.json"


def _gh_path() -> str:
    gh = shutil.which("gh")
    if gh:
        return gh
    winget_gh = (
        Path.home()
        / "AppData"
        / "Local"
        / "Microsoft"
        / "WinGet"
        / "Packages"
        / "GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe"
        / "bin"
        / "gh.exe"
    )
    if winget_gh.exists():
        return str(winget_gh)
    raise RuntimeError("GitHub CLI is not installed or not on PATH.")


def _run(command: list[str], *, allow_failure: bool = False) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, cwd=ROOT_DIR, capture_output=True, text=True)
    if result.returncode != 0 and not allow_failure:
        if result.stdout:
            print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        raise subprocess.CalledProcessError(result.returncode, command)
    return result


def _git_remote_url(remote: str = "origin") -> str:
    result = _run(["git", "remote", "get-url", remote], allow_failure=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def _github_repo_from_remote(remote_url: str) -> str:
    text = remote_url.strip()
    if not text:
        return ""
    if text.startswith("git@github.com:"):
        path = text.removeprefix("git@github.com:")
    else:
        parsed = urlparse(text)
        if parsed.netloc.casefold() != "github.com":
            return ""
        path = parsed.path.lstrip("/")
    if path.endswith(".git"):
        path = path[:-4]
    parts = [part for part in path.split("/") if part]
    return "/".join(parts[:2]) if len(parts) >= 2 else ""


def _default_repo() -> str:
    return _github_repo_from_remote(_git_remote_url())


def _release_exists(gh: str, repo: str, tag: str) -> bool:
    result = _run([gh, "release", "view", tag, "--repo", repo], allow_failure=True)
    return result.returncode == 0


def _required_files(version: str) -> tuple[Path, Path, Path, Path]:
    release_dir = RELEASE_DIR / version
    app_zip = release_dir / f"{APP_ARCHIVE_BASENAME}-{version}.zip"
    asset_zip = release_dir / f"{ASSET_ARCHIVE_BASENAME}-{version}.zip"
    asset_manifest = release_dir / "asset_manifest.json"
    app_manifest = release_dir / APP_MANIFEST_NAME
    missing = [path for path in (app_zip, asset_zip, asset_manifest, app_manifest) if not path.exists()]
    if missing:
        joined = "\n".join(str(path) for path in missing)
        raise FileNotFoundError(f"Missing release file(s):\n{joined}")
    return app_zip, asset_zip, asset_manifest, app_manifest


def _create_or_upload_release(
    *,
    gh: str,
    repo: str,
    tag: str,
    title: str,
    notes: str,
    files: list[Path],
    prerelease: bool,
    draft: bool,
) -> None:
    file_args = [str(path) for path in files]
    if _release_exists(gh, repo, tag):
        _run([gh, "release", "upload", tag, *file_args, "--repo", repo, "--clobber"])
        return

    command = [
        gh,
        "release",
        "create",
        tag,
        *file_args,
        "--repo",
        repo,
        "--title",
        title,
        "--notes",
        notes,
        "--latest=false",
    ]
    if prerelease:
        command.append("--prerelease")
    if draft:
        command.append("--draft")
    _run(command)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Publish BA Planner beta release artifacts to GitHub Releases.")
    parser.add_argument("--version", required=True, help="Release version, for example 0.1.0-beta.1.")
    parser.add_argument("--repo", default="", help="GitHub repo in OWNER/REPO form. Defaults to git remote origin.")
    parser.add_argument("--release-tag", default="", help="GitHub release tag. Defaults to v<version>.")
    parser.add_argument(
        "--latest-manifest-release",
        default="latest-assets",
        help="Stable release tag that hosts the latest asset_manifest.json.",
    )
    parser.add_argument(
        "--latest-app-manifest-release",
        default="latest-app",
        help="Stable release tag that hosts the latest app_manifest.json.",
    )
    parser.add_argument("--draft", action="store_true", help="Create the beta release as a draft.")
    parser.add_argument("--dry-run", action="store_true", help="Print the releases and files without calling gh.")
    parser.add_argument("--skip-latest-manifest", action="store_true", help="Do not update the latest-assets release.")
    parser.add_argument("--skip-latest-app-manifest", action="store_true", help="Do not update the latest-app release.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo = args.repo or _default_repo()
    if not repo:
        raise RuntimeError("Could not infer GitHub repo. Pass --repo OWNER/REPO.")

    tag = args.release_tag or f"v{args.version}"
    app_zip, asset_zip, asset_manifest, app_manifest = _required_files(args.version)
    notes = (
        "BA Planner beta test build.\n\n"
        "Download `ba-planner-windows-*.zip` and run `BA Planner.exe`.\n"
        "The app can download assets from this release using `asset_manifest.json`.\n"
        "Whole-app updates are announced through `app_manifest.json`."
    )
    if args.dry_run:
        print(f"repo: {repo}")
        print(f"beta release: {tag}")
        for path in (app_zip, asset_zip, asset_manifest, app_manifest):
            print(f"  upload: {path}")
        if not args.skip_latest_manifest:
            print(f"latest asset manifest release: {args.latest_manifest_release}")
            print(f"  upload: {asset_manifest}")
        if not args.skip_latest_app_manifest:
            print(f"latest app manifest release: {args.latest_app_manifest_release}")
            print(f"  upload: {app_manifest}")
        return 0

    gh = _gh_path()
    _create_or_upload_release(
        gh=gh,
        repo=repo,
        tag=tag,
        title=f"BA Planner {args.version}",
        notes=notes,
        files=[app_zip, asset_zip, asset_manifest, app_manifest],
        prerelease=True,
        draft=args.draft,
    )
    print(f"Published beta release: https://github.com/{repo}/releases/tag/{tag}")

    if not args.skip_latest_manifest:
        _create_or_upload_release(
            gh=gh,
            repo=repo,
            tag=args.latest_manifest_release,
            title="BA Planner Latest Assets",
            notes="Stable asset manifest endpoint used by BA Planner update checks.",
            files=[asset_manifest],
            prerelease=False,
            draft=False,
        )
        print(f"Updated latest manifest release: https://github.com/{repo}/releases/tag/{args.latest_manifest_release}")

    if not args.skip_latest_app_manifest:
        _create_or_upload_release(
            gh=gh,
            repo=repo,
            tag=args.latest_app_manifest_release,
            title="BA Planner Latest App",
            notes="Stable app manifest endpoint used by BA Planner whole-app update checks.",
            files=[app_manifest],
            prerelease=False,
            draft=False,
        )
        print(f"Updated latest app release: https://github.com/{repo}/releases/tag/{args.latest_app_manifest_release}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

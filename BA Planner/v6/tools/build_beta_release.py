from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from urllib.parse import urlparse

ROOT_DIR = Path(__file__).resolve().parent.parent
RELEASE_DIR = ROOT_DIR / "release"
ASSET_ARCHIVE_BASENAME = "ba-planner-assets"
PATCH_ARCHIVE_BASENAME = "ba-planner-patch"
APP_ARCHIVE_BASENAME = "ba-planner-windows"
APP_NAME = "BA Planner"
APP_MANIFEST_NAME = "app_manifest.json"

# Keep this list broad for asset families that grow over time. Files here are
# installed under the runtime asset root, so code that resolves paths from
# ASSET_DIR/TEMPLATE_DIR.parent keeps working in the packaged app.
ASSET_ROOTS = (
    "templates",
    "regions",
    "data/planning",
    "core/student_meta_data.py",
    "gui/font",
    "assets",
    "debug/region_captures",
)

REQUIRED_ASSET_GLOBS = (
    ("gui/font", "*.ttf"),
    ("templates/icons/temp", "square.png"),
    ("assets/plana", "*.png"),
    ("debug/region_captures", "filtermenu_button.region.json"),
    ("debug/region_captures", "eq_filtermenu_button.region.json"),
)

RUNTIME_ASSET_EXTENSIONS = frozenset({".png", ".jpg", ".jpeg", ".webp", ".ttf"})
RUNTIME_SOURCE_DIRS = ("core", "gui")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _git_remote_url(remote: str = "origin") -> str:
    try:
        result = subprocess.run(
            ["git", "remote", "get-url", remote],
            cwd=ROOT_DIR,
            check=True,
            capture_output=True,
            text=True,
        )
    except Exception:
        return ""
    return result.stdout.strip()


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
    if len(parts) < 2:
        return ""
    return "/".join(parts[:2])


def _default_github_repo() -> str:
    return _github_repo_from_remote(_git_remote_url())


def _release_asset_url(repo: str, release_tag: str, filename: str) -> str:
    if not repo or not release_tag or not filename:
        return ""
    return f"https://github.com/{repo}/releases/download/{release_tag}/{filename}"


def _iter_asset_files() -> list[Path]:
    files: list[Path] = []
    for rel_root in ASSET_ROOTS:
        root = ROOT_DIR / rel_root
        if not root.exists():
            raise FileNotFoundError(f"Missing asset root: {root}")
        if root.is_file():
            files.append(root)
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if "__pycache__" in path.parts:
                continue
            files.append(path)
    return sorted(files, key=lambda p: p.relative_to(ROOT_DIR).as_posix().casefold())


def validate_asset_inputs(files: list[Path]) -> None:
    rel_files = {path.relative_to(ROOT_DIR).as_posix() for path in files}
    missing: list[str] = []
    for rel_root, pattern in REQUIRED_ASSET_GLOBS:
        root = ROOT_DIR / rel_root
        matches = [
            path
            for path in root.glob(pattern)
            if path.is_file() and path.relative_to(ROOT_DIR).as_posix() in rel_files
        ] if root.exists() else []
        if not matches:
            missing.append(f"{rel_root}/{pattern}")
    if missing:
        joined = "\n".join(f"- {item}" for item in missing)
        raise RuntimeError(f"Required runtime asset files are missing from the asset pack:\n{joined}")


def validate_no_unmanaged_runtime_assets(files: list[Path]) -> None:
    """Reject runtime images/fonts placed outside the managed asset roots.

    Code under core/ and gui/ is packaged by PyInstaller, but non-Python files are
    easy to omit accidentally. Runtime images and fonts must live in a managed
    asset root so both full and asset-only releases receive the same files.
    """
    managed = {path.resolve() for path in files}
    unmanaged: list[str] = []
    for rel_root in RUNTIME_SOURCE_DIRS:
        root = ROOT_DIR / rel_root
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if (
                path.is_file()
                and path.suffix.casefold() in RUNTIME_ASSET_EXTENSIONS
                and path.resolve() not in managed
            ):
                unmanaged.append(path.relative_to(ROOT_DIR).as_posix())
    if unmanaged:
        joined = "\n".join(f"- {rel}" for rel in sorted(unmanaged, key=str.casefold))
        raise RuntimeError(
            "Runtime image/font files are outside the managed asset roots. "
            "Move them under assets/templates or add their broad directory to ASSET_ROOTS:\n"
            f"{joined}"
        )


def build_file_manifest(files: list[Path]) -> dict[str, dict[str, object]]:
    manifest: dict[str, dict[str, object]] = {}
    for path in files:
        rel = path.relative_to(ROOT_DIR).as_posix()
        manifest[rel] = {
            "size": path.stat().st_size,
            "sha256": _sha256(path),
        }
    return manifest


def _pyinstaller_asset_data_args() -> list[str]:
    data_args = [
        "gui/font;gui/font",
        "gui/main_ui_color_palete.txt;gui",
        "assets/plana;assets/plana",
    ]
    asset_roots = (
        "templates",
        "regions",
        "data/planning",
        "core/student_meta_data.py",
        "debug/region_captures",
    )
    for rel_root in asset_roots:
        source = ROOT_DIR / rel_root
        if not source.exists():
            raise FileNotFoundError(f"Missing PyInstaller asset input: {source}")
        destination = f"assets/{Path(rel_root).parent.as_posix()}" if source.is_file() else f"assets/{rel_root}"
        if destination.endswith("/."):
            destination = destination[:-2]
        data_args.append(f"{rel_root};{destination}")
    args: list[str] = []
    for data in data_args:
        args.extend(["--add-data", data])
    return args


def build_asset_archive(version: str, output_dir: Path) -> tuple[Path, str]:
    output_dir.mkdir(parents=True, exist_ok=True)
    archive_path = output_dir / f"{ASSET_ARCHIVE_BASENAME}-{version}.zip"
    if archive_path.exists():
        archive_path.unlink()

    files = _iter_asset_files()
    validate_asset_inputs(files)
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            archive.write(path, path.relative_to(ROOT_DIR).as_posix())

    return archive_path, _sha256(archive_path)


def validate_asset_archive(
    archive_path: Path,
    files: dict[str, dict[str, object]],
) -> None:
    """Verify the produced zip contains exactly the manifest files and hashes."""
    with zipfile.ZipFile(archive_path) as archive:
        archive_files = {
            info.filename: info
            for info in archive.infolist()
            if not info.is_dir()
        }
        expected_names = set(files)
        actual_names = set(archive_files)
        missing = sorted(expected_names - actual_names)
        unexpected = sorted(actual_names - expected_names)
        mismatched: list[str] = []
        for rel in sorted(expected_names & actual_names):
            info = archive_files[rel]
            expected = files[rel]
            digest = hashlib.sha256(archive.read(info)).hexdigest()
            if info.file_size != int(expected.get("size") or -1) or digest != str(expected.get("sha256") or ""):
                mismatched.append(rel)
    if missing or unexpected or mismatched:
        details = []
        details.extend(f"missing: {rel}" for rel in missing)
        details.extend(f"unexpected: {rel}" for rel in unexpected)
        details.extend(f"hash/size mismatch: {rel}" for rel in mismatched)
        raise RuntimeError("Asset archive verification failed:\n" + "\n".join(f"- {item}" for item in details))


def validate_full_release(
    *,
    app_archive: Path,
    asset_archive: Path,
    asset_manifest_path: Path,
    app_manifest_path: Path,
) -> None:
    """Verify the full-compile artifacts agree before they can be published."""
    asset_manifest = json.loads(asset_manifest_path.read_text(encoding="utf-8"))
    app_manifest = json.loads(app_manifest_path.read_text(encoding="utf-8"))
    if str(asset_manifest.get("archive_name") or "") != asset_archive.name:
        raise RuntimeError("Asset manifest archive_name does not match the generated asset zip.")
    if str(asset_manifest.get("sha256") or "") != _sha256(asset_archive):
        raise RuntimeError("Asset manifest SHA256 does not match the generated asset zip.")
    if str(app_manifest.get("archive_name") or "") != app_archive.name:
        raise RuntimeError("App manifest archive_name does not match the generated app zip.")
    if str(app_manifest.get("sha256") or "") != _sha256(app_archive):
        raise RuntimeError("App manifest SHA256 does not match the generated app zip.")

    prefix = f"{APP_NAME}/"
    with zipfile.ZipFile(app_archive) as archive:
        names = set(archive.namelist())
        required = {
            f"{prefix}{APP_NAME}.exe",
            f"{prefix}asset_manifest.json",
            f"{prefix}{APP_MANIFEST_NAME}",
        }
        missing = sorted(required - names)
        if missing:
            raise RuntimeError("Full app archive is missing required files:\n" + "\n".join(f"- {name}" for name in missing))
        embedded_asset_manifest = json.loads(archive.read(f"{prefix}asset_manifest.json").decode("utf-8"))
    if embedded_asset_manifest != asset_manifest:
        raise RuntimeError("The app zip contains a stale asset_manifest.json.")


def _safe_version_text(value: str) -> str:
    return "".join(ch if ch.isalnum() or ch in "._-" else "_" for ch in value)


def build_patch_archive(
    *,
    previous_manifest: dict,
    current_manifest: dict[str, dict[str, object]],
    version: str,
    output_dir: Path,
) -> tuple[Path, str, list[str], list[str]] | None:
    previous_version = str(previous_manifest.get("asset_version") or "")
    previous_files = previous_manifest.get("files") or {}
    if not previous_version or not isinstance(previous_files, dict):
        return None

    changed_files = sorted(
        rel
        for rel, info in current_manifest.items()
        if not isinstance(previous_files.get(rel), dict)
        or str(previous_files[rel].get("sha256") or "") != str(info.get("sha256") or "")
    )
    removed_files = sorted(rel for rel in previous_files if rel not in current_manifest)
    if not changed_files and not removed_files:
        return None

    archive_path = output_dir / (
        f"{PATCH_ARCHIVE_BASENAME}-{_safe_version_text(previous_version)}-to-{_safe_version_text(version)}.zip"
    )
    if archive_path.exists():
        archive_path.unlink()
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for rel in changed_files:
            archive.write(ROOT_DIR / rel, rel)
    return archive_path, _sha256(archive_path), changed_files, removed_files


def write_manifest(
    *,
    version: str,
    archive_path: Path,
    sha256: str,
    download_url: str,
    manifest_url: str,
    files: dict[str, dict[str, object]],
    patches: list[dict[str, object]],
    output_dir: Path,
) -> Path:
    manifest = {
        "asset_version": version,
        "archive_name": archive_path.name,
        "url": download_url,
        "manifest_url": manifest_url,
        "sha256": sha256,
        "files": files,
        "patches": patches,
    }
    manifest_path = output_dir / "asset_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return manifest_path


def write_app_manifest(
    *,
    version: str,
    archive_name: str,
    download_url: str,
    manifest_url: str,
    release_url: str,
    sha256: str = "",
    output_dir: Path,
) -> Path:
    manifest = {
        "app_version": version,
        "archive_name": archive_name,
        "url": download_url,
        "manifest_url": manifest_url,
        "release_url": release_url,
        "sha256": sha256,
    }
    manifest_path = output_dir / APP_MANIFEST_NAME
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return manifest_path


def build_exe(manifest_path: Path, app_manifest_path: Path) -> Path:
    pyinstaller = shutil.which("pyinstaller")
    command = [pyinstaller] if pyinstaller else [sys.executable, "-m", "PyInstaller"]
    command.extend(
        [
            "--noconfirm",
            "--clean",
            "--onedir",
            "--windowed",
            "--name",
            APP_NAME,
            *_pyinstaller_asset_data_args(),
            "--collect-all",
            "vgamepad",
            "main.py",
        ]
    )
    subprocess.run(command, cwd=ROOT_DIR, check=True)

    app_dir = ROOT_DIR / "dist" / APP_NAME
    if not app_dir.exists():
        raise RuntimeError(f"PyInstaller output not found: {app_dir}")
    shutil.copy2(manifest_path, app_dir / "asset_manifest.json")
    shutil.copy2(app_manifest_path, app_dir / APP_MANIFEST_NAME)
    return app_dir


def copy_release_files(app_dir: Path, archive_path: Path, manifest_path: Path, app_manifest_path: Path, output_dir: Path) -> None:
    target_app_dir = output_dir / app_dir.name
    if target_app_dir.exists():
        shutil.rmtree(target_app_dir)
    shutil.copytree(app_dir, target_app_dir)
    for source in (archive_path, manifest_path, app_manifest_path):
        destination = output_dir / source.name
        if source.resolve() != destination.resolve():
            shutil.copy2(source, destination)


def zip_app_dir(app_dir: Path, version: str, output_dir: Path) -> Path:
    archive_path = output_dir / f"{APP_ARCHIVE_BASENAME}-{version}.zip"
    if archive_path.exists():
        archive_path.unlink()
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(app_dir.rglob("*"), key=lambda p: p.relative_to(app_dir.parent).as_posix().casefold()):
            if path.is_file():
                archive.write(path, path.relative_to(app_dir.parent).as_posix())
    return archive_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build beta release artifacts.")
    parser.add_argument("--version", required=True, help="Beta version, for example 0.1.0-beta.1")
    parser.add_argument(
        "--asset-url",
        default="",
        help="GitHub Release URL for the asset zip. Leave blank for exe-adjacent zip installs.",
    )
    parser.add_argument(
        "--github-repo",
        default="",
        help="GitHub repo in OWNER/REPO form. Defaults to git remote origin.",
    )
    parser.add_argument(
        "--github-release",
        default="",
        help="Release tag used to auto-fill asset and patch URLs when explicit URLs are omitted.",
    )
    parser.add_argument(
        "--latest-manifest-release",
        default="latest-assets",
        help="Release tag used to auto-fill manifest_url when explicit --manifest-url is omitted.",
    )
    parser.add_argument(
        "--manifest-url",
        default="",
        help="Stable URL for the latest asset_manifest.json used by in-app update checks.",
    )
    parser.add_argument(
        "--previous-manifest",
        default="",
        help="Previous release asset_manifest.json. When provided, a patch zip is generated.",
    )
    parser.add_argument(
        "--patch-url",
        default="",
        help="GitHub Release URL for the generated patch zip. Leave blank for exe-adjacent patch installs.",
    )
    parser.add_argument(
        "--app-url",
        default="",
        help="GitHub Release URL for ba-planner-windows-<version>.zip.",
    )
    parser.add_argument(
        "--app-manifest-url",
        default="",
        help="Stable URL for the latest app_manifest.json used by whole-app update checks.",
    )
    parser.add_argument(
        "--latest-app-manifest-release",
        default="latest-app",
        help="Release tag used to auto-fill app_manifest_url when explicit --app-manifest-url is omitted.",
    )
    parser.add_argument("--skip-exe", action="store_true", help="Only build the asset zip and manifest.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_dir = RELEASE_DIR / args.version
    github_repo = args.github_repo or _default_github_repo()
    asset_files = _iter_asset_files()
    validate_asset_inputs(asset_files)
    if not args.skip_exe:
        validate_no_unmanaged_runtime_assets(asset_files)
    file_manifest = build_file_manifest(asset_files)
    archive_path, digest = build_asset_archive(args.version, output_dir)
    validate_asset_archive(archive_path, file_manifest)
    asset_url = args.asset_url or _release_asset_url(github_repo, args.github_release, archive_path.name)
    manifest_url = args.manifest_url or _release_asset_url(github_repo, args.latest_manifest_release, "asset_manifest.json")
    app_archive_name = f"{APP_ARCHIVE_BASENAME}-{args.version}.zip"
    app_url = args.app_url or _release_asset_url(github_repo, args.github_release, app_archive_name)
    app_manifest_url = args.app_manifest_url or _release_asset_url(
        github_repo,
        args.latest_app_manifest_release,
        APP_MANIFEST_NAME,
    )
    release_url = f"https://github.com/{github_repo}/releases/tag/{args.github_release}" if github_repo and args.github_release else app_url
    patches: list[dict[str, object]] = []
    if args.previous_manifest:
        previous_manifest = json.loads(Path(args.previous_manifest).read_text(encoding="utf-8"))
        patch_result = build_patch_archive(
            previous_manifest=previous_manifest,
            current_manifest=file_manifest,
            version=args.version,
            output_dir=output_dir,
        )
        if patch_result is not None:
            patch_path, patch_digest, changed_files, removed_files = patch_result
            patch_url = args.patch_url or _release_asset_url(github_repo, args.github_release, patch_path.name)
            patches.append(
                {
                    "from": str(previous_manifest.get("asset_version") or ""),
                    "to": args.version,
                    "archive_name": patch_path.name,
                    "url": patch_url,
                    "sha256": patch_digest,
                    "files": changed_files,
                    "removed_files": removed_files,
                }
            )
    manifest_path = write_manifest(
        version=args.version,
        archive_path=archive_path,
        sha256=digest,
        download_url=asset_url,
        manifest_url=manifest_url,
        files=file_manifest,
        patches=patches,
        output_dir=output_dir,
    )

    print(f"Asset archive: {archive_path}")
    print(f"SHA256: {digest}")
    print(f"Manifest: {manifest_path}")
    for patch in patches:
        print(f"Patch archive: {output_dir / str(patch['archive_name'])}")

    if args.skip_exe:
        return 0

    runtime_app_manifest_path = write_app_manifest(
        version=args.version,
        archive_name=app_archive_name,
        download_url=app_url,
        manifest_url=app_manifest_url,
        release_url=release_url,
        output_dir=output_dir,
    )
    app_dir = build_exe(manifest_path, runtime_app_manifest_path)
    copy_release_files(app_dir, archive_path, manifest_path, runtime_app_manifest_path, output_dir)
    app_archive = zip_app_dir(output_dir / app_dir.name, args.version, output_dir)
    app_manifest_path = write_app_manifest(
        version=args.version,
        archive_name=app_archive.name,
        download_url=app_url,
        manifest_url=app_manifest_url,
        release_url=release_url,
        sha256=_sha256(app_archive),
        output_dir=output_dir,
    )
    validate_full_release(
        app_archive=app_archive,
        asset_archive=archive_path,
        asset_manifest_path=manifest_path,
        app_manifest_path=app_manifest_path,
    )
    print(f"Release folder: {output_dir}")
    print(f"App archive: {app_archive}")
    print(f"App manifest: {app_manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

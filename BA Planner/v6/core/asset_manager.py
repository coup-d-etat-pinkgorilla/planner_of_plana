"""
Install and validate external asset packs for beta builds.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from typing import Callable

from core.config import APP_DIR, ASSET_DIR, BASE_DIR, DEFAULT_ASSET_DIR, REGIONS_DIR, TEMPLATE_DIR

DEFAULT_ARCHIVE_NAME = "ba-planner-assets.zip"
MANIFEST_NAME = "asset_manifest.json"
INSTALLED_MANIFEST_NAME = "installed_manifest.json"
ProgressCallback = Callable[[str, int, int], None] | None


def assets_are_ready() -> bool:
    return TEMPLATE_DIR.is_dir() and REGIONS_DIR.is_dir()


def _manifest_candidates() -> tuple[Path, ...]:
    return (
        APP_DIR / MANIFEST_NAME,
        BASE_DIR / MANIFEST_NAME,
    )


def load_asset_manifest() -> dict:
    for path in _manifest_candidates():
        if not path.exists():
            continue
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def _installed_manifest_path() -> Path:
    return DEFAULT_ASSET_DIR / INSTALLED_MANIFEST_NAME


def load_installed_manifest() -> dict:
    path = _installed_manifest_path()
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _write_installed_manifest(manifest: dict) -> None:
    if not manifest:
        return
    path = _installed_manifest_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _download_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def load_latest_asset_manifest(base_manifest: dict | None = None) -> dict:
    manifest = dict(base_manifest or load_asset_manifest())
    manifest_url = str(
        manifest.get("manifest_url")
        or manifest.get("update_manifest_url")
        or ""
    ).strip()
    if not manifest_url:
        return manifest
    try:
        latest = _download_json(manifest_url)
    except Exception:
        return manifest
    return latest if isinstance(latest, dict) else manifest


def _archive_candidates(manifest: dict, *, keys: tuple[str, ...] = ("archive_name",)) -> list[Path]:
    names = [
        *(str(manifest.get(key) or "").strip() for key in keys),
        DEFAULT_ARCHIVE_NAME,
        "assets.zip",
    ]
    result: list[Path] = []
    for name in names:
        if not name:
            continue
        path = Path(name)
        if path.is_absolute():
            result.append(path)
        else:
            result.extend((APP_DIR / path, APP_DIR.parent / path, BASE_DIR / path))
    return result


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _verify_archive(path: Path, expected_sha256: str) -> None:
    if not expected_sha256:
        return
    actual = _sha256(path)
    if actual.casefold() != expected_sha256.casefold():
        raise RuntimeError(
            f"Asset archive checksum mismatch: expected {expected_sha256}, got {actual}"
        )


def _download_archive(
    manifest: dict,
    destination: Path,
    *,
    url_keys: tuple[str, ...] = ("url",),
    progress: ProgressCallback = None,
) -> Path:
    url = ""
    for key in url_keys:
        url = str(manifest.get(key) or "").strip()
        if url:
            break
    if not url:
        raise RuntimeError(
            "Asset pack is missing. Put ba-planner-assets.zip next to the exe, "
            "or fill asset_manifest.json with a GitHub Release download URL."
        )
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=30) as response, destination.open("wb") as handle:
        total = int(response.headers.get("Content-Length") or 0)
        downloaded = 0
        if progress:
            progress("download", downloaded, total)
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            handle.write(chunk)
            downloaded += len(chunk)
            if progress:
                progress("download", downloaded, total)
    return destination


def _safe_extract(archive_path: Path, destination: Path) -> None:
    destination = destination.resolve()
    with zipfile.ZipFile(archive_path) as archive:
        for member in archive.infolist():
            target = (destination / member.filename).resolve()
            if destination != target and destination not in target.parents:
                raise RuntimeError(f"Unsafe path in asset archive: {member.filename}")
        archive.extractall(destination)


def _normalize_extracted_root(staging: Path) -> Path:
    if (staging / "templates").is_dir() and (staging / "regions").is_dir():
        return staging
    children = [child for child in staging.iterdir() if child.is_dir()]
    if len(children) == 1 and (children[0] / "templates").is_dir() and (children[0] / "regions").is_dir():
        return children[0]
    raise RuntimeError("Asset archive must contain templates/ and regions/ directories.")


def install_asset_archive(
    archive_path: Path,
    *,
    expected_sha256: str = "",
    manifest: dict | None = None,
    progress: ProgressCallback = None,
) -> Path:
    archive_path = archive_path.resolve()
    if not archive_path.exists():
        raise FileNotFoundError(f"Asset archive not found: {archive_path}")
    if progress:
        progress("verify", 0, 0)
    _verify_archive(archive_path, expected_sha256)

    target = DEFAULT_ASSET_DIR
    target.parent.mkdir(parents=True, exist_ok=True)
    if progress:
        progress("extract", 0, 0)
    with tempfile.TemporaryDirectory(prefix="ba-planner-assets-") as tmp:
        staging = Path(tmp) / "extract"
        staging.mkdir(parents=True, exist_ok=True)
        _safe_extract(archive_path, staging)
        extracted_root = _normalize_extracted_root(staging)

        if progress:
            progress("install", 0, 0)
        replacement = target.parent / f"{target.name}.new"
        if replacement.exists():
            shutil.rmtree(replacement)
        shutil.move(str(extracted_root), str(replacement))
        if target.exists():
            backup = target.parent / f"{target.name}.old"
            if backup.exists():
                shutil.rmtree(backup)
            os.replace(target, backup)
            os.replace(replacement, target)
            shutil.rmtree(backup, ignore_errors=True)
        else:
            os.replace(replacement, target)
    if manifest:
        _write_installed_manifest(manifest)
    if progress:
        progress("done", 0, 0)
    return target


def _copy_tree_contents(source: Path, destination: Path) -> None:
    for path in source.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(source)
        target = destination / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)


def _verify_manifest_files(root: Path, manifest: dict, *, changed_only: set[str] | None = None) -> None:
    files = manifest.get("files")
    if not isinstance(files, dict):
        return
    for rel_path, info in files.items():
        rel_text = str(rel_path).replace("\\", "/")
        if changed_only is not None and rel_text not in changed_only:
            continue
        if not isinstance(info, dict):
            continue
        expected_sha256 = str(info.get("sha256") or "")
        if not expected_sha256:
            continue
        path = root / rel_text
        if not path.exists():
            raise RuntimeError(f"Updated asset file is missing: {rel_text}")
        actual = _sha256(path)
        if actual.casefold() != expected_sha256.casefold():
            raise RuntimeError(f"Updated asset checksum mismatch: {rel_text}")


def apply_patch_archive(
    archive_path: Path,
    patch: dict,
    target_manifest: dict,
    *,
    progress: ProgressCallback = None,
) -> Path:
    archive_path = archive_path.resolve()
    if not archive_path.exists():
        raise FileNotFoundError(f"Asset patch not found: {archive_path}")
    if progress:
        progress("verify", 0, 0)
    _verify_archive(archive_path, str(patch.get("sha256") or ""))

    target = DEFAULT_ASSET_DIR
    target.mkdir(parents=True, exist_ok=True)
    if progress:
        progress("extract", 0, 0)
    with tempfile.TemporaryDirectory(prefix="ba-planner-patch-") as tmp:
        staging = Path(tmp) / "extract"
        staging.mkdir(parents=True, exist_ok=True)
        _safe_extract(archive_path, staging)
        _copy_tree_contents(staging, target)

    for rel_path in patch.get("removed_files") or ():
        path = target / str(rel_path).replace("\\", "/")
        if path.exists() and path.is_file():
            path.unlink()

    changed_files = {
        str(rel_path).replace("\\", "/")
        for rel_path in patch.get("files") or ()
    }
    _verify_manifest_files(target, target_manifest, changed_only=changed_files or None)
    _write_installed_manifest(target_manifest)
    if progress:
        progress("done", 0, 0)
    return target


def _version(manifest: dict) -> str:
    return str(manifest.get("asset_version") or "")


def _find_patch(installed_manifest: dict, latest_manifest: dict) -> dict | None:
    installed_version = _version(installed_manifest)
    latest_version = _version(latest_manifest)
    if not installed_version or not latest_version or installed_version == latest_version:
        return None
    for patch in latest_manifest.get("patches") or ():
        if not isinstance(patch, dict):
            continue
        if str(patch.get("from") or "") == installed_version and str(patch.get("to") or "") == latest_version:
            return patch
    return None


def _local_or_download_archive(
    manifest: dict,
    *,
    archive_keys: tuple[str, ...],
    url_keys: tuple[str, ...],
    progress: ProgressCallback = None,
) -> Path:
    for candidate in _archive_candidates(manifest, keys=archive_keys):
        if candidate.exists():
            return candidate
    archive_name = str(manifest.get(archive_keys[0]) or DEFAULT_ARCHIVE_NAME)
    download_target = DEFAULT_ASSET_DIR.parent / archive_name
    return _download_archive(manifest, download_target, url_keys=url_keys, progress=progress)


def update_assets_if_available(progress: ProgressCallback = None) -> Path:
    if not assets_are_ready():
        return ASSET_DIR

    base_manifest = load_asset_manifest()
    latest_manifest = load_latest_asset_manifest(base_manifest)
    latest_version = _version(latest_manifest)
    if not latest_version:
        return ASSET_DIR

    installed_manifest = load_installed_manifest()
    installed_version = _version(installed_manifest)
    if installed_version == latest_version:
        return ASSET_DIR

    patch = _find_patch(installed_manifest, latest_manifest)
    if patch is not None:
        try:
            patch_path = _local_or_download_archive(
                patch,
                archive_keys=("archive_name", "patch_name"),
                url_keys=("url", "patch_url"),
                progress=progress,
            )
            return apply_patch_archive(patch_path, patch, latest_manifest, progress=progress)
        except Exception:
            pass

    if not installed_version and ASSET_DIR != DEFAULT_ASSET_DIR:
        return ASSET_DIR

    full_path = _local_or_download_archive(
        latest_manifest,
        archive_keys=("archive_name",),
        url_keys=("url", "asset_url"),
        progress=progress,
    )
    return install_asset_archive(
        full_path,
        expected_sha256=str(latest_manifest.get("sha256") or ""),
        manifest=latest_manifest,
        progress=progress,
    )


def ensure_assets_ready(progress: ProgressCallback = None) -> Path:
    if assets_are_ready():
        return update_assets_if_available(progress=progress)

    manifest = load_asset_manifest()
    latest_manifest = load_latest_asset_manifest(manifest)
    manifest = latest_manifest or manifest
    expected_sha256 = str(manifest.get("sha256") or "").strip()
    for candidate in _archive_candidates(manifest):
        if candidate.exists():
            return install_asset_archive(candidate, expected_sha256=expected_sha256, manifest=manifest, progress=progress)

    archive_name = str(manifest.get("archive_name") or DEFAULT_ARCHIVE_NAME)
    download_target = DEFAULT_ASSET_DIR.parent / archive_name
    return install_asset_archive(
        _download_archive(manifest, download_target, progress=progress),
        expected_sha256=expected_sha256,
        manifest=manifest,
        progress=progress,
    )

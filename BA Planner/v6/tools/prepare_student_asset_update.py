from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from PIL import Image

from tools.schaledb_sync import build_student_meta_from_schale, parse_student_source, schale_path_to_local_id
from tools.student_meta_tool import _write_students, get_students

RELEASE_DIR = ROOT_DIR / "release"
TEMPLATE_DIR = ROOT_DIR / "templates" / "students"
PORTRAIT_DIR = ROOT_DIR / "templates" / "students_portraits"
ELEPH_DIR = ROOT_DIR / "templates" / "students_elephs"


def _normalize_student_id(source: str, explicit_student_id: str = "") -> str:
    if explicit_student_id.strip():
        return explicit_student_id.strip().lower()
    return schale_path_to_local_id(parse_student_source(source))


def _copy_image(source: Path, destination: Path, *, overwrite: bool) -> None:
    if not source.exists():
        raise FileNotFoundError(f"Image not found: {source}")
    if destination.exists() and not overwrite:
        raise FileExistsError(f"Destination already exists: {destination}")

    destination.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        image.load()
        if source.suffix.casefold() == ".png":
            shutil.copy2(source, destination)
            return
        mode = "RGBA" if "A" in image.getbands() else "RGB"
        image.convert(mode).save(destination, format="PNG")


def _validate_image(source: Path) -> None:
    if not source.exists():
        raise FileNotFoundError(f"Image not found: {source}")
    with Image.open(source) as image:
        image.verify()


def _check_destinations(outputs: dict[str, Path], *, overwrite: bool) -> None:
    if overwrite:
        return
    existing = [path for path in outputs.values() if path.exists()]
    if existing:
        joined = "\n".join(str(path) for path in existing)
        raise FileExistsError(f"Destination image already exists. Use --overwrite to replace:\n{joined}")


def _install_images(
    *,
    student_id: str,
    template_image: Path,
    portrait_image: Path,
    eleph_image: Path,
    overwrite: bool,
) -> list[Path]:
    outputs = [
        TEMPLATE_DIR / f"{student_id}.png",
        PORTRAIT_DIR / f"{student_id}.png",
        ELEPH_DIR / f"Item_Icon_SecretStone_{student_id}.png",
    ]
    _copy_image(template_image, outputs[0], overwrite=overwrite)
    _copy_image(portrait_image, outputs[1], overwrite=overwrite)
    _copy_image(eleph_image, outputs[2], overwrite=overwrite)
    return outputs


def _sync_student_meta(source: str, student_id: str, *, force_refresh: bool) -> dict:
    students = get_students()
    payload = build_student_meta_from_schale(
        source,
        existing_students=students,
        preferred_student_id=student_id,
        force_refresh=force_refresh,
    )
    students[str(payload["student_id"])] = dict(payload["meta"])
    _write_students(students)
    return payload


def _build_update_artifacts(args: argparse.Namespace) -> None:
    command = [
        sys.executable,
        str(ROOT_DIR / "tools" / "build_beta_release.py"),
        "--version",
        args.version,
        "--skip-exe",
    ]
    if args.previous_manifest:
        command.extend(["--previous-manifest", args.previous_manifest])
    if args.asset_url:
        command.extend(["--asset-url", args.asset_url])
    if args.patch_url:
        command.extend(["--patch-url", args.patch_url])
    if args.manifest_url:
        command.extend(["--manifest-url", args.manifest_url])
    if args.github_repo:
        command.extend(["--github-repo", args.github_repo])
    if args.github_release:
        command.extend(["--github-release", args.github_release])
    if args.latest_manifest_release:
        command.extend(["--latest-manifest-release", args.latest_manifest_release])
    subprocess.run(command, cwd=ROOT_DIR, check=True)


def _load_manifest(version: str) -> dict:
    manifest_path = RELEASE_DIR / version / "asset_manifest.json"
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def _write_release_notes(
    *,
    version: str,
    student_id: str,
    schale_source: str,
    meta_payload: dict,
    image_outputs: list[Path],
    manifest: dict,
) -> Path:
    release_dir = RELEASE_DIR / version
    patch_names = [str(patch.get("archive_name")) for patch in manifest.get("patches") or ()]
    lines = [
        f"# BA Planner Asset Update {version}",
        "",
        "## Student",
        "",
        f"- SchaleDB source: `{schale_source}`",
        f"- Local student id: `{student_id}`",
        f"- Display name: `{meta_payload.get('meta', {}).get('display_name', student_id)}`",
        f"- SchaleDB slug: `{meta_payload.get('slug', '')}`",
        f"- New student: `{bool(meta_payload.get('is_new'))}`",
        "",
        "## Changed Inputs",
        "",
        *[f"- `{path.relative_to(ROOT_DIR).as_posix()}`" for path in image_outputs],
        "- `core/student_meta_data.py`",
        "",
        "## Upload Files",
        "",
        f"- `ba-planner-assets-{version}.zip`",
        "- `asset_manifest.json`",
    ]
    lines.extend(f"- `{name}`" for name in patch_names if name)
    lines.extend(
        [
            "",
            "## Changed Metadata Fields",
            "",
        ]
    )
    changed_fields = list(meta_payload.get("changed_fields") or ())
    lines.extend(f"- `{field}`" for field in changed_fields)
    if not changed_fields:
        lines.append("- None")

    notes_path = release_dir / f"release_notes_{version}.md"
    notes_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return notes_path


def _upload_with_gh(version: str, github_release: str) -> None:
    gh = shutil.which("gh")
    if not gh:
        winget_gh = Path.home() / "AppData" / "Local" / "Microsoft" / "WinGet" / "Packages" / "GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe" / "bin" / "gh.exe"
        if winget_gh.exists():
            gh = str(winget_gh)
    if not gh:
        raise RuntimeError("GitHub CLI is not installed or not on PATH.")

    release_dir = RELEASE_DIR / version
    upload_files = [
        release_dir / "asset_manifest.json",
        release_dir / f"ba-planner-assets-{version}.zip",
    ]
    manifest = _load_manifest(version)
    for patch in manifest.get("patches") or ():
        name = str(patch.get("archive_name") or "")
        if name:
            upload_files.append(release_dir / name)
    subprocess.run(
        [gh, "release", "upload", github_release, *[str(path) for path in upload_files], "--clobber"],
        cwd=ROOT_DIR,
        check=True,
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare a new-student asset update from SchaleDB metadata and three image files."
    )
    parser.add_argument("--schale-source", required=True, help="SchaleDB student slug or URL, for example hoshino_battle_tank.")
    parser.add_argument("--student-id", default="", help="Override local student_id. Defaults to converted SchaleDB slug.")
    parser.add_argument("--template-image", required=True, help="Template matching image.")
    parser.add_argument("--portrait-image", required=True, help="Student portrait image.")
    parser.add_argument("--eleph-image", required=True, help="Eleph/secret-stone image.")
    parser.add_argument("--version", required=True, help="Asset update version, for example 0.1.0-beta.2.")
    parser.add_argument("--previous-manifest", default="", help="Previous asset_manifest.json used to generate a patch zip.")
    parser.add_argument("--asset-url", default="", help="Final GitHub URL for ba-planner-assets-<version>.zip.")
    parser.add_argument("--patch-url", default="", help="Final GitHub URL for the generated patch zip.")
    parser.add_argument("--manifest-url", default="", help="Stable latest asset_manifest.json URL used by app update checks.")
    parser.add_argument("--github-repo", default="", help="GitHub repo in OWNER/REPO form. Defaults to git remote origin.")
    parser.add_argument("--force-refresh", action="store_true", help="Refetch SchaleDB students/items instead of using cache.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite existing local image files.")
    parser.add_argument("--dry-run", action="store_true", help="Validate inputs and print planned paths without writing files.")
    parser.add_argument("--github-release", default="", help="Optional GitHub release tag used for generated URLs and gh release upload.")
    parser.add_argument("--latest-manifest-release", default="latest-assets", help="Release tag that hosts the latest asset_manifest.json.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    student_id = _normalize_student_id(args.schale_source, args.student_id)
    image_inputs = {
        "template": Path(args.template_image),
        "portrait": Path(args.portrait_image),
        "eleph": Path(args.eleph_image),
    }
    image_outputs = {
        "template": TEMPLATE_DIR / f"{student_id}.png",
        "portrait": PORTRAIT_DIR / f"{student_id}.png",
        "eleph": ELEPH_DIR / f"Item_Icon_SecretStone_{student_id}.png",
    }

    print(f"student_id: {student_id}")
    for label, source in image_inputs.items():
        print(f"{label}: {source} -> {image_outputs[label]}")

    for source in image_inputs.values():
        _validate_image(source)
    _check_destinations(image_outputs, overwrite=args.overwrite)

    if args.dry_run:
        return 0

    written_images = _install_images(
        student_id=student_id,
        template_image=image_inputs["template"],
        portrait_image=image_inputs["portrait"],
        eleph_image=image_inputs["eleph"],
        overwrite=args.overwrite,
    )
    meta_payload = _sync_student_meta(args.schale_source, student_id, force_refresh=args.force_refresh)
    _build_update_artifacts(args)
    manifest = _load_manifest(args.version)
    notes_path = _write_release_notes(
        version=args.version,
        student_id=student_id,
        schale_source=args.schale_source,
        meta_payload=meta_payload,
        image_outputs=written_images,
        manifest=manifest,
    )

    if args.github_release:
        _upload_with_gh(args.version, args.github_release)

    release_dir = RELEASE_DIR / args.version
    print(f"release_dir: {release_dir}")
    print(f"release_notes: {notes_path}")
    for patch in manifest.get("patches") or ():
        print(f"patch: {release_dir / str(patch.get('archive_name'))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
V6_ROOT = REPOSITORY_ROOT.parent / "v6"
RECOGNITION_ROOT = REPOSITORY_ROOT / "backend" / "assets" / "recognition" / "v1"
FIXTURE_DESTINATION = (
    REPOSITORY_ROOT / "backend" / "tests" / "fixtures" / "student_scan_s2_serika_new_year.png"
)

ASSET_GROUPS = (
    ("basic_skill", "student-basic-skill-template"),
    ("basic_student/level_digits", "student-basic-level-digit-template"),
    ("basic_combat_stat_digits", "student-basic-combat-digit-template"),
    ("weaponlevel_glyph", "student-basic-weapon-level-digit-template"),
)


def _digest(path: Path) -> tuple[int, str]:
    content = path.read_bytes()
    return len(content), hashlib.sha256(content).hexdigest()


def _identity(source_group: str, path: Path) -> str:
    if source_group == "basic_skill":
        return path.stem.split("_", 1)[0]
    if source_group == "basic_student/level_digits":
        return path.stem.split("_", 1)[0]
    if source_group == "basic_combat_stat_digits":
        return path.parent.name
    return path.stem


def sync() -> dict[str, int]:
    if not V6_ROOT.is_dir():
        raise FileNotFoundError(f"v6 reference tree not found: {V6_ROOT}")
    assets: list[dict[str, object]] = []

    copied = 0
    for source_group, purpose in ASSET_GROUPS:
        source_root = V6_ROOT / "templates" / Path(source_group)
        destination_root = RECOGNITION_ROOT / "templates" / "student_basic" / Path(source_group)
        if destination_root.exists():
            shutil.rmtree(destination_root)
        for source in sorted(source_root.rglob("*.png")):
            relative = source.relative_to(source_root)
            destination = destination_root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            size, digest = _digest(destination)
            assets.append({
                "path": destination.relative_to(RECOGNITION_ROOT).as_posix(),
                "scan_kind": "student",
                "purpose": purpose,
                "digit" if "digit" in purpose else "student_value": _identity(source_group, source),
                "required": True,
                "bytes": size,
                "sha256": digest,
                "source_path": f"../v6/templates/{source.relative_to(V6_ROOT / 'templates').as_posix()}",
            })
            copied += 1

    auxiliary_manifest = {
        "version": 1,
        "source_version": "student-basic-s2-2026-08-21",
        "assets": sorted(assets, key=lambda item: str(item["path"])),
    }
    (RECOGNITION_ROOT / "student_basic_manifest.json").write_text(
        json.dumps(auxiliary_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    fixture_source = (
        V6_ROOT
        / "debug"
        / "student_level_roi_per_image_20260624_2152_otsu_center_safe"
        / "02_lv12_215255_overlay.png"
    )
    FIXTURE_DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(fixture_source, FIXTURE_DESTINATION)
    return {"recognition_assets": copied, "fixtures": 1}


if __name__ == "__main__":
    print(json.dumps(sync(), sort_keys=True))

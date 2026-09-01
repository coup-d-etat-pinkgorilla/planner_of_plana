from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
V6_ROOT = REPOSITORY_ROOT.parent / "v6"
RECOGNITION_ROOT = REPOSITORY_ROOT / "backend" / "assets" / "recognition" / "v1"
DESTINATION_ROOT = RECOGNITION_ROOT / "templates" / "student_weapon"


def _digest(path: Path) -> tuple[int, str]:
    content = path.read_bytes()
    return len(content), hashlib.sha256(content).hexdigest()


def _copy(source: Path, relative: Path, purpose: str, identity: str) -> dict[str, object]:
    destination = RECOGNITION_ROOT / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    size, digest = _digest(destination)
    return {
        "path": relative.as_posix(),
        "scan_kind": "student",
        "purpose": purpose,
        "required": True,
        "bytes": size,
        "sha256": digest,
        "source_path": f"../v6/{source.relative_to(V6_ROOT).as_posix()}",
        "weapon_value": identity,
    }


def sync() -> dict[str, int]:
    if not V6_ROOT.is_dir():
        raise FileNotFoundError(f"v6 reference tree not found: {V6_ROOT}")
    assets: list[dict[str, object]] = []

    regions = json.loads(
        (V6_ROOT / "regions" / "student_weaponmenu_regions.json").read_text(
            encoding="utf-8-sig"
        )
    )
    student_data = json.loads(
        (V6_ROOT / "regions" / "student_data_regions.json").read_text(
            encoding="utf-8-sig"
        )
    )["student_data"]
    regions["basic_weapon_state_region"] = student_data["weapon_detect_flag_region"]
    for key in ("weapon_info_menu_button", "weapon_menu_quit_button"):
        regions[key] = student_data[key]
    region_path = RECOGNITION_ROOT / "regions" / "student_weapon_regions.json"
    region_path.parent.mkdir(parents=True, exist_ok=True)
    region_path.write_text(
        json.dumps(regions, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    size, digest = _digest(region_path)
    assets.append({
        "path": "regions/student_weapon_regions.json",
        "scan_kind": "student",
        "purpose": "student-weapon-regions",
        "required": True,
        "bytes": size,
        "sha256": digest,
        "source_path": "adapted:../v6/regions/student_weaponmenu_regions.json+student_data_regions.json",
    })

    for source in sorted((V6_ROOT / "templates" / "weapon_state").glob("*.png")):
        assets.append(_copy(
            source,
            Path("templates/student_weapon/state") / source.name,
            "student-weapon-state-template",
            source.stem.casefold(),
        ))
    for position in (1, 2):
        for source in sorted(
            (V6_ROOT / "templates" / f"weaponlevel_digit{position}").glob("*.png")
        ):
            digit = source.stem.split("_", 1)[-1]
            assets.append(_copy(
                source,
                Path(f"templates/student_weapon/menu/level_digit{position}") / source.name,
                "student-weapon-menu-level-template",
                f"{position}:{digit}",
            ))
    for source in sorted((V6_ROOT / "templates" / "weapon_star").glob("*.png")):
        star = source.stem.split("_", 1)[-1]
        assets.append(_copy(
            source,
            Path("templates/student_weapon/menu/star") / source.name,
            "student-weapon-menu-star-template",
            star,
        ))

    manifest = {
        "version": 1,
        "source_version": "student-weapon-s2w-v6-parity-2026-08-30",
        "assets": sorted(assets, key=lambda item: str(item["path"])),
    }
    (RECOGNITION_ROOT / "student_weapon_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return {"recognition_assets": len(assets)}


if __name__ == "__main__":
    print(json.dumps(sync(), sort_keys=True))

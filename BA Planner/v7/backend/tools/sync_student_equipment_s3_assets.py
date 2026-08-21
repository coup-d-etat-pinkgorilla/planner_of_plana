from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
V6_ROOT = REPOSITORY_ROOT.parent / "v6"
RECOGNITION_ROOT = REPOSITORY_ROOT / "backend" / "assets" / "recognition" / "v1"
DESTINATION_ROOT = RECOGNITION_ROOT / "templates" / "student_equipment"


def _digest(path: Path) -> tuple[int, str]:
    content = path.read_bytes()
    return len(content), hashlib.sha256(content).hexdigest()


def _copy(source: Path, relative: Path, purpose: str, identity: str | None = None) -> dict[str, object]:
    destination = RECOGNITION_ROOT / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    size, digest = _digest(destination)
    entry: dict[str, object] = {
        "path": relative.as_posix(),
        "scan_kind": "student",
        "purpose": purpose,
        "required": True,
        "bytes": size,
        "sha256": digest,
        "source_path": f"../v6/{source.relative_to(V6_ROOT).as_posix()}",
    }
    if identity is not None:
        entry["equipment_value"] = identity
    return entry


def sync() -> dict[str, int]:
    if not V6_ROOT.is_dir():
        raise FileNotFoundError(f"v6 reference tree not found: {V6_ROOT}")
    if DESTINATION_ROOT.exists():
        shutil.rmtree(DESTINATION_ROOT)
    assets: list[dict[str, object]] = []

    assets.append(_copy(
        V6_ROOT / "templates" / "icons" / "temp" / "square.png",
        Path("templates/student_equipment/card_background.png"),
        "student-equipment-card-background",
    ))
    bold_fonts = sorted((V6_ROOT / "gui" / "font").glob("*Bold.ttf"))
    if not bold_fonts:
        raise FileNotFoundError("v6 equipment rendering font is missing")
    assets.append(_copy(
        bold_fonts[0], Path("templates/student_equipment/equipment_level_bold.ttf"),
        "student-equipment-font",
    ))
    region_entry = _copy(
        V6_ROOT / "regions" / "student_equipment_regions.json",
        Path("regions/student_equipment_regions.json"),
        "student-equipment-menu-regions",
    )
    region_destination = RECOGNITION_ROOT / "regions" / "student_equipment_regions.json"
    menu_regions = json.loads(region_destination.read_text(encoding="utf-8-sig"))
    student_data = json.loads(
        (V6_ROOT / "regions" / "student_data_regions.json").read_text(encoding="utf-8-sig")
    )["student_data"]
    for key in ("equipment_button", "equipmentmenu_quit_button"):
        menu_regions[key] = student_data[key]
    region_destination.write_text(
        json.dumps(menu_regions, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
    )
    region_entry["bytes"], region_entry["sha256"] = _digest(region_destination)
    assets.append(region_entry)

    for source in sorted((V6_ROOT / "templates" / "equip4_basic").glob("*.png")):
        tier = source.stem.rsplit("_", 1)[-1]
        assets.append(_copy(
            source, Path("templates/student_equipment/favorite") / source.name,
            "student-equipment-favorite-template", tier,
        ))

    for slot in (1, 2, 3, 4):
        for source in sorted((V6_ROOT / "templates" / f"equip{slot}").glob("*.png")):
            tier = source.stem.rsplit("_", 1)[-1]
            assets.append(_copy(
                source, Path(f"templates/student_equipment/menu/equip{slot}") / source.name,
                "student-equipment-menu-tier-template", f"{slot}:{tier}",
            ))
        flag_root = V6_ROOT / "templates" / f"equip{slot}_flag"
        for source in sorted(flag_root.glob("*.png")):
            flag = source.stem.removeprefix(f"equip{slot}_")
            assets.append(_copy(
                source, Path(f"templates/student_equipment/menu/equip{slot}_flag") / source.name,
                "student-equipment-menu-flag-template", f"{slot}:{flag}",
            ))
        if slot <= 3:
            for position in (1, 2):
                digit_root = V6_ROOT / "templates" / f"equip{slot}level_digit{position}"
                for source in sorted(digit_root.glob("*.png")):
                    digit = source.stem.split("_", 1)[-1]
                    assets.append(_copy(
                        source,
                        Path(f"templates/student_equipment/menu/equip{slot}level_digit{position}") / source.name,
                        "student-equipment-menu-digit-template", f"{slot}:{position}:{digit}",
                    ))

    manifest = {
        "version": 1,
        "source_version": "student-equipment-s3-2026-08-21",
        "assets": sorted(assets, key=lambda item: str(item["path"])),
    }
    (RECOGNITION_ROOT / "student_equipment_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
    )
    return {"recognition_assets": len(assets)}


if __name__ == "__main__":
    print(json.dumps(sync(), sort_keys=True))

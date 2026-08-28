from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

from tools.build_student_studio_text_templates import ROOT, SUGGESTION, build


ASSET_ROOT = ROOT / "backend" / "assets" / "recognition" / "v1"
BANK_RELATIVE = Path("templates/student_numeric_studio/position_digit_bank.json")
BANK_PATH = ASSET_ROOT / BANK_RELATIVE
BASIC_MANIFEST = ASSET_ROOT / "student_basic_manifest.json"
ROOT_MANIFEST = ASSET_ROOT / "manifest.json"
REGION_RELATIVE = Path("regions/student_normal_info_regions.json")
REGION_PATH = ASSET_ROOT / REGION_RELATIVE
PURPOSE = "student-studio-numeric-digit-bank"


GROUPS = {
    "basic_student_level_studio_cells": (
        "studentlevel_digit1", "studentlevel_digit2",
    ),
    "basic_weapon_level_studio_cells": (
        "weaponlevel_digit1", "weaponlevel_digit2",
    ),
    "basic_equipment_1_level_studio_cells": (
        "equip1level_digit1", "equip1level_digit2",
    ),
    "basic_equipment_2_level_studio_cells": (
        "equip2level_digit1", "equip2level_digit2",
    ),
    "basic_equipment_3_level_studio_cells": (
        "equip3level_digit1", "equip3level_digit2",
    ),
    "basic_relationship_rank_studio_1_cells": (
        "affectionlevel_1digit_digit1",
    ),
    "basic_relationship_rank_studio_2_cells": (
        "affectionlevel_digit1", "affectionlevel_digit2",
    ),
    "basic_relationship_rank_studio_3_cells": (
        "affectionlevel_3digit_digit1", "affectionlevel_3digit_digit2",
        "affectionlevel_3digit_digit3",
    ),
}


def _digest(path: Path) -> tuple[int, str]:
    content = path.read_bytes()
    return len(content), hashlib.sha256(content).hexdigest()


def _bits(mask: Image.Image) -> tuple[str, int]:
    value = 0
    ink = 0
    for index, pixel in enumerate(mask.convert("L").getdata()):
        if pixel >= 127:
            value |= 1 << index
            ink += 1
    return format(value, "x"), ink


def _sync_regions() -> None:
    suggestion = json.loads(SUGGESTION.read_text(encoding="utf-8"))
    reference_width, reference_height = 2560, 1440
    roi_lookup = {row["name"]: row for row in suggestion["rois"]}
    regions = json.loads(REGION_PATH.read_text(encoding="utf-8"))
    for group, names in GROUPS.items():
        cells = []
        for name in names:
            roi = roi_lookup[name]
            cells.append({
                "roi": name,
                "shape": roi.get("shape", "rectangle"),
                "points_ratio": [
                    {
                        "x": float(point["x"]) / reference_width,
                        "y": float(point["y"]) / reference_height,
                    }
                    for point in roi["points"]
                ],
            })
        regions[group] = {"source": "suggestion.json", "cells": cells}
    REGION_PATH.write_text(
        json.dumps(regions, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    size, digest = _digest(REGION_PATH)
    root_manifest = json.loads(ROOT_MANIFEST.read_text(encoding="utf-8"))
    entry = next(
        row for row in root_manifest["assets"]
        if row["path"] == REGION_RELATIVE.as_posix()
    )
    entry["bytes"] = size
    entry["sha256"] = digest
    ROOT_MANIFEST.write_text(
        json.dumps(root_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def sync() -> dict[str, int | str]:
    built = build()
    renderer_spec = json.loads(Path(built["spec"]).read_text(encoding="utf-8"))
    templates = []
    for row in renderer_spec["templates"]:
        with Image.open(ROOT / row["path"]) as opened:
            mask = opened.convert("L")
        bits_hex, ink = _bits(mask)
        templates.append({
            "roi": row["roi"],
            "field": row["field"],
            "digit": row["digit"],
            "width": mask.width,
            "height": mask.height,
            "pixels": mask.width * mask.height,
            "ink": ink,
            "bits_hex": bits_hex,
            "source_sha256": row["sha256"],
        })
        mask.close()
    payload = {
        "schema_version": 1,
        "purpose": "production Studio-aligned numeric position bank",
        "template_count": len(templates),
        "sources": renderer_spec["source"],
        "processing": renderer_spec["processing"],
        "templates": sorted(
            templates,
            key=lambda row: (str(row["field"]), str(row["roi"]), str(row["digit"])),
        ),
    }
    payload["processing"]["production"] = True
    BANK_PATH.parent.mkdir(parents=True, exist_ok=True)
    BANK_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    size, digest = _digest(BANK_PATH)
    manifest = json.loads(BASIC_MANIFEST.read_text(encoding="utf-8"))
    manifest["assets"] = [
        row for row in manifest["assets"] if row.get("purpose") != PURPOSE
    ]
    manifest["assets"].append({
        "path": BANK_RELATIVE.as_posix(),
        "scan_kind": "student",
        "purpose": PURPOSE,
        "required": True,
        "bytes": size,
        "sha256": digest,
        "source_path": "generated:suggestion_text-layout-position-bank-v1",
    })
    manifest["assets"] = sorted(manifest["assets"], key=lambda row: str(row["path"]))
    BASIC_MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    _sync_regions()
    return {
        "templates": len(templates),
        "bank": BANK_RELATIVE.as_posix(),
        "region_groups": len(GROUPS),
    }


if __name__ == "__main__":
    print(json.dumps(sync(), ensure_ascii=False, sort_keys=True))

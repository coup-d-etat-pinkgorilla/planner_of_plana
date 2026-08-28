from __future__ import annotations

from hashlib import sha256
import json
from pathlib import Path

from PIL import Image

from core.student_scan_recognizer import (
    relationship_rank_number_mask,
    split_relationship_rank_digits,
)


BACKEND = Path(__file__).resolve().parents[1]
FIXTURE = BACKEND / "tests" / "fixtures" / "student_relationship_s4"
ASSETS = BACKEND / "assets" / "recognition" / "v1"
OUTPUT = ASSETS / "templates" / "student_relationship_rank_digits"
PURPOSE = "student-relationship-rank-digit-template"


def main() -> None:
    manifest = json.loads((FIXTURE / "manifest.json").read_text(encoding="utf-8"))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    entries: list[dict[str, object]] = []
    counters = {str(value): 0 for value in range(10)}
    with Image.open(FIXTURE / manifest["atlas"]["path"]) as atlas:
        for record in manifest["records"]:
            if record["partition"] not in {"calibration", "calibration_only"}:
                continue
            label = str(record["rank"])
            crop = atlas.crop(record["atlas_box"])
            glyphs = split_relationship_rank_digits(
                relationship_rank_number_mask(crop),
                len(label),
            )
            if len(glyphs) != len(label):
                raise ValueError(f"could not split relationship rank {label}")
            for digit, glyph in zip(label, glyphs):
                index = counters[digit]
                counters[digit] += 1
                target = OUTPUT / digit / f"{digit}_{index:02d}.png"
                target.parent.mkdir(parents=True, exist_ok=True)
                glyph.save(target)
                content = target.read_bytes()
                entries.append(
                    {
                        "path": target.relative_to(ASSETS).as_posix(),
                        "scan_kind": "student",
                        "purpose": PURPOSE,
                        "digit": digit,
                        "required": True,
                        "bytes": len(content),
                        "sha256": sha256(content).hexdigest(),
                        "source_sha256": record["source_sha256"],
                    }
                )
    if any(count == 0 for count in counters.values()):
        raise ValueError(f"incomplete relationship digit bank: {counters}")
    manifest_path = ASSETS / "student_basic_manifest.json"
    asset_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    asset_manifest["assets"] = [
        item for item in asset_manifest["assets"] if item.get("purpose") != PURPOSE
    ]
    asset_manifest["assets"].extend(entries)
    manifest_path.write_text(
        json.dumps(asset_manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(counters, sort_keys=True))


if __name__ == "__main__":
    main()

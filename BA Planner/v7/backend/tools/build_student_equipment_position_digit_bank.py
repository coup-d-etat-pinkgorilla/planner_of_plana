from __future__ import annotations

import argparse
import json
from pathlib import Path

from core.recognition_assets import RecognitionAssetCatalog
from core.student_equipment_recognizer import (
    PreparedBinaryGlyph,
    StudentEquipmentRecognizer,
    _normalize_mask,
    _text_mask_variants,
)


def build_bank(assets: Path) -> dict[str, object]:
    recognizer = StudentEquipmentRecognizer(RecognitionAssetCatalog(assets))
    region = recognizer.catalog.region("student")["basic_equipment_1_level_digits_quad"]
    records: list[dict[str, object]] = []
    try:
        cases = [(1, digit, digit) for digit in range(1, 10)]
        cases.extend((2, digit, 10 + digit) for digit in range(10))
        for position, digit, source_value in cases:
            crop = recognizer._generated_text_crop(1, source_value, region)
            if crop is None:
                raise RuntimeError(f"cannot render position {position} digit {digit}")
            cells = recognizer._level_cells(crop, region)
            variants = _text_mask_variants(cells[position - 1])
            normalized = _normalize_mask(variants["fill"])
            prepared = PreparedBinaryGlyph.from_mask(normalized)
            crop.close()
            for cell in cells:
                cell.close()
            for mask in variants.values():
                mask.close()
            if normalized is not None:
                normalized.close()
            if prepared is None:
                raise RuntimeError(f"empty position {position} digit {digit}")
            records.append({
                "position": position,
                "digit": str(digit),
                "source_value": source_value,
                "bits_hex": format(prepared.bits, "x"),
                "ink": prepared.ink,
                "pixels": prepared.pixels,
            })
    finally:
        recognizer.close()
    return {
        "schema_version": 1,
        "purpose": "student basic equipment position digit masks",
        "font_rule": "v6-verified white fill, 1px #505878 outline, shear -0.25",
        "positions": {"1": list("123456789"), "2": list("0123456789")},
        "template_count": len(records),
        "templates": records,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--assets", type=Path, required=True)
    args = parser.parse_args()
    payload = build_bank(args.assets)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

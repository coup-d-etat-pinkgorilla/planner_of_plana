"""Build compact student-card digit templates from labeled screenshots."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.quad_roi import normalize_binary_glyph, otsu_binary, warp_quad_region


SAMPLES = {
    "123903": 66,
    "123836": 55,
    "123820": 44,
    "123812": 33,
    "123749": 22,
    "123738": 21,
    "123804": 30,
    "124014": 90,
    "123951": 70,
    "123945": 69,
    "123933": 67,
    "234206": 11,
    "124003": 88,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=ROOT / "templates" / "basic_student" / "level_digits",
    )
    args = parser.parse_args()

    regions = json.loads((ROOT / "regions" / "student_normal_info_regions.json").read_text(encoding="utf-8"))
    region = regions["basic_level_digits_quad"]
    output_size = tuple(region["output_size"])
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for old_path in args.output_dir.glob("*.png"):
        old_path.unlink()

    written = 0
    for stamp, level in SAMPLES.items():
        matches = list(args.source_dir.glob(f"*2026-03-29 {stamp}.png"))
        if len(matches) != 1:
            raise FileNotFoundError(f"expected one screenshot for {stamp}, found {len(matches)}")
        image = Image.open(matches[0]).convert("RGB")
        warped = warp_quad_region(image, region, output_size=output_size)
        if warped is None:
            raise RuntimeError(f"failed to warp {matches[0]}")
        binary = otsu_binary(warped)
        midpoint = binary.shape[1] // 2
        cells = (binary[:, :midpoint], binary[:, midpoint:])
        digits = str(level)
        if len(digits) != 2:
            raise ValueError(f"template sample must have two digits: {level}")
        for position, (digit, cell) in enumerate(zip(digits, cells), start=1):
            glyph = normalize_binary_glyph(cell)
            if glyph is None:
                raise RuntimeError(f"empty digit crop: {stamp} position {position}")
            Image.fromarray(glyph).save(args.output_dir / f"{digit}_{stamp}_p{position}.png")
            written += 1

    print(f"wrote {written} digit templates to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

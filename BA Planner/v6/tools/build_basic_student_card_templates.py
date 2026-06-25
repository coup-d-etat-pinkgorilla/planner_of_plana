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


SAMPLES = (
    ("2026-06-24", "215302", 1),
    ("2026-06-24", "215255", 12),
    ("2026-06-24", "215250", 23),
    ("2026-06-24", "215246", 34),
    ("2026-06-24", "215240", 45),
    ("2026-06-24", "215238", 56),
    ("2026-06-24", "215236", 67),
    ("2026-06-24", "215234", 78),
    ("2026-06-24", "215230", 89),
    ("2026-06-24", "215227", 90),
)


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
    center_trim = max(0, int(region.get("center_trim_pixels", 0) or 0))
    for date, stamp, level in SAMPLES:
        matches = list(args.source_dir.glob(f"*{date} {stamp}.png"))
        if len(matches) != 1:
            raise FileNotFoundError(f"expected one screenshot for {stamp}, found {len(matches)}")
        image = Image.open(matches[0]).convert("RGB")
        warped = warp_quad_region(image, region, output_size=output_size)
        if warped is None:
            raise RuntimeError(f"failed to warp {matches[0]}")
        binary = otsu_binary(warped)
        midpoint = binary.shape[1] // 2
        trim = min(center_trim, max(0, midpoint - 1))
        cells = (binary[:, :midpoint - trim], binary[:, midpoint + trim:])
        digits = str(level)
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

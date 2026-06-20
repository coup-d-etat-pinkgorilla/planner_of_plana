"""Validate direct level/star recognition against labeled screenshots."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.matcher import read_basic_student_level_result, read_basic_student_star_result
from tools.build_basic_student_card_templates import SAMPLES


STAR_TRUTH = {stamp: (5 if stamp in {"234206", "124003"} else 3) for stamp in SAMPLES}
EXTRA_SAMPLES = {
    "2026-06-20 005803": (1, 2),
    "2026-03-28 224727": (1, 1),
    "2026-06-20 005850": (90, 4),
    "2026-06-20 005843": (90, 3),
    "2026-06-20 005828": (90, 3),
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    args = parser.parse_args()
    regions = json.loads((ROOT / "regions" / "student_normal_info_regions.json").read_text(encoding="utf-8"))

    failures = 0
    for stamp, expected_level in SAMPLES.items():
        path = next(args.source_dir.glob(f"*2026-03-29 {stamp}.png"))
        image = Image.open(path).convert("RGB")
        level = read_basic_student_level_result(image, regions["basic_level_digits_quad"])
        star = read_basic_student_star_result(image, regions["basic_student_stars_quad"])
        expected_star = STAR_TRUTH[stamp]
        ok = level.value == expected_level and star.value == expected_star and not level.uncertain and not star.uncertain
        failures += int(not ok)
        print(
            f"{stamp}: level={level.value}/{expected_level} score={level.score:.3f} "
            f"star={star.value}/{expected_star} score={star.score:.3f} "
            f"uncertain={level.uncertain or star.uncertain} {'OK' if ok else 'FAIL'}"
        )
    for stamp, (expected_level, expected_star) in EXTRA_SAMPLES.items():
        path = next(args.source_dir.glob(f"*{stamp}.png"))
        image = Image.open(path).convert("RGB")
        level = read_basic_student_level_result(image, regions["basic_level_digits_quad"])
        star = read_basic_student_star_result(image, regions["basic_student_stars_quad"])
        ok = level.value == expected_level and star.value == expected_star and not level.uncertain and not star.uncertain
        failures += int(not ok)
        print(
            f"{stamp}: level={level.value}/{expected_level} score={level.score:.3f} "
            f"star={star.value}/{expected_star} score={star.score:.3f} "
            f"uncertain={level.uncertain or star.uncertain} {'OK' if ok else 'FAIL'}"
        )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

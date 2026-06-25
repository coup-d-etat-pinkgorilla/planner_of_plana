"""Build fixed student basic-card attribute label templates from screenshots."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCREENSHOTS = Path.home() / "Pictures" / "Screenshots"
DEFAULT_OUTPUT = ROOT / "templates" / "student_basic_attributes"
REGIONS_PATH = ROOT / "regions" / "student_normal_info_regions.json"

SAMPLES = {
    "attack_type": {
        "explosive": "2026-06-20 170104",
        "piercing": "2026-06-21 161646",
        "mystic": "2026-06-21 161727",
        "sonic": "2026-06-21 161746",
    },
    "defense_type": {
        "light": "2026-06-21 161727",
        "heavy": "2026-06-21 161746",
        "special": "2026-06-21 161646",
        "elastic": "2026-06-21 161717",
        "composite": "2026-06-21 161708",
    },
    "position": {
        "front": "2026-06-21 161646",
        "middle": "2026-06-21 161708",
        "back": "2026-06-21 161746",
    },
    "combat_class": {
        "striker": "2026-06-21 161746",
        "special": "2026-06-21 161727",
    },
    "role": {
        "dealer": "2026-06-21 161746",
        "healer": "2026-06-21 161727",
        "t_s": "2026-06-21 161717",
        "tanker": "2026-06-21 161646",
        "supporter": "2026-06-20 170721",
    },
}


def _find_screenshot(directory: Path, stamp: str) -> Path:
    matches = sorted(directory.glob(f"*{stamp}*.png"))
    if len(matches) != 1:
        raise FileNotFoundError(f"expected one screenshot for {stamp!r}, found {len(matches)}")
    return matches[0]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screenshots-dir", type=Path, default=DEFAULT_SCREENSHOTS)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    regions = json.loads(REGIONS_PATH.read_text(encoding="utf-8-sig"))
    for field, labels in SAMPLES.items():
        region = regions[f"basic_attribute_{field}"]
        target = args.output_dir / field
        target.mkdir(parents=True, exist_ok=True)
        for label, stamp in labels.items():
            path = _find_screenshot(args.screenshots_dir, stamp)
            with Image.open(path) as raw:
                image = raw.convert("RGB")
            w, h = image.size
            box = (
                int(w * region["x1"]), int(h * region["y1"]),
                int(w * region["x2"]), int(h * region["y2"]),
            )
            image.crop(box).save(target / f"{label}.png")
            print(field, label, path.name)


if __name__ == "__main__":
    main()

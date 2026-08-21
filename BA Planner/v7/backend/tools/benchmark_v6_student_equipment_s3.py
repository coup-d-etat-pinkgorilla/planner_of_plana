"""Offline-only benchmark for the accepted v6 generated-RGB equipment path.

Run this file with an isolated interpreter while the current working directory is
the v6 repository root.  It deliberately imports v6 modules only in that process;
it is never part of the v7 runtime.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
from statistics import median
import sys
from time import perf_counter

import cv2
import numpy
from PIL import Image

# This script is launched from the v6 root.  A file launched by absolute path
# otherwise receives only its v7 tools directory on sys.path.
sys.path.insert(0, str(Path.cwd()))

from core.matcher import (
    _BASIC_EQUIPMENT_CARD_X,
    _BASIC_EQUIPMENT_TEXT_X,
    _basic_equipment_generated_digit_templates,
    _basic_equipment_generated_level_crop,
    _basic_equipment_template_card,
    _render_basic_equipment_level_text,
    read_basic_equipment_generated_level_result,
)


def _percentile(values: list[float], percentile: float) -> float:
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, round((len(ordered) - 1) * percentile)))
    return ordered[index]


def _screen(regions: dict, *, slot: int, family: str, tier: int, level: int) -> Image.Image:
    icon_region = regions[f"basic_equipment_{slot}_icon_region"]
    geometry = icon_region.get("template_geometry") or {}
    card = _basic_equipment_template_card(
        family,
        tier,
        background_relpath=str(icon_region.get("template_background") or "icons/temp/square.png"),
        icon_width_ratio=float(geometry.get("icon_width_ratio", 0.995)),
        icon_height_ratio=float(geometry.get("icon_height_ratio", 0.98125)),
        icon_offset_x_ratio=float(geometry.get("icon_offset_x_ratio", 0.0)),
        icon_offset_y_ratio=float(geometry.get("icon_offset_y_ratio", 0.0)),
    )
    if card is None:
        raise RuntimeError("v6 equipment card assets are unavailable")
    card.alpha_composite(
        _render_basic_equipment_level_text(level),
        dest=(_BASIC_EQUIPMENT_TEXT_X[slot] - _BASIC_EQUIPMENT_CARD_X[slot], 6),
    )
    image = Image.new("RGB", (2560, 1440), "black")
    image.paste(card.convert("RGB"), (_BASIC_EQUIPMENT_CARD_X[slot], 1114))
    card.close()
    return image


def benchmark(v6_root: Path, repeats: int) -> dict[str, object]:
    regions = json.loads(
        (v6_root / "regions" / "student_normal_info_regions.json").read_text(encoding="utf-8-sig")
    )
    slot, family, tier, level = 1, "Shoes", 10, 70
    region = regions["basic_equipment_1_level_digits_quad"]
    icon_region = regions["basic_equipment_1_icon_region"]
    image = _screen(regions, slot=slot, family=family, tier=tier, level=level)

    _basic_equipment_generated_level_crop.cache_clear()
    _basic_equipment_generated_digit_templates.cache_clear()
    started = perf_counter()
    cold = read_basic_equipment_generated_level_result(
        image, region, slot, family, f"T{tier}", icon_region
    )
    cold_ms = (perf_counter() - started) * 1000.0
    cold_level_cache = _basic_equipment_generated_level_crop.cache_info()._asdict()
    cold_digit_cache = _basic_equipment_generated_digit_templates.cache_info()._asdict()

    warm_times: list[float] = []
    warm_values: list[int | None] = []
    for _index in range(repeats):
        started = perf_counter()
        result = read_basic_equipment_generated_level_result(
            image, region, slot, family, f"T{tier}", icon_region
        )
        warm_times.append((perf_counter() - started) * 1000.0)
        warm_values.append(result.value if isinstance(result.value, int) else None)
    image.close()

    return {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "implementation": "v6 core.matcher generated RGB/OpenCV",
        "environment": {
            "python": __import__("sys").version.split()[0],
            "opencv": cv2.__version__,
            "numpy": numpy.__version__,
            "pillow": __import__("PIL").__version__,
            "v6_root": str(v6_root.resolve()),
        },
        "case": {"slot": slot, "family": family, "tier": f"T{tier}", "level": level},
        "result": {
            "cold_value": cold.value,
            "cold_uncertain": cold.uncertain,
            "cold_ms": round(cold_ms, 6),
            "warm_p50_ms": round(median(warm_times), 6),
            "warm_p95_ms": round(_percentile(warm_times, 0.95), 6),
            "warm_samples_ms": [round(value, 6) for value in warm_times],
            "all_warm_values": warm_values,
            "correct": cold.value == level and all(value == level for value in warm_values),
        },
        "cold_cache_state": {
            "full_screen_candidate_crops": cold_level_cache,
            "digit_template_bundles": cold_digit_cache,
        },
        "candidate_count": tier * 7,
        "candidate_canvas": [2560, 1440, 3],
        "theoretical_candidate_rgb_bytes": 2560 * 1440 * 3 * tier * 7,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--v6-root", type=Path, default=Path.cwd())
    parser.add_argument("--repeats", type=int, default=20)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = benchmark(args.v6_root, max(1, args.repeats))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

"""Build present detail-fallback composites from the production blue background."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BACKGROUND_SOURCE = ROOT / "debug" / "ChatGPT_background_made.png"
DEFAULT_BACKGROUND_ASSET = ROOT / "templates" / "inventory_detail_backgrounds" / "presents.png"
DEFAULT_ICON_DIR = ROOT / "templates" / "icons" / "presents"
DEFAULT_OUTPUT_DIR = ROOT / "templates" / "inventory_detail" / "presents"
DEFAULT_REGION_CONFIG = DEFAULT_OUTPUT_DIR / "_region.json"


def load_region_config(path: Path = DEFAULT_REGION_CONFIG) -> dict:
    payload = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if not isinstance(payload, dict):
        raise ValueError(f"expected JSON object: {path}")
    return payload


def crop_detail_background(source: Image.Image, config: dict) -> Image.Image:
    """Normalize a full screenshot and crop the configured production detail ROI."""

    window = dict(config.get("window_rect") or {})
    width = int(window.get("width") or 0)
    height = int(window.get("height") or 0)
    if width <= 0 or height <= 0:
        raise ValueError("detail region config is missing a valid window_rect")

    points = list(config.get("points_screen") or [])
    if len(points) < 4:
        raise ValueError("detail region config is missing points_screen")
    xs = [int(point["x"]) for point in points]
    ys = [int(point["y"]) for point in points]
    box = (min(xs), min(ys), max(xs), max(ys))

    normalized = source.convert("RGB").resize(
        (width, height),
        Image.Resampling.LANCZOS,
    )
    background = normalized.crop(box)
    output_size = dict(config.get("output_size") or {})
    expected_size = (
        int(output_size.get("width") or background.width),
        int(output_size.get("height") or background.height),
    )
    if background.size != expected_size:
        background = background.resize(expected_size, Image.Resampling.LANCZOS)
    return background


def compose_present_detail_template(
    background: Image.Image,
    icon: Image.Image,
    config: dict,
) -> Image.Image:
    geometry = dict(config.get("overlay_geometry") or {})
    width = int(geometry.get("width") or 0)
    height = int(geometry.get("height") or 0)
    if width <= 0 or height <= 0:
        raise ValueError("detail region config is missing overlay_geometry")
    overlay = icon.convert("RGBA").resize(
        (width, height),
        Image.Resampling.LANCZOS,
    )
    canvas = background.convert("RGBA")
    canvas.alpha_composite(
        overlay,
        dest=(int(geometry.get("x") or 0), int(geometry.get("y") or 0)),
    )
    return canvas.convert("RGB")


def build_present_detail_templates(
    *,
    background_source: Path | None = None,
    background_asset: Path = DEFAULT_BACKGROUND_ASSET,
    icon_dir: Path = DEFAULT_ICON_DIR,
    output_dir: Path = DEFAULT_OUTPUT_DIR,
    region_config: Path = DEFAULT_REGION_CONFIG,
) -> list[Path]:
    config = load_region_config(region_config)
    if background_source is not None:
        with Image.open(background_source) as source:
            background = crop_detail_background(source, config)
        background_asset.parent.mkdir(parents=True, exist_ok=True)
        background.save(background_asset)
    else:
        with Image.open(background_asset) as source:
            background = source.convert("RGB")
    output_dir.mkdir(parents=True, exist_ok=True)

    icon_paths = sorted(icon_dir.glob("*.png"))
    expected_names = {path.name for path in icon_paths}
    for stale_path in output_dir.glob("*.png"):
        if stale_path.name not in expected_names:
            stale_path.unlink()

    written: list[Path] = []
    for icon_path in icon_paths:
        with Image.open(icon_path) as icon:
            composite = compose_present_detail_template(background, icon, config)
        output_path = output_dir / icon_path.name
        composite.save(output_path)
        written.append(output_path)
    return written


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--background-source",
        type=Path,
        help=(
            "optional full screenshot to recrop; defaults to the committed "
            "templates/inventory_detail_backgrounds/presents.png asset"
        ),
    )
    parser.add_argument("--background-asset", type=Path, default=DEFAULT_BACKGROUND_ASSET)
    parser.add_argument("--icon-dir", type=Path, default=DEFAULT_ICON_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--region-config", type=Path, default=DEFAULT_REGION_CONFIG)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    written = build_present_detail_templates(
        background_source=args.background_source,
        background_asset=args.background_asset,
        icon_dir=args.icon_dir,
        output_dir=args.output_dir,
        region_config=args.region_config,
    )
    print(f"background: {args.background_asset}")
    print(f"templates: {len(written)} -> {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

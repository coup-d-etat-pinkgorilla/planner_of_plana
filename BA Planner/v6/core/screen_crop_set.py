"""Reusable named crops prepared from a captured application screen."""

from __future__ import annotations

from dataclasses import dataclass
import math
from pathlib import Path
from typing import Iterable, Mapping

from PIL import Image

from core.quad_roi import warp_quad_region


@dataclass(frozen=True)
class PreparedScreenRegion:
    """A small source crop plus coordinates local to that crop."""

    name: str
    image: Image.Image
    region: dict
    source_box: tuple[int, int, int, int]
    kind: str

    def output_image(self) -> Image.Image | None:
        """Return the final rect crop or perspective-normalized quad."""
        if self.kind == "quad":
            output_size = tuple(self.region.get("output_size", ())) or None
            return warp_quad_region(self.image, self.region, output_size=output_size)
        return self.image


class ScreenCropSet:
    """Named screen crops that do not retain the full source screenshot.

    Quad entries retain only their small bounding rectangle and local quad
    coordinates. Rect entries retain the final crop. This makes every crop
    independently inspectable and lets later readers reuse it without another
    full-screen conversion.
    """

    def __init__(self, source_size: tuple[int, int], entries: dict[str, PreparedScreenRegion]):
        self.source_size = source_size
        self._entries = entries

    @classmethod
    def from_image(
        cls,
        image: Image.Image,
        regions: Mapping[str, dict],
        *,
        keys: Iterable[str] | None = None,
        quad_border: int = 2,
    ) -> "ScreenCropSet":
        selected = tuple(keys) if keys is not None else tuple(regions)
        entries: dict[str, PreparedScreenRegion] = {}
        width, height = image.size
        for name in selected:
            payload = regions.get(name)
            if not isinstance(payload, dict):
                continue
            prepared = _prepare_region(
                image,
                name,
                payload,
                width=width,
                height=height,
                quad_border=quad_border,
            )
            if prepared is not None:
                entries[name] = prepared
        return cls(image.size, entries)

    def get(self, name: str) -> PreparedScreenRegion | None:
        return self._entries.get(name)

    def names(self) -> tuple[str, ...]:
        return tuple(self._entries)

    def memory_bytes(self) -> int:
        return sum(entry.image.width * entry.image.height * len(entry.image.getbands()) for entry in self._entries.values())

    def save_debug(self, directory: str | Path, *, prefix: str = "") -> list[Path]:
        """Save every final crop so ROI changes can be inspected visually."""
        target = Path(directory)
        target.mkdir(parents=True, exist_ok=True)
        saved: list[Path] = []
        for name, entry in self._entries.items():
            output = entry.output_image()
            if output is None:
                continue
            path = target / f"{prefix}{name}.png"
            output.save(path)
            saved.append(path)
        return saved


def _prepare_region(
    image: Image.Image,
    name: str,
    payload: dict,
    *,
    width: int,
    height: int,
    quad_border: int,
) -> PreparedScreenRegion | None:
    points = payload.get("points_ratio") or []
    if len(points) == 4 and all(
        isinstance(point, dict) and "x" in point and "y" in point
        for point in points
    ):
        pixel_points = [
            (float(point["x"]) * width, float(point["y"]) * height)
            for point in points
        ]
        left = max(0, int(math.floor(min(point[0] for point in pixel_points))) - quad_border)
        top = max(0, int(math.floor(min(point[1] for point in pixel_points))) - quad_border)
        right = min(width, int(math.ceil(max(point[0] for point in pixel_points))) + quad_border + 1)
        bottom = min(height, int(math.ceil(max(point[1] for point in pixel_points))) + quad_border + 1)
        if right <= left or bottom <= top:
            return None
        crop = image.crop((left, top, right, bottom))
        local = dict(payload)
        local["points_ratio"] = [
            {"x": (x - left) / crop.width, "y": (y - top) / crop.height}
            for x, y in pixel_points
        ]
        return PreparedScreenRegion(name, crop, local, (left, top, right, bottom), "quad")

    required = ("x1", "y1", "x2", "y2")
    if all(key in payload for key in required):
        left = max(0, min(width, int(width * float(payload["x1"]))))
        top = max(0, min(height, int(height * float(payload["y1"]))))
        right = max(0, min(width, int(width * float(payload["x2"]))))
        bottom = max(0, min(height, int(height * float(payload["y2"]))))
        if right <= left or bottom <= top:
            return None
        crop = image.crop((left, top, right, bottom))
        local = dict(payload)
        local.update({"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0})
        return PreparedScreenRegion(name, crop, local, (left, top, right, bottom), "rect")
    return None

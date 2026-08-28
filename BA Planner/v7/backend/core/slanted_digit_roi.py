from __future__ import annotations

from dataclasses import dataclass
from math import ceil, floor

from PIL import Image, ImageChops, ImageDraw


@dataclass(slots=True)
class ParallelogramDigitCell:
    """One source-preserving digit cell bounded by two parallel slanted lines."""

    image: Image.Image
    polygon: tuple[tuple[float, float], ...]
    axis_bounds: tuple[float, float]

    def close(self) -> None:
        self.image.close()


def _foreground_points(mask: Image.Image) -> list[tuple[int, int]]:
    source = mask.convert("L")
    try:
        return [
            (x, y)
            for y in range(source.height)
            for x in range(source.width)
            if source.getpixel((x, y)) >= 127
        ]
    finally:
        source.close()


def _valley_cuts(
    projection: dict[int, int],
    lower: float,
    upper: float,
    digit_count: int,
) -> list[float]:
    if digit_count == 1:
        return []
    span = upper - lower
    cell_width = span / digit_count
    cuts: list[float] = []
    for index in range(1, digit_count):
        expected = lower + cell_width * index
        radius = max(2, round(cell_width * 0.42))
        search_left = ceil(expected - radius)
        search_right = floor(expected + radius)
        if cuts:
            search_left = max(search_left, ceil(cuts[-1] + 2))
        search_right = min(
            search_right,
            floor(upper - (digit_count - index) * 2),
        )
        if search_left > search_right:
            cuts.append(expected)
            continue
        cut = min(
            range(search_left, search_right + 1),
            key=lambda value: (
                projection.get(value - 1, 0)
                + projection.get(value, 0)
                + projection.get(value + 1, 0),
                abs(value - expected),
            ),
        )
        cuts.append(float(cut))
    return cuts


def split_parallelogram_digit_cells(
    mask: Image.Image,
    digit_count: int,
    *,
    shear: float,
    padding: int = 1,
) -> tuple[ParallelogramDigitCell, ...]:
    """Split a mask without deskewing or resampling its pixels.

    Segmentation is measured on the slanted axis ``u = x - shear * (y-yc)``.
    Each resulting cell is cut from the original mask between two lines that
    retain the requested shear. The returned bitmap is only masked and cropped;
    no affine transform is applied to the glyph.
    """

    if digit_count not in (1, 2, 3):
        return ()
    source = mask.convert("L")
    points = _foreground_points(source)
    if not points:
        source.close()
        return ()
    y_min = max(0, min(y for _x, y in points) - padding)
    y_max = min(source.height, max(y for _x, y in points) + padding + 1)
    y_center = (y_min + y_max - 1) / 2.0
    axis_values = [x - shear * (y - y_center) for x, y in points]
    lower = min(axis_values) - padding
    upper = max(axis_values) + padding + 1.0
    projection: dict[int, int] = {}
    for value in axis_values:
        key = round(value)
        projection[key] = projection.get(key, 0) + 1
    boundaries = [lower, *_valley_cuts(projection, lower, upper, digit_count), upper]
    result: list[ParallelogramDigitCell] = []
    for left_axis, right_axis in zip(boundaries, boundaries[1:]):
        left_top = left_axis + shear * (y_min - y_center)
        left_bottom = left_axis + shear * (y_max - 1 - y_center)
        right_top = right_axis + shear * (y_min - y_center)
        right_bottom = right_axis + shear * (y_max - 1 - y_center)
        polygon = (
            (left_top, float(y_min)),
            (right_top, float(y_min)),
            (right_bottom, float(y_max - 1)),
            (left_bottom, float(y_max - 1)),
        )
        selector = Image.new("L", source.size)
        ImageDraw.Draw(selector).polygon(polygon, fill=255)
        selected = ImageChops.multiply(source, selector)
        selector.close()
        x_min = max(0, floor(min(point[0] for point in polygon)))
        x_max = min(source.width, ceil(max(point[0] for point in polygon)) + 1)
        cell = selected.crop((x_min, y_min, x_max, y_max))
        selected.close()
        if cell.getbbox() is None:
            cell.close()
            for prior in result:
                prior.close()
            source.close()
            return ()
        result.append(
            ParallelogramDigitCell(
                image=cell,
                polygon=polygon,
                axis_bounds=(left_axis, right_axis),
            )
        )
    source.close()
    return tuple(result)


def draw_parallelogram_boundaries(
    image: Image.Image,
    cells: tuple[ParallelogramDigitCell, ...],
) -> Image.Image:
    """Return an RGB diagnostic overlay; the source image is not modified."""

    result = image.convert("RGB")
    draw = ImageDraw.Draw(result)
    colors = ("#58E6FF", "#FFD166", "#FF7084")
    for index, cell in enumerate(cells):
        points = [(round(x), round(y)) for x, y in cell.polygon]
        draw.line((*points, points[0]), fill=colors[index % len(colors)], width=1)
    return result

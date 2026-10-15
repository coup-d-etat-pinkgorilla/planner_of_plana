"""Field/ROI-specific quality checks for persistent numeric answer masks."""
from PIL import Image

ROI_FIELDS = {
    **{f"studentlevel_digit{i}": "student_level" for i in (1, 2)},
    **{f"weaponlevel_digit{i}": "weapon_level" for i in (1, 2)},
    **{f"equip{s}level_digit{i}": "equipment_level" for s in (1, 2, 3) for i in (1, 2)},
    "affectionlevel_1digit_digit1": "relationship_rank",
    **{f"affectionlevel_digit{i}": "relationship_rank" for i in (1, 2)},
    **{f"affectionlevel_3digit_digit{i}": "relationship_rank" for i in (1, 2, 3)},
}
MIN_HEIGHT_RATIO = {"student_level": .30, "relationship_rank": .35,
                    "weapon_level": .25, "equipment_level": .25}


def numeric_mask_issue(mask: Image.Image, field: str, roi_name: str) -> str | None:
    if ROI_FIELDS.get(roi_name) != field:
        return "unsupported_field_roi"
    binary = mask.convert("L").point(lambda value: 255 if value >= 127 else 0)
    try:
        bbox = binary.getbbox()
        if bbox is None:
            return "empty_mask"
        points = {(x, y) for y in range(binary.height) for x in range(binary.width)
                  if binary.getpixel((x, y))}
        if len(points) < max(8, round(binary.width * binary.height * .02)):
            return "insufficient_ink"
        if bbox[2] - bbox[0] < max(2, round(binary.width * .12)):
            return "fragment_width"
        if bbox[3] - bbox[1] < max(3, round(binary.height * MIN_HEIGHT_RATIO[field])):
            return "fragment_height"
        active, largest = set(points), 0
        while active:
            stack, size = [active.pop()], 0
            while stack:
                x, y = stack.pop()
                size += 1
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        point = (x + dx, y + dy)
                        if point in active:
                            active.remove(point)
                            stack.append(point)
            largest = max(largest, size)
        if largest / len(points) < .8:
            return "fragmented_components"
        return None
    finally:
        binary.close()

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re

from PIL import Image


BACKEND = Path(__file__).resolve().parents[1]
RECOGNITION_ROOT = BACKEND / "assets" / "recognition" / "v1"
TEMPLATE_ROOT = RECOGNITION_ROOT / "templates" / "students"
V6_TEMPLATE_ROOT = BACKEND.parent.parent / "v6" / "templates" / "students"
REGION_PATH = RECOGNITION_ROOT / "regions" / "student_normal_info_regions.json"
MANIFEST_PATH = RECOGNITION_ROOT / "manifest.json"
TOP_BAR_PIXELS = 82
EXPECTED_SOURCE_HEIGHTS = {611, 612}
TARGET_OUTPUT_HEIGHT = 530
STUDENT_TEXTURE_Y1 = 0.0653


def _integrity(path: Path) -> tuple[int, str]:
    content = path.read_bytes()
    return len(content), hashlib.sha256(content).hexdigest()


def _object_span_for_path(text: str, relative: str) -> tuple[int, int]:
    match = re.search(r'"path"\s*:\s*' + re.escape(json.dumps(relative)), text)
    if match is None:
        raise ValueError(f"manifest entry missing: {relative}")
    start = text.rfind("{", 0, match.start())
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(text)):
        character = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            continue
        if character == '"':
            in_string = True
        elif character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return start, index + 1
    raise ValueError(f"unterminated manifest entry: {relative}")


def _replace_field(block: str, field: str, value: object) -> str:
    pattern = rf'("{re.escape(field)}"\s*:\s*)(?:"[^"]*"|\d+)'
    replaced, count = re.subn(
        pattern,
        lambda match: match.group(1) + json.dumps(value, ensure_ascii=False),
        block,
        count=1,
    )
    if count != 1:
        raise ValueError(f"manifest field missing: {field}")
    return replaced


def migrate() -> dict[str, int]:
    regions = json.loads(REGION_PATH.read_text(encoding="utf-8"))
    texture_region = regions.get("student_texture_region")
    if not isinstance(texture_region, dict) or float(texture_region.get("y1", -1)) != STUDENT_TEXTURE_Y1:
        raise ValueError(f"student_texture_region.y1 must be {STUDENT_TEXTURE_Y1}")

    templates = sorted(TEMPLATE_ROOT.glob("*.png"))
    if not templates:
        raise FileNotFoundError(f"student templates not found: {TEMPLATE_ROOT}")

    crop_pixels_by_path: dict[Path, int] = {}
    for path in templates:
        v6_source = V6_TEMPLATE_ROOT / path.name
        if v6_source.is_file():
            with Image.open(v6_source) as source:
                if source.height not in EXPECTED_SOURCE_HEIGHTS:
                    raise ValueError(f"unexpected v6 source height for {path.name}: {source.height}")
                crop_pixels = source.height - TARGET_OUTPUT_HEIGHT
                crop_pixels_by_path[path] = crop_pixels
                with Image.open(path) as current:
                    if current.height == TARGET_OUTPUT_HEIGHT:
                        continue
                cropped = source.crop((0, crop_pixels, source.width, source.height))
                cropped.save(path)
                cropped.close()
            continue

        with Image.open(path) as source:
            if source.height == TARGET_OUTPUT_HEIGHT:
                continue
            if source.height not in EXPECTED_SOURCE_HEIGHTS:
                raise ValueError(f"unexpected source height for {path.name}: {source.height}")
            crop_pixels = source.height - TARGET_OUTPUT_HEIGHT
            crop_pixels_by_path[path] = crop_pixels
            cropped = source.crop((0, crop_pixels, source.width, source.height))
            cropped.save(path)
            cropped.close()

    manifest_text = MANIFEST_PATH.read_text(encoding="utf-8")
    manifest = json.loads(manifest_text)
    student_entries = {
        str(item.get("path")): item
        for item in manifest["assets"]
        if item.get("scan_kind") == "student" and item.get("purpose") == "student-template"
    }
    if len(student_entries) != len(templates):
        raise ValueError(
            f"manifest/template count mismatch: {len(student_entries)} != {len(templates)}"
        )

    replacements: list[tuple[int, int, str]] = []
    for path in templates:
        relative = path.relative_to(RECOGNITION_ROOT).as_posix()
        entry = student_entries.get(relative)
        if entry is None:
            raise ValueError(f"manifest entry missing: {relative}")
        size, digest = _integrity(path)
        start, end = _object_span_for_path(manifest_text, relative)
        block = manifest_text[start:end]
        block = _replace_field(block, "bytes", size)
        block = _replace_field(block, "sha256", digest)
        if "source_path" in entry:
            source_path = str(entry["source_path"])
            if not source_path.startswith("adapted:"):
                source_path = f"adapted:{source_path}"
            crop_pixels = crop_pixels_by_path.get(path, TOP_BAR_PIXELS)
            suffix = f"#top-bar-removed-{crop_pixels}px"
            if re.search(r"#top-bar-removed-\d+px$", source_path):
                source_path = re.sub(r"#top-bar-removed-\d+px$", suffix, source_path)
            else:
                source_path = f"{source_path}{suffix}"
            block = _replace_field(block, "source_path", source_path)
        replacements.append((start, end, block))

    region_relative = "regions/student_normal_info_regions.json"
    region_entry = next(
        item for item in manifest["assets"]
        if item.get("path") == region_relative
    )
    region_size, region_digest = _integrity(REGION_PATH)
    source_path = str(region_entry.get("source_path") or "")
    if not source_path.startswith("adapted:"):
        source_path = f"adapted:{source_path}"
    start, end = _object_span_for_path(manifest_text, region_relative)
    block = manifest_text[start:end]
    block = _replace_field(block, "bytes", region_size)
    block = _replace_field(block, "sha256", region_digest)
    block = _replace_field(block, "source_path", source_path)
    replacements.append((start, end, block))

    for start, end, block in sorted(replacements, reverse=True):
        manifest_text = manifest_text[:start] + block + manifest_text[end:]
    MANIFEST_PATH.write_text(manifest_text, encoding="utf-8")

    output_heights = set()
    for path in templates:
        with Image.open(path) as image:
            output_heights.add(image.height)
    if output_heights != {TARGET_OUTPUT_HEIGHT}:
        raise ValueError(f"unexpected output heights: {sorted(output_heights)}")
    return {"templates": len(templates), "top_bar_pixels": TOP_BAR_PIXELS}


if __name__ == "__main__":
    print(json.dumps(migrate(), sort_keys=True))

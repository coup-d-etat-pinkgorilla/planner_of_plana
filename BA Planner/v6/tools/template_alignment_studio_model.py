"""Project model and renderer for Template Alignment Studio."""

from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass, field
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont


@dataclass
class LayerSpec:
    name: str
    kind: str = "image"
    path: str = ""
    x: int = 0
    y: int = 0
    width: int = 1
    height: int = 1
    opacity: int = 55
    visible: bool = True
    text: str = "Lv.70"
    font_path: str = "C:/Windows/Fonts/arialbd.ttf"
    font_size: int = 32
    text_bold: bool = False
    fill: str = "#FFFFFF"
    stroke_width: int = 0
    stroke_fill: str = "#000000"
    shear: float = 0.0


@dataclass
class RoiSpec:
    name: str = "main"
    x: int = 0
    y: int = 0
    width: int = 128
    height: int = 128
    enabled: bool = True


@dataclass
class StudioProject:
    reference_path: str = ""
    layers: list[LayerSpec] = field(default_factory=list)
    rois: list[RoiSpec] = field(default_factory=lambda: [RoiSpec()])


def _resolve(value: str, base: Path | None = None) -> str:
    if not value:
        return ""
    path = Path(value).expanduser()
    if not path.is_absolute() and base:
        path = base / path
    return str(path.resolve())


def load_project(path: Path) -> StudioProject:
    raw = json.loads(path.read_text(encoding="utf-8"))
    base = path.parent
    layers = []
    for item in raw.get("layers", []):
        data = dict(item)
        # Backward compatibility with the first alignment-tool project format.
        data.setdefault("kind", "image")
        if data.get("path"):
            data["path"] = _resolve(data["path"], base)
        if data.get("font_path"):
            data["font_path"] = _resolve(data["font_path"], base)
        layers.append(LayerSpec(**{k: v for k, v in data.items() if k in LayerSpec.__dataclass_fields__}))
    roi_rows = raw.get("rois")
    if not roi_rows:
        legacy = dict(raw.get("roi", {}))
        legacy.setdefault("name", "main")
        roi_rows = [legacy]
    rois = [RoiSpec(**{k: v for k, v in row.items() if k in RoiSpec.__dataclass_fields__}) for row in roi_rows]
    reference = _resolve(raw.get("reference_path", ""), base)
    return StudioProject(reference, layers, rois or [RoiSpec()])


def save_project(project: StudioProject, path: Path) -> None:
    base = path.parent.resolve()

    def portable(value: str) -> str:
        if not value:
            return ""
        resolved = Path(value).resolve()
        try:
            return str(resolved.relative_to(base))
        except ValueError:
            return str(resolved)

    payload = asdict(project)
    payload["reference_path"] = portable(project.reference_path)
    for row, layer in zip(payload["layers"], project.layers):
        row["path"] = portable(layer.path)
        row["font_path"] = portable(layer.font_path)
    # Keep a legacy primary ROI so older readers can still inspect the project.
    payload["roi"] = asdict(project.rois[0]) if project.rois else asdict(RoiSpec())
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def _bold_font_path(font_path: Path) -> Path:
    if font_path.name.lower() in {"arial.ttf", "arialmt.ttf"}:
        candidate = font_path.with_name("arialbd.ttf")
        if candidate.exists():
            return candidate
    if font_path.name.lower() in {"malgun.ttf", "malgunsl.ttf"}:
        candidate = font_path.with_name("malgunbd.ttf")
        if candidate.exists():
            return candidate
    stem = font_path.stem
    suffixes = ("bd", "b", "bold", "-bold", "_bold")
    candidates = [font_path.with_name(f"{stem}{suffix}{font_path.suffix}") for suffix in suffixes]
    lower_stem = stem.lower()
    if lower_stem.endswith(("regular", "normal")):
        base = stem[: -7] if lower_stem.endswith("regular") else stem[: -6]
        candidates.append(font_path.with_name(f"{base}Bold{font_path.suffix}"))
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return font_path


def _draw_text(draw: ImageDraw.ImageDraw, position: tuple[int, int], layer: LayerSpec, font: ImageFont.ImageFont) -> None:
    fill = ImageColor.getcolor(layer.fill, "RGBA")
    stroke_fill = ImageColor.getcolor(layer.stroke_fill, "RGBA")
    stroke_width = max(0, layer.stroke_width)
    offsets = ((0, 0),)
    if layer.text_bold and Path(layer.font_path) == _bold_font_path(Path(layer.font_path)):
        offsets = ((0, 0), (1, 0))
    for dx, dy in offsets:
        draw.text(
            (position[0] + dx, position[1] + dy),
            layer.text,
            font=font,
            fill=fill,
            stroke_width=stroke_width,
            stroke_fill=stroke_fill,
        )

def render_text_layer(layer: LayerSpec) -> Image.Image:
    width, height = max(1, layer.width), max(1, layer.height)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    font_path = _bold_font_path(Path(layer.font_path)) if layer.text_bold else Path(layer.font_path)
    try:
        font = ImageFont.truetype(str(font_path), max(1, layer.font_size))
    except OSError:
        font = ImageFont.load_default()
    draw = ImageDraw.Draw(canvas)
    _draw_text(draw, (layer.stroke_width + 1, layer.stroke_width + 1), layer, font)
    if layer.shear:
        shift = abs(layer.shear) * height
        expanded = Image.new("RGBA", (width + round(shift), height), (0, 0, 0, 0))
        expanded.alpha_composite(canvas)
        canvas = expanded.transform(
            expanded.size,
            Image.Transform.AFFINE,
            (1, -layer.shear, shift if layer.shear > 0 else 0, 0, 1, 0),
            resample=Image.Resampling.BICUBIC,
        ).crop((0, 0, width, height))
    return canvas


def render_layer(layer: LayerSpec) -> Image.Image:
    if layer.kind == "text":
        image = render_text_layer(layer)
    else:
        image = Image.open(layer.path).convert("RGBA").resize(
            (max(1, layer.width), max(1, layer.height)), Image.Resampling.LANCZOS
        )
    if layer.opacity < 100:
        alpha = image.getchannel("A").point(lambda value: value * layer.opacity // 100)
        image.putalpha(alpha)
    return image


def render_virtual(project: StudioProject, size: tuple[int, int]) -> Image.Image:
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    for layer in project.layers:
        if layer.visible:
            canvas.alpha_composite(render_layer(layer), dest=(layer.x, layer.y))
    return canvas


def _safe_name(value: str) -> str:
    return re.sub(r"[^0-9A-Za-z_.-]+", "_", value).strip("_") or "roi"


def export_project(project: StudioProject, output_dir: Path) -> list[Path]:
    if not project.reference_path:
        raise ValueError("Reference image is not set")
    reference = Image.open(project.reference_path).convert("RGBA")
    virtual = render_virtual(project, reference.size)
    preview = Image.alpha_composite(reference, virtual)
    output_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for roi in project.rois:
        if not roi.enabled:
            continue
        name = _safe_name(roi.name)
        box = (roi.x, roi.y, roi.x + roi.width, roi.y + roi.height)
        for prefix, image in (
            ("reference", reference), ("virtual_template", virtual),
            ("overlay_preview", preview),
        ):
            target = output_dir / f"{name}_{prefix}.png"
            image.crop(box).save(target)
            paths.append(target)
    full = output_dir / "virtual_template_full.png"
    virtual.save(full)
    paths.append(full)
    metadata = output_dir / "alignment.json"
    metadata.write_text(json.dumps(asdict(project), ensure_ascii=False, indent=2), encoding="utf-8")
    paths.append(metadata)
    return paths

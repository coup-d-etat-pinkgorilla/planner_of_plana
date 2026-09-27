"""C5e-6a: synthetic recognition templates from the locally extracted assets (D19, D24, D25).

Grid tiles and detail icons are composed once at the 1080p-equivalent UI scale and stored at one
normalized size (tiles 96x96, detail icons 128x128); a real crop is resized to the same size before M4
matching, so no per-resolution set is kept (D25, E8). Count glyphs depend on the window and are rendered
on demand. The generator is a pure function of its inputs: the same asset cache, rarity snapshot, spec
version and parameters give byte-identical images.

Geometry (spec ``ba-ui-template-spec-v1.json``, template-generation-spec section 3):
item tile = Card_Item_Bg_<rarity> 265x217 units + icon 253x200 units x 1.06 at (+3.5, +1.2) units;
the planner slot crop is the card's left+2 / top+2, 98x91 px at 720p.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import hashlib
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

SPEC_VERSION = "1.0.0"
GENERATOR_VERSION = 1
DESIGN = (2960, 1440)
RARITIES = ("N", "R", "SR", "SSR")
TILE_SIZE = (96, 96)
DETAIL_SIZE = (128, 128)
# Item tile (UINonEquipmentCard), design units.
CARD = (265, 217)
ICON = (253, 200)
ICON_SCALE, ICON_OFFSET = 1.06, (3.5, 1.2)
# Equipment tile (UIEquipmentCard): blueprint background at (0, -2), icon 257x203. Blueprint tiles show the
# *_Piece icon (D18). Fit on 79 live 1280 tiles (C5e-6a): scale 1.06, (+2, 0) units, alpha 1.0 (the prefab's
# .8-.867 alpha fits worse) -> 79/79 top-1, true M4 median .935. Stones and weapon growth use item cards.
EQUIPMENT_ICON = (257, 203)
EQUIPMENT_BG_OFFSET = (0.0, 2.0)  # NGUI y up: -2 units is 2 units lower on screen
EQUIPMENT_FIT = dict(scale=1.06, offset=(2.0, 0.0), alpha=1.0)
ITEM_CARD_EQUIPMENT = ("Exp", "WeaponExpGrowthZ", "WeaponExpGrowthC", "WeaponExpGrowthB", "WeaponExpGrowthA")
# Item detail panel: big icon 551x435 units centred at (-717, 261) over the panel; planner ROI (ratios of the
# window). Fit on 101 live detail crops: prefab scale over a flat panel colour -> 101/101, true M4 median .995.
DETAIL_ICON = (551, 435)
DETAIL_CENTRE = (-717.0, 261.0)
DETAIL_ROI = (0.203516, 0.238194, 0.310937, 0.440972)
DETAIL_BG = (181, 227, 244)
GUTTER = (204, 204, 204)
# Planner slot crop at 720p: card left+2 / top+2, 98x91 px (template-generation-spec 3.1).
SLOT_CROP_720 = (2, 2, 98, 91)
S_720 = 720 / 1665
S_NORMAL = 1080 / 1665  # 1080p-equivalent scale for the normalized set (D25)
# Count label (E5): Gyeonggi Bold, shear .10, stroke dilation .5 px at 720p, ink #2D4664.
GLYPHS = "x0123456789K"
GLYPH_INK = (45, 70, 99)
GLYPH_SHEAR = 0.10


class SynthUnavailable(Exception):
    """The synthetic tier cannot be built (missing or inconsistent inputs); callers disable it."""

    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


def ui_scale(width: int, height: int) -> float:
    """NGUI UIRoot Constrained scale: s = H / active height (16:9 and 4:3 alike)."""
    aspect = width / height
    active = round(DESIGN[0] / aspect) if aspect < DESIGN[0] / DESIGN[1] else DESIGN[1]
    return height / active


@dataclass
class SynthTemplateSet:
    profile: str
    tiles: dict[str, Image.Image] = field(default_factory=dict)
    details: dict[str, Image.Image] = field(default_factory=dict)
    glyphs: dict[int, dict[str, Image.Image]] = field(default_factory=dict)
    fingerprint: str = ""

    def close(self) -> None:
        for image in [*self.tiles.values(), *self.details.values(), *(g for size in self.glyphs.values() for g in size.values())]:
            image.close()


def _scaled(image: Image.Image, size: tuple[float, float]) -> Image.Image:
    return image.resize((max(1, round(size[0])), max(1, round(size[1]))), Image.Resampling.LANCZOS)


def compose_item_tile(icon: Image.Image, card_bg: Image.Image, s: float) -> Image.Image:
    """Card background + icon on the gutter colour, canvas = card box + 1 px margin (E4 synth_tile)."""
    card_w, card_h = CARD[0] * s, CARD[1] * s
    canvas = Image.new("RGBA", (round(card_w) + 2, round(card_h) + 2), GUTTER + (255,))
    with _scaled(card_bg.convert("RGBA"), (card_w, card_h)) as bg:
        canvas.alpha_composite(bg, (1, 1))
    icon_w, icon_h = ICON[0] * s * ICON_SCALE, ICON[1] * s * ICON_SCALE
    with _scaled(icon.convert("RGBA"), (icon_w, icon_h)) as scaled:
        x = round(1 + card_w / 2 - icon_w / 2 + ICON_OFFSET[0] * s)
        y = round(1 + card_h / 2 - icon_h / 2 + ICON_OFFSET[1] * s)
        canvas.alpha_composite(scaled, (x, y))
    return canvas.convert("RGB")


def compose_equipment_tile(icon: Image.Image, blueprint_bg: Image.Image, s: float, *, alpha: float = EQUIPMENT_FIT["alpha"],
                           scale: float = EQUIPMENT_FIT["scale"], offset: tuple[float, float] = EQUIPMENT_FIT["offset"]) -> Image.Image:
    """Blueprint background (2 units low) + equipment icon at partial alpha (spec 3.2)."""
    card_w, card_h = CARD[0] * s, CARD[1] * s
    canvas = Image.new("RGBA", (round(card_w) + 2, round(card_h) + 2), GUTTER + (255,))
    with _scaled(blueprint_bg.convert("RGBA"), (card_w, card_h)) as bg:
        canvas.alpha_composite(bg, (1, 1 + round(EQUIPMENT_BG_OFFSET[1] * s)))
    icon_w, icon_h = EQUIPMENT_ICON[0] * s * scale, EQUIPMENT_ICON[1] * s * scale
    with _scaled(icon.convert("RGBA"), (icon_w, icon_h)) as scaled:
        faded = scaled.copy()
        faded.putalpha(scaled.getchannel("A").point(lambda value: round(value * alpha)))
        x = round(1 + card_w / 2 - icon_w / 2 + offset[0] * s)
        y = round(1 + card_h / 2 - icon_h / 2 + offset[1] * s)
        canvas.alpha_composite(faded, (x, y))
        faded.close()
    return canvas.convert("RGB")


def slot_crop(tile: Image.Image, s: float) -> Image.Image:
    """The planner's slot window on a composed tile (crop_like_dataset), scaled from 720p."""
    k = s / S_720
    x, y, w, h = SLOT_CROP_720
    return tile.crop((1 + round(x * k), 1 + round(y * k), 1 + round((x + w) * k), 1 + round((y + h) * k)))


def compose_detail_icon(icon: Image.Image, window: tuple[int, int]) -> Image.Image:
    """The planner's detail ROI of the item detail panel: the big icon over the panel colour (spec 3.3)."""
    width, height = window
    s = ui_scale(width, height)
    x1, y1 = round(DETAIL_ROI[0] * width), round(DETAIL_ROI[1] * height)
    x2, y2 = round(DETAIL_ROI[2] * width), round(DETAIL_ROI[3] * height)
    canvas = Image.new("RGBA", (x2 - x1, y2 - y1), DETAIL_BG + (255,))
    icon_w, icon_h = DETAIL_ICON[0] * s, DETAIL_ICON[1] * s
    centre_x, centre_y = width / 2 + DETAIL_CENTRE[0] * s, height / 2 - DETAIL_CENTRE[1] * s
    with _scaled(icon.convert("RGBA"), (icon_w, icon_h)) as scaled:
        canvas.alpha_composite(scaled, (round(centre_x - icon_w / 2) - x1, round(centre_y - icon_h / 2) - y1))
    return canvas.convert("RGB")


def normalize_detail(crop: Image.Image) -> Image.Image:
    return crop.convert("RGB").resize(DETAIL_SIZE, Image.Resampling.BILINEAR)


def normalize_tile(crop: Image.Image) -> Image.Image:
    """Real slot crops and synthetic tiles meet at one size (D25)."""
    return crop.convert("RGB").resize(TILE_SIZE, Image.Resampling.BILINEAR)


def profile_universe(profile: str, rarity: dict[str, Any]) -> list[str]:
    """Candidate identities of a scan profile: its filter category in the snapshot (D23 (2)), so items newer
    than the planner catalog are included; blueprint *_Piece rows fold into their equipment identity."""
    from core.inventory_catalog import CATALOG
    catalog = {row.item_id for row in CATALOG if row.profile_id == profile}
    if profile == "equipment":
        table = rarity.get("equipment", {})
        universe = {identity for identity in table if not identity.endswith("_Piece")}
    else:
        table = rarity.get("items", {})
        if profile == "presents":
            universe = {identity for identity, row in table.items() if row.get("category") == "Favor"}
        elif profile == "tech_notes":
            universe = {identity for identity in table if identity.startswith("Item_Icon_SkillBook_")}
        else:
            universe = set(table)
    # Catalog members outside the category (e.g. present selection boxes) stay candidates too.
    return sorted(universe | {identity for identity in catalog if identity in table})


def _input_fingerprint(parts: list[str]) -> str:
    return hashlib.sha256("\n".join(parts).encode()).hexdigest()


def synthesize(cache: Any, rarity: dict[str, Any], *, profile: str, identities=None, window: tuple[int, int] = (1280, 720),
               glyph_sizes: tuple[int, ...] | None = None) -> SynthTemplateSet:
    """Build the synthetic set for identities (default: the profile's filter category, ``profile_universe``).

    ``cache`` is a C5e-6a-0 ``AssetCache``. Items use their snapshot rarity for the card; equipment uses the
    blueprint background. Missing inputs raise ``SynthUnavailable``.
    """
    manifest = getattr(cache, "manifest", None)
    if not manifest:
        raise SynthUnavailable("no extracted asset cache")
    equipment = profile == "equipment"
    table = rarity.get("equipment" if equipment else "items", {})
    wanted = list(identities) if identities is not None else profile_universe(profile, rarity)
    sprite_names = [f"Card_Item_Bg_{name}" for name in RARITIES] + (["Card_Item_Bg_C"] if equipment else [])
    sprites = {}
    for name in sprite_names:
        path = cache.sprite(name)
        if path is None or not Path(path).is_file():
            raise SynthUnavailable(f"sprite {name} is missing")
        sprites[name] = Image.open(path).convert("RGBA")
    result = SynthTemplateSet(profile)
    parts = [f"generator={GENERATOR_VERSION}", f"spec={SPEC_VERSION}", f"profile={profile}",
             *(f"{name}={manifest['sprites'][name].get('pixel_sha256')}" for name in sprite_names)]
    try:
        for identity in wanted:
            row = table.get(identity)
            blueprint = equipment and row is not None and row.get("category") not in ITEM_CARD_EQUIPMENT
            # A blueprint tile shows the *_Piece icon (D18); the planner identity stays the equipment name.
            icon_name = identity + "_Piece" if blueprint and identity + "_Piece" in manifest["icons"] else identity
            entry = manifest["icons"].get(icon_name)
            if entry is None or row is None:
                raise SynthUnavailable(f"icon or rarity for {identity} is missing")
            with Image.open(cache.icon(icon_name)) as icon:
                if blueprint:
                    tile = compose_equipment_tile(icon, sprites["Card_Item_Bg_C"], S_NORMAL)
                else:
                    tile = compose_item_tile(icon, sprites[f"Card_Item_Bg_{row['rarity']}"], S_NORMAL)
                if not equipment:
                    with compose_detail_icon(icon, (1920, 1080)) as detail:
                        result.details[identity] = normalize_detail(detail)
            with tile, slot_crop(tile, S_NORMAL) as crop:
                result.tiles[identity] = normalize_tile(crop)
            parts.append(f"{identity}={icon_name}:{entry.get('pixel_sha256')}:{row.get('rarity')}")
        font = cache.font("GyeonggiTitle-Bold")
        sizes = glyph_sizes if glyph_sizes is not None else glyph_em_candidates(window)
        if sizes:
            if font is None or not Path(font).is_file():
                raise SynthUnavailable("count font is missing")
            for size in sizes:
                result.glyphs[size] = render_glyphs(Path(font), size, ui_scale(*window))
            parts += [f"font={manifest['fonts']['GyeonggiTitle-Bold']['sha256']}", f"glyphs={sizes}"]
    except SynthUnavailable:
        result.close()
        raise
    finally:
        for sprite in sprites.values():
            sprite.close()
    result.fingerprint = _input_fingerprint(parts)
    return result


def glyph_em_candidates(window: tuple[int, int]) -> tuple[int, int, int]:
    """Count label em in px: round(44 s) + 1 with +-1 candidates (E5: 20 px at 720p)."""
    em = round(44 * ui_scale(*window)) + 1
    return (em - 1, em, em + 1)


def render_glyphs(font_path: Path, em: int, s: float, *, supersample: int = 4) -> dict[str, Image.Image]:
    """Count-label glyphs x0-9K as ink masks (L, 255 = ink): Gyeonggi Bold, sheared italic, dilated (E5)."""
    font = ImageFont.truetype(str(font_path), em * supersample)
    dilate = 0.5 * s / S_720 * supersample
    glyphs = {}
    for char in GLYPHS:
        box = font.getbbox(char)
        width, height = box[2] - box[0], box[3] - box[1]
        pad = supersample * 4 + round(height * GLYPH_SHEAR)
        canvas = Image.new("L", (width + 2 * pad, height + 2 * pad), 0)
        ImageDraw.Draw(canvas).text((pad - box[0], pad - box[1]), char, font=font, fill=255)
        # Unity's synthetic italic: shear x by y around the baseline (top leans right).
        sheared = canvas.transform(canvas.size, Image.Transform.AFFINE,
                                   (1, GLYPH_SHEAR, -GLYPH_SHEAR * (pad + height), 0, 1, 0), Image.Resampling.BILINEAR)
        canvas.close()
        radius = round(dilate)
        if radius:
            thick = sheared.filter(ImageFilter.MaxFilter(2 * radius + 1))
            sheared.close()
            sheared = thick
        # Composite the label colour over the light tile background and read it back through the same ink
        # map as a real crop, so edge softness matches (E5: ink map of a rendered string, not the raw mask).
        colour = Image.new("RGB", sheared.size, GLYPH_INK)
        rendered = Image.new("RGB", sheared.size, (232, 232, 232))
        rendered.paste(colour, (0, 0), sheared)
        small = rendered.resize((max(1, sheared.width // supersample), max(1, sheared.height // supersample)), Image.Resampling.BOX)
        for image in (sheared, colour, rendered):
            image.close()
        ink = ink_map(small)
        small.close()
        bbox = ink.point(lambda value: 255 if value > 51 else 0).getbbox()
        glyphs[char] = ink.crop(bbox) if bbox else ink
        if bbox:
            ink.close()
    return glyphs


def ink_map(image: Image.Image) -> Image.Image:
    """Real count-label ink as L (255 = ink colour), for comparing against rendered glyphs."""
    rgb = image.convert("RGB")
    r, g, b = rgb.split()
    distance = ImageChops.add(ImageChops.add(ImageChops.difference(r, Image.new("L", r.size, GLYPH_INK[0])),
                                             ImageChops.difference(g, Image.new("L", g.size, GLYPH_INK[1]))),
                              ImageChops.difference(b, Image.new("L", b.size, GLYPH_INK[2])))
    return distance.point(lambda value: max(0, 255 - value * 255 // 90))

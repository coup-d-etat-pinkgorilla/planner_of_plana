"""F7 control observations and bounded equipment-only retry policy."""
from PIL import Image, ImageStat

from core.student_scan_recognizer import Observation, ratio_crop
from core.student_weapon_recognizer import _normalized_correlation, _color_similarity
from core.student_panel_recovery import read_panel_fields
from core import recognition_thresholds as rt


class EquipmentControlRecognizer:
    def __init__(self, catalog):
        self.catalog = catalog
        self.regions = catalog.region_for_purpose('student', 'student-equipment-menu-regions')
        self.templates = {}

    def _read(self, crop, labels, source, *, shape_weight=.7):
        if crop is None:
            return Observation(None, 0, 'region_missing', source, 'crop missing')
        if not self.templates:
            for asset in self.catalog.assets('student', 'student-equipment-control-template'):
                with Image.open(self.catalog.resolve(asset.path)) as image:
                    self.templates[asset.identity] = image.convert('RGB')
        with crop.convert('L') as gray:
            signal = ImageStat.Stat(gray).stddev[0] >= 8
        scores = sorted(((value, shape_weight*_normalized_correlation(crop, self.templates[label])
            + (1-shape_weight)*_color_similarity(crop, self.templates[label]))
            for label, value in labels.items() if label in self.templates), key=lambda pair: pair[1], reverse=True)
        if len(scores) != 2:
            return Observation(None, 0, 'uncertain', source, 'templates missing')
        (value, score), (_, second) = scores
        margin = score-second
        ok = signal and score >= rt.value("student.equipment.show_all.score") and margin >= rt.value("student.equipment.show_all.margin")
        return Observation(value if ok else None, score, 'ok' if ok else 'uncertain', source, f'margin={margin:.6f}')

    def read_check(self, frame):
        with ratio_crop(frame, self.regions['equipment_all_view_check_region']) as crop:
            return self._read(crop, {'true': True, 'false': False}, 'equipment_show_all_template')

    def read_growth(self, crop):
        # The same text is drawn in both states; background color carries the state.
        return self._read(crop, {'possible': True, 'impossible': False}, 'equipment_growth_template', shape_weight=.2)

    def close(self):
        for image in self.templates.values(): image.close()
        self.templates.clear()


def favorite_dot_state(crop, present):
    """Require the card's rounded upper-right corner to positively observe absence."""
    if crop is None or crop.width < 8 or crop.height < 8:
        return None
    if present(crop):
        return True
    with crop.convert('RGB') as rgb:
        pixels = list(rgb.getdata())
        # A partially visible dot is unknown even below the full-dot detector floor.
        orange = sum(r > 230 and 145 < g < 220 and b < 100 for r,g,b in pixels)
        if orange >= 3:
            return None
        background = [rgb.getpixel((x,y)) for y in range(rgb.height) for x in range(rgb.width)
                      if y < rgb.height*.15 or x >= rgb.width*.85]
        card = [rgb.getpixel((x,y)) for y in range(rgb.height) for x in range(rgb.width)
                if x < rgb.width*.40 and rgb.height*.55 <= y < rgb.height*.95]
    light = sum(min(p) >= 235 and max(p)-min(p) <= 25 for p in background)/len(background)
    neutral_card = sum(70 <= min(p) and max(p) <= 215 and max(p)-min(p) <= 40 for p in card)/len(card)
    # Uniform white/gray/black and arbitrary texture do not establish the corner.
    card_spread = max(max(p[i] for p in card)-min(p[i] for p in card) for i in range(3))
    return False if light >= rt.value("student.equipment.growth_off.light") and neutral_card >= rt.value("student.equipment.growth_off.neutral_card") and card_spread <= 35 else None


def resolve_equipment_menu(menu, reader, target, cancel, initial, slots):
    slots = tuple(dict.fromkeys(slots))
    fields = tuple(field for slot in slots for field in
                   ((f'equip{slot}', f'equip{slot}_level') if slot <= 3 else ('equip4',)))
    normal = tuple(f'equip{slot}' for slot in slots if slot <= 3)
    def retry(merged):
        return bool(normal) and all(not merged.get(field) or
            (not merged[field].confirmed and merged[field].source != 'panel_value_conflict') for field in normal)
    result = read_panel_fields(menu, 'equipment', target, cancel, initial, fields,
        lambda frame: reader.recognize(frame, slots), attempts=2, retry_if=retry)
    def resolved(field):
        value = result.get(field)
        if value is None: return False
        if value.confirmed: return True
        tier = result.get(field.removesuffix('_level'))
        return (field.endswith('_level') and value.status == 'skipped' and tier is not None
                and tier.confirmed and tier.value in {'empty', 'level_locked', 'love_locked'})
    panel = result.get('equipment_panel')
    if (panel is not None and panel.note == 'fields unresolved after bounded reads'
            and all(resolved(field) for field in fields)):
        result.pop('equipment_panel')
    return result

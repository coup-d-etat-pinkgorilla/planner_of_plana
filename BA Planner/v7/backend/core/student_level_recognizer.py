"""Dedicated level-tab fallback; no basic screenshot or profile value is a template."""
from PIL import Image, ImageStat

from core.planning import MAX_TARGET_LEVEL
from core.student_scan_recognizer import Observation, ratio_crop, _mask_from_predicate, _normalize_mask, _rank_glyph
from core.student_panel_recovery import read_panel_fields
from core import recognition_thresholds as rt


def _ink(image):
    return _mask_from_predicate(image, lambda p: max(p) < 170 and max(p)-min(p) < 80)


class StudentLevelRecognizer:
    def __init__(self, catalog):
        self.catalog = catalog
        self.regions = catalog.region_for_purpose("student", "student-level-regions")
        self.templates = {}

    def _bank(self, position):
        if position in self.templates:
            return self.templates[position]
        bank = {}
        for asset in self.catalog.assets("student", "student-level-template"):
            pos, label = asset.identity.split(":")
            if int(pos) != position:
                continue
            with Image.open(self.catalog.resolve(asset.path)) as source:
                half = source.resize((max(1,round(source.width/2)),max(1,round(source.height/2))),Image.Resampling.LANCZOS)
                glyphs = []
                try:
                    for image in (source,half):
                        mask = _ink(image)
                        try: glyph = _normalize_mask(mask)
                        finally: mask.close()
                        if glyph is not None: glyphs.append(glyph)
                finally:
                    half.close()
            bank[label] = tuple(glyphs)
        self.templates[position] = bank
        return bank

    def read_digit(self, crop, position):
        mask = _ink(crop)
        gray = crop.convert("L")
        try:
            stats = ImageStat.Stat(gray)
            occupancy = sum(v >= 127 for v in mask.getdata())/max(1,mask.width*mask.height)
            # A failed second digit is never interpreted as a one-digit level.
            # Only the bright, uniform unused cell explicitly ends the number.
            if position == 2 and occupancy <= rt.value("student.level.blank_occupancy") and stats.mean[0] >= 210 and stats.stddev[0] <= 12:
                return Observation("blank",1,"ok","level_tab_blank",f"ink={occupancy:.6f}")
            if not rt.value("student.level.glyph_occupancy.min") <= occupancy <= rt.value("student.level.glyph_occupancy.max") or stats.stddev[0] < 12 or stats.mean[0] < 80:
                return Observation(None,0,"uncertain","level_tab_digit",f"invalid UI signal;ink={occupancy:.6f}")
            glyph = _normalize_mask(mask)
            try: label,score,margin = _rank_glyph(glyph,self._bank(position))
            finally:
                if glyph is not None: glyph.close()
            confirmed = label is not None and score >= rt.value("student.level.tab.score") and margin >= rt.value("student.level.tab.margin")
            return Observation(label if confirmed else None,score,"ok" if confirmed else "uncertain",
                               "level_tab_digit",f"label={label};margin={margin:.6f};ink={occupancy:.6f}")
        finally:
            mask.close();gray.close()

    def recognize_menu(self, frame):
        digits = []
        for position in (1,2):
            crop = ratio_crop(frame,self.regions[f"level_digit_{position}"])
            try: digits.append(self.read_digit(crop,position))
            finally: crop.close()
        value = None
        if all(d.confirmed for d in digits):
            text = str(digits[0].value)+(str(digits[1].value) if digits[1].value != "blank" else "")
            if text.isdigit() and 1 <= int(text) <= MAX_TARGET_LEVEL:
                value = int(text)
        return {"level":Observation(value,min(d.confidence for d in digits),"ok" if value is not None else "uncertain",
                                    "level_tab_template",";".join(f"d{i+1}:{d.note}" for i,d in enumerate(digits)))}

    def resolve(self, observations, menu, target, cancel):
        previous = observations.get("level")
        if previous is not None and (previous.confirmed or previous.source == "panel_value_conflict"):
            return {"level":previous}
        if menu is None:
            return {"level":previous} if previous is not None else {}
        return read_panel_fields(menu,"level",target,cancel,observations,("level",),self.recognize_menu,attempts=3)

    def close(self):
        for bank in self.templates.values():
            for variants in bank.values():
                for image in variants: image.close()
        self.templates.clear()

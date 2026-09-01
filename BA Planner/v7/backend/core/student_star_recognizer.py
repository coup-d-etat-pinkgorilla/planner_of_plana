"""Student stars from independent weapon flags or the verified star tab."""
from PIL import Image, ImageStat

from core.student_scan_recognizer import Observation, ratio_crop
from core.student_panel_recovery import merge_observation, read_panel_fields
from core.student_weapon_recognizer import StudentWeaponRecognizer


class StudentStarRecognizer:
    UNLOCKED_STATES = {"weapon_equipped", "weapon_unlocked_not_equipped"}

    def __init__(self, catalog):
        self.catalog = catalog
        self.regions = catalog.region_for_purpose("student", "student-star-regions")
        self.templates = None

    def _bank(self):
        if self.templates is None:
            self.templates = {}
            for asset in self.catalog.assets("student", "student-star-template"):
                with Image.open(self.catalog.resolve(asset.path)) as source:
                    self.templates[asset.identity] = source.convert("RGB")
        return self.templates

    def recognize_menu(self, frame):
        crop = ratio_crop(frame, self.regions["student_star_region"])
        try:
            with crop.convert("L") as gray:
                signal = ImageStat.Stat(gray)
            label, score, margin = StudentWeaponRecognizer._rank(crop, self._bank())
            confirmed = (label in {"1", "2", "3", "4", "5"} and score >= .60 and margin >= .035
                         and signal.mean[0] >= 80 and signal.stddev[0] >= 12)
            return {"student_star": Observation(int(label) if confirmed else None, score,
                    "ok" if confirmed else "uncertain", "star_tab_template",
                    f"label={label};margin={margin:.6f}")}
        finally:
            crop.close()

    def resolve(self, observations, independent_weapon, menu, target, cancel):
        previous = observations.get("student_star")
        if previous is not None and previous.source == "panel_value_conflict":
            return {"student_star": previous}
        # Only a direct flag observation qualifies. Never consume a star-derived gate
        # or inferred weapon level/star values, even if their values look plausible.
        if (independent_weapon is not None and independent_weapon.status == "ok"
                and independent_weapon.source == "basic_weapon_state_template"
                and independent_weapon.value in self.UNLOCKED_STATES):
            inferred = Observation(5, independent_weapon.confidence, "inferred",
                                   "independent_weapon_flag", f"weapon_state={independent_weapon.value}")
            return {"student_star": merge_observation(previous, inferred)}
        if previous is not None and previous.confirmed:
            return {"student_star": previous}
        if menu is None:
            return {"student_star": previous} if previous is not None else {}
        return read_panel_fields(menu, "star", target, cancel, observations, ("student_star",),
                                 self.recognize_menu, attempts=1)

    def close(self):
        for image in (self.templates or {}).values():
            image.close()
        self.templates = None

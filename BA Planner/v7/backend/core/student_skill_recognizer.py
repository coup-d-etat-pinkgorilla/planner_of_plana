"""F6 skill observation, independent show-all state and star unlock gates."""
from PIL import Image, ImageStat

from core.student_scan_recognizer import (
    Observation, ratio_crop, _skill_ui_feature, _skill_text_feature, _ncc_difference_score,
)
from core.student_weapon_recognizer import StudentWeaponRecognizer
from core.student_panel_recovery import read_panel_fields

SKILL_REGIONS = {"ex_skill":"EX_skill", "skill1":"Skill_1", "skill2":"Skill_2", "skill3":"Skill_3"}
SKILL_UNLOCKS = {"skill2":2, "skill3":3}


class StudentSkillRecognizer:
    def __init__(self, catalog):
        self.catalog = catalog
        self.regions = catalog.region_for_purpose("student","student-skill-regions")
        self.templates = {}
        self.check_templates = None

    def read_check(self, frame):
        if self.check_templates is None:
            self.check_templates = {}
            for asset in self.catalog.assets("student","student-skill-check-template"):
                with Image.open(self.catalog.resolve(asset.path)) as source:
                    self.check_templates[asset.identity] = source.convert("RGB")
        with ratio_crop(frame,self.regions["skill_all_view_check_region"]) as crop:
            with crop.convert("L") as gray:
                signal = ImageStat.Stat(gray)
            label,score,margin = StudentWeaponRecognizer._rank(crop,self.check_templates)
            ok = label in {"true","false"} and score >= .75 and margin >= .10 and signal.stddev[0] >= 8
            return Observation(label == "true" if ok else None,score,"ok" if ok else "uncertain",
                               "skill_show_all_template",f"label={label};margin={margin:.6f}")

    def _bank(self, field):
        if field not in self.templates:
            bank = {}
            for asset in self.catalog.assets("student","student-skill-template"):
                group,label = asset.identity.split(":")
                if group != field: continue
                with Image.open(self.catalog.resolve(asset.path)) as source:
                    region = self.regions[SKILL_REGIONS[field]]
                    sizes = {source.size}
                    for width,height in ((1280,720),(2560,1440)):
                        sizes.add((round(region['x2']*width)-round(region['x1']*width),
                                   round(region['y2']*height)-round(region['y1']*height)))
                    variants = []
                    for size in sorted(sizes):
                        with source.resize(size,Image.Resampling.LANCZOS) as scaled:
                            variants.append((size,_skill_ui_feature(scaled,size),_skill_text_feature(scaled,size)))
                    bank[label] = variants
            self.templates[field] = bank
        return self.templates[field]

    def read_value(self, crop, field):
        with crop.convert("L") as gray:
            signal = ImageStat.Stat(gray)
        if signal.mean[0] < 70 or signal.stddev[0] < 12:
            return Observation(None,0,"uncertain","skill_menu_template","insufficient UI signal")
        features = {}
        ranked = []
        try:
            for label,variants in self._bank(field).items():
                scores = []
                for size,ui,text in variants:
                    if size not in features:
                        features[size] = (_skill_ui_feature(crop,size),_skill_text_feature(crop,size))
                    current_ui,current_text = features[size]
                    scores.append(.15*_ncc_difference_score(current_ui,ui)+.85*_ncc_difference_score(current_text,text))
                ranked.append((max(scores),label))
        finally:
            for ui,text in features.values(): ui.close();text.close()
        ranked.sort(reverse=True)
        score,label = ranked[0] if ranked else (0,None)
        margin = score-ranked[1][0] if len(ranked)>1 else score
        ok = label is not None and label.isdigit() and score >= .70 and margin >= .035
        return Observation(int(label) if ok else None,score,"ok" if ok else "uncertain",
                           "skill_menu_template",f"field={field};label={label};margin={margin:.6f}")

    def recognize_menu(self, frame, fields=None):
        fields = tuple(SKILL_REGIONS) if fields is None else fields
        check = self.read_check(frame)
        if not check.confirmed or check.value is not True:
            return {field:Observation(None,check.confidence,"dependency_missing","skill_show_all_template",
                                      "show-all not positively checked") for field in fields}
        result = {}
        for field in fields:
            with ratio_crop(frame,self.regions[SKILL_REGIONS[field]]) as crop:
                result[field] = self.read_value(crop,field)
        return result

    def resolve(self, observations, menu, target, cancel):
        result = {f:observations[f] for f in SKILL_REGIONS if f in observations}
        star = observations.get("student_star")
        for field,minimum in SKILL_UNLOCKS.items():
            previous = result.get(field)
            if star is not None and star.confirmed and type(star.value) is int and 1 <= star.value < minimum:
                if previous is not None and previous.source == "panel_value_conflict":
                    continue
                if previous is not None and previous.confirmed:
                    result[field] = Observation(previous.value,previous.confidence,"uncertain","panel_value_conflict",
                        f"{previous.source}={previous.value};skill_star_gate=locked;student_star={star.value}")
                else:
                    result[field] = Observation(None,1,"skipped","skill_star_gate",f"student_star={star.value};unlock={minimum}")
        unresolved = tuple(f for f in SKILL_REGIONS if f not in result or
                          (not result[f].confirmed and result[f].status != "skipped" and result[f].source != "panel_value_conflict"))
        if unresolved and menu is not None:
            result.update(read_panel_fields(menu,"skill",target,cancel,result,unresolved,
                                           lambda frame:self.recognize_menu(frame,unresolved),attempts=1))
        return result

    def close(self):
        for bank in self.templates.values():
            for variants in bank.values():
                for size,ui,text in variants: ui.close();text.close()
        self.templates.clear()
        for image in (self.check_templates or {}).values(): image.close()
        self.check_templates = None

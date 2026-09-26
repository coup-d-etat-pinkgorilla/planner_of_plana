"""F8: positive identity evidence, bounded entry recovery, no speculative input."""
from dataclasses import dataclass
from threading import Event

from PIL import Image
from core import student_meta
from core.scanner_session import ScannerError
from core.scan_context import ScanContext
from core.student_scan_recognizer import ratio_crop
from core.student_weapon_recognizer import _normalized_correlation, _color_similarity
from core import recognition_thresholds as rt


@dataclass(frozen=True)
class StudentIdentity:
    student_ref: str
    score: float
    margin: float
    source: str = 'student_texture_template'


class StudentIdentityRecognizer:
    def __init__(self, catalog):
        self.catalog = catalog
        self.regions = catalog.region_for_purpose('student', 'student-identity-regions')
        self.templates = {}
        self.last_attributes = {}
        self.last_candidates = ()

    def _load(self):
        if not self.templates:
            for asset in self.catalog.assets('student', 'student-attribute-template'):
                with Image.open(self.catalog.resolve(asset.path)) as image:
                    self.templates[asset.identity] = image.convert('RGB')

    def attributes(self, frame):
        self._load()
        result = {}
        for field in ('attack_type', 'defense_type', 'position', 'combat_class', 'role'):
            with ratio_crop(frame, self.regions['basic_attribute_'+field]) as crop:
                scores = sorted(((key.split(':')[1], .7*_normalized_correlation(crop, template)
                    + .3*_color_similarity(crop, template)) for key, template in self.templates.items()
                    if key.startswith(field+':')), key=lambda x: x[1], reverse=True)
            if len(scores) >= 2 and scores[0][1] >= rt.value("student.entry.screen.score") and scores[0][1]-scores[1][1] >= rt.value("student.entry.screen.margin"):
                result[field] = scores[0][0]
        self.last_attributes = result
        self.last_candidates = self.attribute_candidates(result)
        return result

    @staticmethod
    def matching_forms(student_id, attributes):
        if not attributes:
            return ()
        return tuple(form for form in student_meta.form_indexes(student_id)
            if all(str(student_meta.field_for_form(student_id, key, form, '')).lower() == value.lower()
                   for key, value in attributes.items()))

    @classmethod
    def attribute_candidates(cls, attributes):
        if len(attributes) < 3:
            return ()
        ids = tuple(s for s in student_meta.all_ids() if cls.matching_forms(s, attributes))
        return ids if 1 <= len(ids) <= 32 else ()

    def identify(self, frame, matcher, texture_region, canonical, threshold, margin):
        self.last_attributes = {}
        self.last_candidates = ()
        with ratio_crop(frame, texture_region) as crop:
            match = matcher.match(crop)
            if match.score >= threshold and match.margin >= margin:
                return StudentIdentity(canonical(match.identity), match.score, match.margin)
            # A full search remains authoritative; attributes never hide a rival student.
            ranked = matcher.rank(crop)
        attributes = self.attributes(frame)
        by_student = {}
        for identity, score in ranked:
            base, _ = student_meta.split_form_ref(canonical(identity))
            by_student[base] = max(score, by_student.get(base, 0))
        groups = sorted(by_student.items(), key=lambda x: x[1], reverse=True)
        if not groups:
            return None
        (base, score) = groups[0]
        separation = score-(groups[1][1] if len(groups) > 1 else 0)
        # Only a confirmed base portrait may use attributes to disambiguate its forms.
        if not student_meta.is_multi_form(base) or score < threshold or separation < margin:
            return None
        forms = self.matching_forms(base, attributes)
        if len(forms) != 1:
            return None
        return StudentIdentity(student_meta.format_form_ref(base, forms[0]), score, separation,
                               'student_texture_attribute_form')

    def close(self):
        for image in self.templates.values(): image.close()
        self.templates.clear()


class StudentEntryRecovery:
    """One verified lobby -> list -> basic path, or known detail tab -> basic."""
    def __init__(self, capture, catalog, panels):
        self.capture, self.catalog, self.panels = capture, catalog, panels
        self.regions = catalog.region_for_purpose('student', 'student-identity-regions')
        self.templates = {}
        self.trace = []

    def classify(self, frame):
        state = self.panels.recognizer.classify(frame)
        if state != 'unknown':
            return state
        if not self.templates:
            for asset in self.catalog.assets('student', 'student-entry-template'):
                with Image.open(self.catalog.resolve(asset.path)) as image:
                    self.templates[asset.identity] = image.convert('RGB')
        states = []
        for state, template in self.templates.items():
            region = state+'_flag_native_1280' if state == 'lobby' and frame.size == (1280, 720) else state+'_flag'
            with ratio_crop(frame, self.regions[region]) as crop:
                score = .35*_normalized_correlation(crop, template)+.65*_color_similarity(crop, template)
            if score >= rt.value("student.entry.list_card.score"):
                states.append(state)
        return states[0] if len(states) == 1 else 'unknown'

    def recover(self, target, cancel, initial_state):
        state = initial_state
        self.trace = []
        for _ in range(2):
            if state == 'basic':
                return
            if cancel.is_set():
                raise ScannerError('cancelled', 'first student entry cancelled')
            if state == 'lobby':
                button, expected = self.regions['student_list_button'], 'student_list'
            elif state == 'student_list':
                button, expected = self.regions['first_student_button'], 'basic'
            elif state in {'level', 'star'}:
                button, expected = self.panels.regions['basic_info_button'], 'basic'
            else:
                raise ScannerError('panel_wrong_start', 'unverified first-entry state; no input')
            self.capture.click(ScanContext.of(target).replace(cancel=cancel),
                               (button['x1']+button['x2'])/2, (button['y1']+button['y2'])/2)
            self.trace.append(dict(input=state, expected=expected))
            for _poll in range(3):
                if cancel.wait(.2):
                    raise ScannerError('cancelled', 'first student entry cancelled')
                try:
                    with self.capture.wait_stable(target, cancel) as frame:
                        state = self.classify(frame)
                except ScannerError as exc:
                    if exc.code not in {'capture_failed', 'capture_timeout'}:
                        raise
                    state = 'unknown'
                    self.trace.append(dict(capture_error=exc.code))
                    continue
                self.trace.append(dict(state=state))
                if state == expected:
                    break
            if state != expected:
                raise ScannerError('entry_unconfirmed', 'entry input did not reach its expected state')
        if state != 'basic':
            raise ScannerError('entry_unconfirmed', 'bounded first entry did not reach basic')

    def close(self):
        for image in self.templates.values(): image.close()
        self.templates.clear()

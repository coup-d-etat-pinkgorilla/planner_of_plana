"""F8: positive identity evidence, bounded entry recovery, no speculative input."""
from dataclasses import dataclass, replace
from threading import Event

from PIL import Image
from core import student_meta
from core.scanner_session import ScannerError
from core.scan_context import ScanContext
from core.student_scan_recognizer import ratio_crop
from core.recognition_image_ops import color_similarity, ncc_signed_lanczos
from core import recognition_thresholds as rt
from core.student_attribute_filter import AXES, build_candidates, merge_selected_attributes


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
        self.last_attribute_observations = {}
        self.last_filter_evidence = {}
        self.last_name_candidates = None

    def _load(self):
        if not self.templates:
            for asset in self.catalog.assets('student', 'student-attribute-template'):
                with Image.open(self.catalog.resolve(asset.path)) as image:
                    self.templates[asset.identity] = image.convert('RGB')

    def attributes(self, frame):
        self._load()
        result = {}
        observations = {}
        self.last_attribute_observations = observations
        for field in AXES:
            with ratio_crop(frame, self.regions['basic_attribute_'+field]) as crop:
                scores = sorted(((key.split(':')[1], .7*ncc_signed_lanczos(crop, template)
                    + .3*color_similarity(crop, template)) for key, template in self.templates.items()
                    if key.startswith(field+':')), key=lambda x: x[1], reverse=True)
            accepted = len(scores) >= 2 and scores[0][1] >= rt.value("student.entry.screen.score") and scores[0][1]-scores[1][1] >= rt.value("student.entry.screen.margin")
            observations[field] = {
                'value': scores[0][0] if accepted else None,
                'top_value': scores[0][0] if scores else None,
                'score': scores[0][1] if scores else None,
                'confidence': scores[0][1] if scores else None,
                'confidence_kind': 'weighted_template_similarity',
                'roi_id': 'basic_attribute_'+field,
                'roi_geometry': dict(self.regions['basic_attribute_'+field]),
                'margin': scores[0][1]-scores[1][1] if len(scores) >= 2 else None,
                'accepted': accepted,
                'reason': 'accepted' if accepted else 'unknown_or_low_confidence',
            }
            if accepted:
                result[field] = scores[0][0]
        self.last_attributes = result
        self.last_attribute_observations = observations
        return result

    @staticmethod
    def matching_forms(student_id, attributes):
        candidates = build_candidates(attributes)
        if not candidates.used or candidates.fallback_reason:
            return ()
        forms = tuple(form for form in student_meta.form_indexes(student_id)
            if student_meta.format_form_ref(student_id, form) in candidates.after)
        uncertain = {issue.get('student_ref') for issue in candidates.issues}
        if any(student_meta.format_form_ref(student_id, form) in uncertain for form in forms):
            return ()
        return forms

    @classmethod
    def attribute_candidates(cls, attributes):
        candidates = build_candidates(attributes)
        return tuple(sorted(candidates.name_ids)) if candidates.narrowed else ()

    def identify(self, frame, matcher, texture_region, canonical, threshold, margin, *, selected_filters=None):
        self.last_attributes = {}
        self.last_candidates = ()
        self.last_attribute_observations = {}
        self.last_name_candidates = None
        attribute_error = None
        # Every axis is read before either matcher starts its candidate search.
        try:
            attributes = self.attributes(frame)
        except (OSError, ValueError, KeyError, TypeError, ScannerError) as exc:
            attributes = {}
            attribute_error = type(exc).__name__
        for axis in AXES:
            self.last_attribute_observations.setdefault(axis, {
                'value': attributes.get(axis), 'confidence': None, 'score': None, 'margin': None,
                'roi_id': 'basic_attribute_'+axis, 'accepted': axis in attributes,
                'reason': 'attribute_read_failed' if attribute_error else 'no_observation',
            })
        attributes, selected_observations, input_issues = merge_selected_attributes(attributes, selected_filters)
        for axis, observation in selected_observations.items():
            if observation['reason'] == 'selected_observed_conflict':
                self.last_attribute_observations[axis].update(
                    value=None, accepted=False, reason='selected_observed_conflict')
            elif axis not in self.last_attribute_observations:
                self.last_attribute_observations[axis] = dict(observation)
        self.last_attributes = attributes
        raw_ids = getattr(matcher, 'identities', ())
        raw_ids = raw_ids if isinstance(raw_ids, (set, frozenset, tuple, list)) else ()
        candidates = build_candidates(attributes, extra_refs=[canonical(s) for s in raw_ids])
        if input_issues:
            candidates = replace(candidates, issues=candidates.issues + input_issues)
        self.last_candidates = tuple(sorted(candidates.name_ids))
        note = candidates.evidence()
        note.update(attribute_observations=self.last_attribute_observations,
                    portrait_before_count=len(raw_ids),
                    authority='full_catalog_illustration',
                    effective_name_scope='attribute_conditioned' if candidates.narrowed else 'full_catalog',
                    conditional_match=None, global_match=None)
        if selected_filters is not None:
            note['selected_filter_observations'] = selected_observations
        self.last_filter_evidence = note
        for axis, observation in self.last_attribute_observations.items():
            observation['exclusion_applied'] = bool(observation['accepted'] and axis in candidates.used and candidates.narrowed)
            observation['application_reason'] = ('candidate_intersection' if observation['exclusion_applied']
                else candidates.fallback_reason or ('no_candidate_reduction' if axis in candidates.used else observation['reason']))
            observation['initial_exclusion_applied'] = observation['exclusion_applied']
            observation['initial_application_reason'] = observation['application_reason']
        for axis, observation in selected_observations.items():
            observation['exclusion_applied'] = bool(observation['accepted'] and axis in candidates.used and candidates.narrowed)
            observation['application_reason'] = ('explicit_selection' if observation['exclusion_applied']
                else candidates.fallback_reason or observation['reason'])
            observation['initial_exclusion_applied'] = observation['exclusion_applied']
            observation['initial_application_reason'] = observation['application_reason']
        allowed = None
        if attribute_error:
            self._filter_fallback('attribute_read_failed', error=attribute_error)
        elif candidates.narrowed:
            allowed = {s for s in raw_ids if canonical(s) in candidates.after}
            if not allowed:
                allowed = None
                self._filter_fallback('no_portrait_candidates')
            else:
                self.last_name_candidates = candidates.name_ids
        note['portrait_after_count'] = len(allowed) if allowed is not None else len(raw_ids)
        note['portrait_filter_applied'] = allowed is not None
        note['portrait_singleton_handling'] = ('requires_full_catalog_illustration_gate'
            if allowed is not None and len(allowed)==1 else 'not_singleton')
        with ratio_crop(frame, texture_region) as crop:
            if allowed is not None:
                conditional = matcher.match(crop, allowed_identities=allowed)
                note['conditional_match'] = self._match_note(conditional, canonical)
            # The full-catalog score/margin retains production authority. A
            # reduced rival set cannot turn an ambiguous portrait into certainty.
            match = matcher.match(crop)
            note['global_match'] = self._match_note(match, canonical)
            if match.score >= threshold and match.margin >= margin:
                ref = canonical(match.identity)
                if allowed is not None and ref not in candidates.after:
                    self._filter_fallback('global_winner_excluded', excluded_ref=ref)
                elif allowed is not None and canonical(conditional.identity) != ref:
                    self._filter_fallback('conditional_global_conflict', global_ref=ref)
                note['authoritative_ref'] = ref
                return StudentIdentity(ref, match.score, match.margin)
            # A full search remains authoritative; attributes never hide a rival student.
            ranked = matcher.rank(crop)
        by_student = {}
        for identity, score in ranked:
            base, _ = student_meta.split_form_ref(canonical(identity))
            by_student[base] = max(score, by_student.get(base, 0))
        groups = sorted(by_student.items(), key=lambda x: x[1], reverse=True)
        if not groups:
            self._filter_fallback('no_portrait_ranking')
            return None
        (base, score) = groups[0]
        separation = score-(groups[1][1] if len(groups) > 1 else 0)
        # Only a confirmed base portrait may use attributes to disambiguate its forms.
        if not student_meta.is_multi_form(base) or score < threshold or separation < margin:
            self._filter_fallback('global_portrait_unconfirmed')
            return None
        forms = (() if candidates.fallback_reason or attribute_error else
                 tuple(form for form in student_meta.form_indexes(base)
                       if student_meta.format_form_ref(base, form) in candidates.after))
        if len(forms) != 1:
            self._filter_fallback('form_unconfirmed', base=base, matching_forms=list(forms))
            return None
        ref = student_meta.format_form_ref(base, forms[0])
        if any(issue.get('student_ref') == ref for issue in candidates.issues):
            self._filter_fallback('form_metadata_unconfirmed', student_ref=ref)
            return None
        note.update(authoritative_ref=ref, form_resolution='confirmed_global_base_plus_attributes',
                    global_base_score=score, global_base_margin=separation)
        return StudentIdentity(ref, score, separation,
                               'student_texture_attribute_form')

    @staticmethod
    def _match_note(match, canonical):
        return {'student_ref': canonical(match.identity), 'score': match.score, 'margin': match.margin,
                'runner_exists': getattr(match, 'runner_exists', None),
                'runner_margin': getattr(match, 'runner_margin', None)}

    def _filter_fallback(self, reason, **details):
        self.last_name_candidates = None
        self.last_filter_evidence.update(fallback=True, fallback_reason=reason,
                                        final_fallback_reason=reason,
                                        final_candidate_filter_applied=False,
                                        effective_name_scope='full_catalog',
                                        effective_after_count=self.last_filter_evidence['before_count'])
        self.last_filter_evidence['effective_refs'] = list(self.last_filter_evidence['before_refs'])
        self.last_filter_evidence['effective_set_sha256'] = self.last_filter_evidence['before_set_sha256']
        self.last_filter_evidence['fallback_history'].append({'stage': 'identity', 'reason': reason, **details})
        for observation in self.last_attribute_observations.values():
            observation['exclusion_applied'] = False
            observation['application_reason'] = reason
        for observation in self.last_filter_evidence.get('selected_filter_observations', {}).values():
            observation['exclusion_applied'] = False
            observation['application_reason'] = reason
        self.last_filter_evidence.setdefault('contradictions', []).append({'reason': reason, **details})

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
                score = .35*ncc_signed_lanczos(crop, template)+.65*color_similarity(crop, template)
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

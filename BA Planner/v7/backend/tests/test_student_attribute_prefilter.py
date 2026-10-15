"""Attribute-first routing and conservative authority with synthetic inputs."""

import json
import hashlib
from pathlib import Path
from threading import Event, RLock
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from PIL import Image

from core.student_attribute_filter import AXES, build_candidates
from core.student_identity_recovery import StudentIdentity, StudentIdentityRecognizer
from core.scanner_matchers import StudentMatcherAdapter
from core.scanner_matchers import Match, TemplateMatcher
from core import recognition_thresholds as rt

SYNTHETIC_RESULTS = []


def row(**overrides):
    return dict(attack_type='explosive', defense_type='light', role='supporter',
                position='front', combat_class='striker') | overrides


class AttributeCandidateTests(unittest.TestCase):
    def test_versioned_spec_matches_axes_and_unchanged_thresholds(self):
        spec=json.loads((Path(__file__).parents[1]/'assets/recognition/spec/student-attribute-prefilter-v1.json').read_text(encoding='utf-8'))
        self.assertEqual(list(AXES),spec['axes'])
        self.assertEqual(1,spec['version'])
        self.assertEqual(2,spec['evidence_schema_version'])
        measurement=spec['attribute_measurement']
        self.assertEqual(.90,rt.value(measurement['score_threshold_name']))
        self.assertEqual(.10,rt.value(measurement['margin_threshold_name']))
        self.assertFalse(spec['authority']['name_authoritative'])
    def test_all_requested_axes_are_separate_intersection_constraints(self):
        attrs = row()
        rows = {'target': row(), 'outfit': row(attack_type='mystic')}
        alternatives = {'attack_type': 'mystic', 'defense_type': 'heavy',
                        'role': 'dealer', 'position': 'back', 'combat_class': 'special'}
        rows.update({axis: row(**{axis: value}) for axis, value in alternatives.items()})
        result = build_candidates(attrs, metadata=rows)
        self.assertEqual(frozenset({'target'}), result.after)
        self.assertEqual(set(AXES), set(result.used))
        for axis in AXES:
            with self.subTest(axis=axis):
                one = build_candidates({axis: attrs[axis]}, metadata=rows)
                self.assertNotIn(axis, one.after)
                self.assertIn('target', one.after)

    def test_unknown_and_unsupported_values_do_not_exclude(self):
        result = build_candidates({'role': 'special', 'position': 'unknown',
                                   'attack_type': None, 'arbitrary': 'front'},
                                  metadata={'a': row(), 'b': row(role='dealer')})
        self.assertEqual(result.before, result.after)
        self.assertEqual({}, result.used)
        self.assertEqual('no_reliable_attributes', result.fallback_reason)

    def test_role_is_not_combat_class(self):
        rows = {'a': row(), 'b': row(combat_class='special'), 'c': row(role='dealer')}
        self.assertEqual({'a', 'b'}, set(build_candidates({'role': 'supporter'}, metadata=rows).after))
        self.assertEqual({'b'}, set(build_candidates({'combat_class': 'special'}, metadata=rows).after))

    def test_missing_used_metadata_retains_form_even_with_another_mismatch(self):
        rows = {'a': row(role=None, position='back'), 'b': row(), 'new': {}}
        result = build_candidates({'role': 'supporter', 'position': 'front'}, metadata=rows)
        self.assertEqual(set(rows), set(result.after))
        self.assertTrue(any(issue['reason']=='metadata_missing_or_invalid' for issue in result.issues))

    def test_joint_unknown_metadata_exception_is_not_single_axis_intersection(self):
        for missing in (True, False):
            with self.subTest(missing=missing):
                rows={'x':row(role='supporter',position=None if missing else 'back'),
                      'y':row(role='dealer',position='middle'),
                      'z':row(role='dealer',position='back')}
                catalog=None if missing else {'students':rows | {'x':row(role='supporter',position='middle')}, 'forms':{}}
                role_only=build_candidates({'role':'dealer'},metadata=rows,canonical_catalog=catalog)
                joint=build_candidates({'role':'dealer','position':'middle'},metadata=rows,canonical_catalog=catalog)
                self.assertEqual({'y','z'},set(role_only.after))
                self.assertEqual({'x','y'},set(joint.after))
                note=joint.evidence()
                self.assertEqual(2,note['evidence_schema_version'])
                self.assertEqual(['y','z'],note['axis_candidates']['role']['candidate_refs'])
                self.assertEqual(['x','y'],note['axis_candidates']['position']['candidate_refs'])
                self.assertEqual(['y'],note['axis_intersection_refs'])
                self.assertEqual(['x'],note['conservative_override_refs'])
                self.assertEqual(['x','y'],note['proposed_refs'])
                expected=hashlib.sha256(json.dumps(['y','z']).encode('utf-8')).hexdigest()
                self.assertEqual(expected,note['axis_candidates']['role']['candidate_set_sha256'])
                self.assertFalse(note['axis_candidates']['combat_class']['used'])
                self.assertEqual(['x','y','z'],note['axis_candidates']['combat_class']['candidate_refs'])

    def test_canonical_conflict_retains_candidate_and_is_reported(self):
        rows = {'a': row(role='dealer'), 'b': row()}
        catalog = {'students': {'a': row(), 'b': row()}, 'forms': {}}
        result = build_candidates({'role': 'supporter'}, metadata=rows, canonical_catalog=catalog)
        self.assertEqual({'a', 'b'}, set(result.after))
        self.assertIn({'student_ref':'a', 'axis':'role', 'reason':'metadata_conflict'}, result.issues)

    def test_empty_intersection_explicitly_falls_back_to_full_universe(self):
        result = build_candidates({'attack_type':'mystic'}, metadata={'a':row(), 'b':row()})
        self.assertEqual(result.before, result.after)
        self.assertEqual('empty_intersection', result.fallback_reason)
        self.assertEqual(0, result.evidence()['proposed_after_count'])
        self.assertEqual(2, result.evidence()['effective_after_count'])
        self.assertEqual([],result.evidence()['proposed_refs'])
        self.assertEqual([],result.evidence()['axis_candidates']['attack_type']['candidate_refs'])
        self.assertEqual(['a','b'],result.evidence()['effective_refs'])

    def test_missing_additional_canonical_form_is_not_treated_as_base_metadata(self):
        rows={'hoshino_battle':row(), 'hoshino_battle#2':row()}
        result=build_candidates({'role':'dealer'},metadata=rows,
            canonical_catalog={'students':{'hoshino_battle':row()},'forms':{}})
        self.assertIn('hoshino_battle#2',result.after)
        self.assertTrue(any(i.get('student_ref')=='hoshino_battle#2' and
                            i['reason']=='canonical_metadata_missing_or_invalid' for i in result.issues))

    def test_public_metadata_form_overrides_and_outfits_are_distinct(self):
        result = build_candidates({'role':'dealer', 'position':'front', 'attack_type':'mystic'})
        self.assertNotIn('hoshino_battle', result.after)
        self.assertIn('hoshino_battle#2', result.after)
        self.assertNotIn('hoshino_swimsuit', result.after)
        self.assertEqual(267, len(result.before))
        self.assertFalse(result.issues)
        self.assertEqual((2,), StudentIdentityRecognizer.matching_forms('hoshino_battle', {'role':'dealer'}))
        self.assertEqual((1,2), StudentIdentityRecognizer.matching_forms('shun_swimsuit', {'role':'dealer'}))

    def test_invalid_or_missing_metadata_snapshot_disables_exclusion(self):
        for error in (OSError('missing public metadata'), ValueError('invalid public metadata')):
            with self.subTest(error=type(error).__name__), patch(
                'core.student_attribute_filter.resolve_metadata_catalog_path',
                return_value=SimpleNamespace(read_bytes=Mock(side_effect=error)),
            ):
                result = build_candidates({'role':'dealer'})
                self.assertEqual(result.before, result.after)
                self.assertEqual('metadata_unavailable', result.fallback_reason)


class AttributeRuntimeTests(unittest.TestCase):
    def setUp(self):
            self.reader = StudentIdentityRecognizer(SimpleNamespace(region_for_purpose=lambda *_a:{}))
            self.addCleanup(self.reader.close)
            self.region = dict(x1=0, y1=0, x2=1, y2=1)
            self.matcher = object.__new__(TemplateMatcher)
            self.matcher._lock = RLock()
            self.matcher.user_templates = {}
            self.matcher.templates = []
            self.scores = {}
            for i, (sid, score) in enumerate([('a',.96),('b',.87),('c',.70)], 1):
                image = Image.new('RGB',(8,8),(i,0,0))
                self.addCleanup(image.close)
                self.matcher.templates.append((sid,image))
                self.scores[i] = score
            scoring = patch('core.scanner_matchers.image_similarity',
                            side_effect=lambda _actual,template:self.scores[template.getpixel((0,0))[0]])
            scoring.start();self.addCleanup(scoring.stop)
            self.rows = {'a':row(), 'b':row(role='dealer'), 'c':row(role='dealer')}

    def fixture_attributes(self, attributes):
            self.reader.last_attribute_observations={axis:{
                'value':attributes.get(axis),'confidence':.95 if axis in attributes else None,
                'score':.95 if axis in attributes else None,'margin':.20 if axis in attributes else None,
                'confidence_kind':'synthetic_controlled_template_similarity',
                'roi_id':'basic_attribute_'+axis,'roi_geometry':dict(self.region),
                'accepted':axis in attributes,'reason':'accepted' if axis in attributes else 'unknown_or_low_confidence',
            } for axis in AXES}
            return attributes

    def identify(self, attributes, frame=None):
            candidates = build_candidates(attributes, metadata=self.rows)
            with patch.object(self.reader,'attributes',side_effect=lambda _f:self.fixture_attributes(attributes)), patch(
                'core.student_identity_recovery.build_candidates',return_value=candidates,
            ):
                if frame is not None:
                    result = self.reader.identify(frame,self.matcher,self.region,lambda s:s,.82,.04)
                else:
                    with Image.new('RGB',(16,16)) as image:
                        result = self.reader.identify(image,self.matcher,self.region,lambda s:s,.82,.04)
                SYNTHETIC_RESULTS.append({
                    'test': self.id(), 'ground_truth': 'a', 'attributes': attributes,
                    'before_count': len(candidates.before), 'after_count': len(candidates.after),
                    'prefilter_recall': 'a' in candidates.after,
                    'truth_excluded_by_high_confidence_fixture': 'a' not in candidates.after,
                    'final_student_ref': result.student_ref if result else None,
                    'final_status': 'unconfirmed' if result is None else 'correct' if result.student_ref=='a' else 'wrong',
                    'filter_evidence': self.reader.last_filter_evidence,
                    'scope':'synthetic controlled matcher scores; not a native-image performance gate',
                })
                return result

    def test_attributes_then_restricted_actual_match_then_global_guard(self):
            events=[]
            candidates=build_candidates(row(),metadata=self.rows)
            original=self.matcher.match
            def match(image,**kwargs):
                events.append(('match',kwargs.get('allowed_identities')))
                return original(image,**kwargs)
            def attributes(_frame):events.append(('attributes',None));return row()
            with Image.new('RGB',(16,16)) as frame, patch.object(self.reader,'attributes',side_effect=attributes), \
                 patch.object(self.matcher,'match',side_effect=match), \
                 patch('core.student_identity_recovery.build_candidates',return_value=candidates):
                result=self.reader.identify(frame,self.matcher,self.region,lambda s:s,.82,.04)
            self.assertEqual([('attributes',None),('match',{'a'}),('match',None)],events)
            self.assertEqual(StudentIdentity('a',.96,.96-.87),result)
            self.assertEqual(frozenset({'a'}),self.reader.last_name_candidates)
            note=self.reader.last_filter_evidence
            self.assertEqual((3,1),(note['portrait_before_count'],note['portrait_after_count']))
            self.assertGreater(note['conditional_match']['margin'],note['global_match']['margin'])

    def test_confident_wrong_attribute_restores_excluded_global_winner(self):
            result=self.identify({'role':'dealer'})
            self.assertEqual('a',result.student_ref)
            self.assertEqual(.96-.87,result.margin)
            self.assertIsNone(self.reader.last_name_candidates)
            self.assertEqual('global_winner_excluded',self.reader.last_filter_evidence['fallback_reason'])
            self.assertEqual('b',self.reader.last_filter_evidence['conditional_match']['student_ref'])
            self.assertEqual(.95,self.reader.last_filter_evidence['attribute_observations']['role']['confidence'])

    def test_single_filtered_candidate_cannot_inflate_authoritative_margin(self):
            self.scores[2]=.95
            self.assertIsNone(self.identify({'role':'supporter'}))
            note=self.reader.last_filter_evidence
            self.assertEqual(.96,note['conditional_match']['margin'])
            self.assertFalse(note['conditional_match']['runner_exists'])
            self.assertIsNone(note['conditional_match']['runner_margin'])
            self.assertTrue(note['global_match']['runner_exists'])
            self.assertAlmostEqual(.01,note['global_match']['runner_margin'])
            self.assertLess(note['global_match']['margin'],.04)
            self.assertEqual('global_portrait_unconfirmed',note['fallback_reason'])
            self.assertTrue(note['initial_candidate_filter_applied'])
            self.assertFalse(note['final_candidate_filter_applied'])
            self.assertTrue(note['portrait_filter_applied'])
            self.assertTrue(note['attribute_observations']['role']['initial_exclusion_applied'])
            self.assertFalse(note['attribute_observations']['role']['exclusion_applied'])

    def test_retained_unknown_form_cannot_be_confirmed_from_singleton(self):
            self.matcher.templates[0]=('hoshino_battle',self.matcher.templates[0][1])
            self.matcher.templates[1]=('hoshino_battle_1',self.matcher.templates[1][1])
            self.scores.update({1:.90,2:.895})
            candidates=build_candidates({'role':'dealer'},metadata={
                'hoshino_battle':row(role='tanker'), 'hoshino_battle#2':row(role=None), 'c':row(role='dealer')})
            canonical=lambda s:{'hoshino_battle_1':'hoshino_battle#2'}.get(s,s)
            with Image.new('RGB',(16,16)) as frame, \
                 patch.object(self.reader,'attributes',return_value={'role':'dealer'}), \
                 patch('core.student_identity_recovery.build_candidates',return_value=candidates):
                self.assertIsNone(self.reader.identify(frame,self.matcher,self.region,canonical,.82,.04))
            self.assertEqual('form_metadata_unconfirmed',self.reader.last_filter_evidence['fallback_reason'])
            self.assertIsNone(self.reader.last_name_candidates)

    def test_unknown_and_empty_intersection_use_unrestricted_actual_search(self):
            for attrs in ({}, {'attack_type':'sonic'}):
                with self.subTest(attrs=attrs), patch.object(self.matcher,'match',wraps=self.matcher.match) as match:
                    result=self.identify(attrs)
                    self.assertEqual('a',result.student_ref)
                    match.assert_called_once()
                    self.assertNotIn('allowed_identities',match.call_args.kwargs)
                    self.assertIsNone(self.reader.last_name_candidates)

    def test_attribute_read_failure_falls_back_without_changing_illustration(self):
            with Image.new('RGB',(16,16)) as frame, patch.object(self.reader,'attributes',side_effect=OSError('fixture failure')):
                result=self.reader.identify(frame,self.matcher,self.region,lambda s:s,.82,.04)
            self.assertEqual('a',result.student_ref)
            self.assertEqual('attribute_read_failed',self.reader.last_filter_evidence['fallback_reason'])

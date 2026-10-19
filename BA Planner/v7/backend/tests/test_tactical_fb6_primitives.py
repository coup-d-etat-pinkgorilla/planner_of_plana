from copy import deepcopy
import unittest

from core.repository_store import RepositoryError
from core.tactical_fb6 import (
    canonical_attempt_count, canonical_deck, complete_confirmed_deck,
    deck_identity, legacy_date, legacy_deck, lineage_id, matches_defense_pattern,
)


def deck():
    return legacy_deck({'version': 1, 'strikers': ['shiroko', 'akane', 'yuuka', 'mika'], 'specials': ['serina', 'hibiki']})


class TacticalFB6PrimitivesTests(unittest.TestCase):
    def test_full_slot_provenance_and_input_are_preserved(self):
        value = deck()
        value['strikers'][0].update(state='visible_lobby', source='lobby_scan', confidence=.91, review_status='review_required')
        original = deepcopy(value)
        result = canonical_deck(value)
        self.assertEqual(original, result)
        result['strikers'][0]['student_id'] = None
        self.assertEqual(original, value)

    def test_explicit_wildcard_unknown_and_empty_are_distinct(self):
        value = deck()
        for slot, state, wildcard in zip(value['strikers'], ['unknown', 'unknown', 'empty'], [True, False, False]):
            slot.update(student_id=None, state=state, wildcard=wildcard)
        self.assertEqual(('*', '?', 'empty'), deck_identity(canonical_deck(value))[:3])
        self.assertFalse(complete_confirmed_deck(value))

    def test_duplicate_wrong_class_and_unowned_rejected(self):
        value = deck()
        self.assertEqual(value, canonical_deck(value, owned=set(deck_identity(value))))
        with self.assertRaises(RepositoryError):
            canonical_deck(value, owned={'shiroko'})
        for sid in ('shiroko', 'hibiki', 'not-canonical'):
            bad = deepcopy(value)
            bad['strikers'][1]['student_id'] = sid
            with self.subTest(sid=sid), self.assertRaises(RepositoryError):
                canonical_deck(bad)

    def test_bool_indices_and_versions_rejected(self):
        for location, field in (('deck', 'version'), ('slot', 'version'), ('slot', 'position')):
            value = deck()
            target = value if location == 'deck' else value['strikers'][0]
            target[field] = True if field == 'version' else False
            with self.subTest(location=location, field=field), self.assertRaises(RepositoryError):
                canonical_deck(value)

    def test_invalid_confidence_and_non_boolean_wildcard_rejected(self):
        for value in (True, float('nan'), float('inf'), -.1, 1.01, '.5'):
            bad = deck()
            bad['specials'][0]['confidence'] = value
            with self.subTest(value=value), self.assertRaises(RepositoryError):
                canonical_deck(bad)
        bad = deck()
        bad['specials'][0]['wildcard'] = 0
        with self.assertRaises(RepositoryError):
            canonical_deck(bad)

    def test_slot_shape_and_identity_state_invariants_rejected(self):
        for change in ({'student_id': None}, {'state': 'unknown'}, {'wildcard': True}, {'source': 'invented'}, {'review_status': 'approved'}):
            bad = deck()
            bad['strikers'][0].update(change)
            with self.subTest(change=change), self.assertRaises(RepositoryError):
                canonical_deck(bad)
        bad = deck()
        del bad['strikers'][0]['source']
        with self.assertRaises(RepositoryError):
            canonical_deck(bad)

    def test_partial_owned_deck_is_not_promoted_to_complete(self):
        value = deck()
        value['strikers'][3].update(student_id=None, state='unknown', wildcard=True)
        self.assertEqual(value, canonical_deck(value, owned=set(deck_identity(deck()))))
        self.assertFalse(complete_confirmed_deck(value))
        self.assertTrue(complete_confirmed_deck(deck()))

    def test_lineage_is_stable_across_provenance_but_position_matters(self):
        attack, defense = deck(), deck()
        first = lineage_id(defense, attack)
        defense['strikers'][0].update(source='lobby_scan', state='visible_lobby', confidence=.9)
        self.assertEqual(first, lineage_id(defense, attack))
        defense['strikers'][0], defense['strikers'][1] = defense['strikers'][1], defense['strikers'][0]
        self.assertNotEqual(first, lineage_id(defense, attack))

    def test_wildcard_lookup_does_not_match_unknown_as_any_student(self):
        partial, observed = deck(), deck()
        partial['strikers'][3].update(student_id=None, state='unknown', wildcard=True)
        self.assertTrue(matches_defense_pattern(partial, observed))
        partial['strikers'][3]['wildcard'] = False
        self.assertFalse(matches_defense_pattern(partial, observed))
        observed['strikers'][3].update(student_id=None, state='unknown')
        self.assertTrue(matches_defense_pattern(partial, observed))

    def test_attempt_count_has_no_invented_default_or_outcomes(self):
        self.assertEqual(3, canonical_attempt_count(3))
        self.assertIsNone(canonical_attempt_count(None, legacy=True))
        self.assertIsNone(canonical_attempt_count(None))
        for value in (False, True, 0, -1, 1.0, '1'):
            with self.subTest(value=value), self.assertRaises(RepositoryError):
                canonical_attempt_count(value)

    def test_legacy_date_keeps_precision_and_unknown(self):
        self.assertEqual({'occurred_at': '2026-10-13T00:00:00+09:00', 'occurred_precision': 'date'}, legacy_date('2026-10-13'))
        self.assertEqual({'occurred_at': None, 'occurred_precision': 'unknown'}, legacy_date(None))
        for value in ('2026-10-32', '20261013', '2026-10-13T21:10:00+09:00', True):
            with self.subTest(value=value), self.assertRaises(RepositoryError):
                legacy_date(value)

    def test_v1_null_is_unknown_without_fabricated_wildcard(self):
        value = {'version': 1, 'strikers': ['shiroko', None, None, None], 'specials': ['serina', None]}
        original = deepcopy(value)
        result = legacy_deck(value)
        self.assertEqual(original, value)
        unknown = result['strikers'][1]
        self.assertEqual((None, 'unknown', False, 'unreviewed'), (unknown['student_id'], unknown['state'], unknown['wildcard'], unknown['review_status']))
        self.assertIsNone(result['strikers'][0]['confidence'])

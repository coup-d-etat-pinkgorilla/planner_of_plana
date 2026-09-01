from pathlib import Path
import hashlib
import json
from threading import Event
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
from PIL import Image

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import Match, StudentMatcherAdapter
from core.scanner_session import ScannerError
from core.student_identity_recovery import StudentIdentityRecognizer, StudentEntryRecovery
from core.student_panel_recovery import StudentPanelRecovery
from test_student_panel_f2 import FastEvent


class IdentityF8Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.catalog = RecognitionAssetCatalog()

    def adapter(self):
        path = Path(__file__).parent/'fixtures/student_equipment_f7_favorite/miyu-1280.png'
        capture = SimpleNamespace(wait_stable=Mock(side_effect=lambda *_a: Image.open(path).convert('RGB')))
        adapter = StudentMatcherAdapter(capture, self.catalog)
        self.addCleanup(adapter.identity_recognizer.close)
        return adapter, capture

    def test_failed_identity_recaptures_before_reading_any_fields(self):
        adapter, capture = self.adapter()
        with patch.object(adapter.matcher, 'match', side_effect=[Match('mika', .3, .01), Match('miyu', .99, .5)]), \
             patch.object(adapter.basic_recognizer, 'recognize') as basic:
            frame, identity = adapter._capture_identified({}, Event())
            frame.close()
        self.assertEqual('miyu', identity.student_ref)
        self.assertEqual(2, capture.wait_stable.call_count)
        basic.assert_not_called()

    def test_identity_retry_exhaustion_never_uses_top1_as_context(self):
        adapter, capture = self.adapter()
        with patch.object(adapter.matcher, 'match', return_value=Match('mika', .3, .01)), \
             patch.object(adapter.basic_recognizer, 'recognize') as basic:
            with self.assertRaises(ScannerError) as raised:
                adapter._scan_current({}, Event(), lambda *_a: None)
        self.assertEqual('identity_unconfirmed', raised.exception.code)
        self.assertEqual(2, capture.wait_stable.call_count)
        basic.assert_not_called()

    def test_success_does_not_recapture(self):
        adapter, capture = self.adapter()
        frame, identity = adapter._capture_identified({}, Event())
        frame.close()
        self.assertEqual('miyu', identity.student_ref)
        self.assertEqual(1, capture.wait_stable.call_count)

    def test_cancel_prevents_first_capture(self):
        adapter, capture = self.adapter()
        cancel = Event(); cancel.set()
        with self.assertRaises(ScannerError): adapter._capture_identified({}, cancel)
        capture.wait_stable.assert_not_called()

    def test_entry_recovery_is_first_student_only(self):
        adapter, _ = self.adapter()
        entry = Mock()
        entry.classify.return_value = 'student_list'
        adapter.entry_recovery = entry
        with self.assertRaises(ScannerError): adapter._capture_identified({'_first_student': False}, Event())
        entry.recover.assert_not_called()

    def test_entry_cycle_cannot_repeat_after_failed_transition(self):
        adapter, capture = self.adapter()
        entry = Mock()
        entry.classify.return_value = 'student_list'
        adapter.entry_recovery = entry
        with self.assertRaises(ScannerError): adapter._capture_identified({}, Event())
        entry.recover.assert_called_once()
        self.assertEqual(2, capture.wait_stable.call_count)

    def test_form_attribute_tie_never_defaults_to_form_one(self):
        self.assertEqual((1, 2), StudentIdentityRecognizer.matching_forms('shun_swimsuit', {'role': 'dealer'}))
        self.assertEqual((), StudentIdentityRecognizer.matching_forms('hoshino_battle', {}))
        self.assertEqual((2,), StudentIdentityRecognizer.matching_forms('hoshino_battle', {'role': 'dealer'}))

    def test_strong_base_portrait_can_disambiguate_form_but_attributes_cannot_identify_base(self):
        adapter, _ = self.adapter()
        reader = adapter.identity_recognizer
        matcher = Mock()
        matcher.match.return_value = Match('hoshino_battle', .90, .005)
        matcher.rank.return_value = [('hoshino_battle', .90), ('hoshino_battle_1', .895), ('mika', .70)]
        with Image.new('RGB', (1280,720)) as frame, patch.object(reader, 'attributes', return_value={'role':'dealer'}):
            result = reader.identify(frame, matcher, adapter.texture_region, adapter._canonical_student_ref, .82, .04)
            self.assertEqual('hoshino_battle#2', result.student_ref)
            matcher.rank.return_value.append(('shiroko', .89))
            self.assertIsNone(reader.identify(frame, matcher, adapter.texture_region, adapter._canonical_student_ref, .82, .04))

    def test_attribute_candidates_require_three_fields_and_keep_all_portrait_competitors(self):
        self.assertEqual((), StudentIdentityRecognizer.attribute_candidates({'role':'dealer'}))
        ids = StudentIdentityRecognizer.attribute_candidates(dict(role='tanker', attack_type='mystic', position='front'))
        self.assertIn('hoshino_battle', ids)

    def test_unknown_entry_does_not_click(self):
        capture = Mock()
        entry = StudentEntryRecovery(capture, self.catalog, Mock())
        self.addCleanup(entry.close)
        with self.assertRaises(ScannerError): entry.recover({}, Event(), 'unknown')
        capture.click.assert_not_called()

    def test_lobby_list_basic_requires_each_visual_transition(self):
        capture = Mock()
        capture.wait_stable.side_effect = lambda *_a: Image.new('RGB', (10,10))
        entry = StudentEntryRecovery(capture, self.catalog, Mock())
        self.addCleanup(entry.close)
        with patch.object(entry, 'classify', side_effect=['student_list','basic']):
            entry.recover({}, Event(), 'lobby')
        self.assertEqual(2, capture.click.call_count)
        self.assertEqual(2, capture.wait_stable.call_count)

    def test_entry_transition_timeout_is_bounded_without_reclick(self):
        capture = Mock()
        capture.wait_stable.side_effect = [ScannerError('capture_timeout', 'transition'),
                                          Image.new('RGB', (10,10))]
        entry = StudentEntryRecovery(capture, self.catalog, Mock())
        self.addCleanup(entry.close)
        with patch.object(entry, 'classify', return_value='basic'):
            entry.recover({}, FastEvent(), 'student_list')
        capture.click.assert_called_once()
        self.assertEqual(2, capture.wait_stable.call_count)
        capture.reset_mock()
        capture.wait_stable.side_effect = ScannerError('capture_timeout', 'transition')
        with self.assertRaises(ScannerError) as exc: entry.recover({}, FastEvent(), 'lobby')
        self.assertEqual('entry_unconfirmed', exc.exception.code)
        self.assertEqual(3, capture.wait_stable.call_count)
        capture.click.assert_called_once()

    def test_native_states_identity_forms_and_independent_combat(self):
        root = Path(__file__).parent/'fixtures/student_identity_f8_live'
        rows = json.loads((root/'manifest.json').read_text())['assets']
        adapter, _ = self.adapter()
        panels = StudentPanelRecovery(Mock(), self.catalog)
        entry = StudentEntryRecovery(Mock(), self.catalog, panels)
        self.addCleanup(panels.close); self.addCleanup(entry.close)
        from core.student_scan_recognizer import StudentBasicCropSet
        for row in rows:
            with self.subTest(file=row['file']):
                path = root/row['file']
                self.assertEqual(row['sha256'], hashlib.sha256(path.read_bytes()).hexdigest())
                with Image.open(path) as frame:
                    self.assertEqual((1280,720), frame.size)
                    self.assertEqual(row['state'], entry.classify(frame))
                    if not row['identity']: continue
                    identity = adapter.identity_recognizer.identify(frame, adapter.matcher, adapter.texture_region,
                        adapter._canonical_student_ref, adapter.threshold, adapter.margin)
                    self.assertIsNotNone(identity)
                    self.assertEqual(row['identity'], identity.student_ref)
                    if not row['combat']: continue
                    self.assertEqual('student_texture_attribute_form', identity.source)
                    crops = StudentBasicCropSet.from_frame(frame, adapter.regions)
                    try:
                        values = [adapter.basic_recognizer.read_combat(crops.cell_groups['basic_combat_'+key+'_digits'],key,n).value
                                  for key,n in [('hp',4),('atk',2),('def',1),('heal',2)]]
                        self.assertEqual(row['combat'], values)
                    finally: crops.close()
        for color in ('white','black','#173555'):
            with Image.new('RGB',(1280,720),color) as frame: self.assertEqual('unknown',entry.classify(frame))


if __name__ == '__main__': unittest.main()

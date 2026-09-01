import json
from pathlib import Path
from threading import Event
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from PIL import Image
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import StudentMatcherAdapter
from core.student_equipment_recognizer import EquipmentMenuRecognizer, _ratio_crop
from core.student_scan_recognizer import Observation
from tools.benchmark_student_equipment_f7_d2 import FIXTURES, audit, noisy_tier, paste_region


class EquipmentD2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = RecognitionAssetCatalog()
        cls.audit = audit()

    def reader(self, enabled=True):
        return EquipmentMenuRecognizer(self.catalog, allow_t10_inference=enabled)

    def test_independent_originals_cover_all_tiers_without_inference(self):
        rows = self.audit['native']['rows']
        self.assertEqual(24, len(rows))
        self.assertEqual({f'T{i}' for i in range(1, 11)}, {r['expected'][0] for r in rows})
        self.assertTrue(all(r['correct'] and not r['eligible'] for r in rows))
        self.assertEqual(3, sum(r['expected'] == ('T10', 70) for r in rows))

    def test_synthetic_stress_never_promotes_lower_tiers_or_negative_images(self):
        self.assertEqual(0, self.audit['synthetic_perturbation']['false_inferred'])
        self.assertEqual(0, self.audit['synthetic_negatives']['false_inferred'])
        self.assertEqual(321, self.audit['synthetic_negatives']['count'])
        self.assertEqual(5, self.audit['synthetic_perturbation']['recovered'])

    def test_numeric_cells_are_independent_of_any_tier_bank(self):
        reader = self.reader()
        reader.tiers = {}
        with Image.open(FIXTURES/'toki.png') as frame:
            cells = reader.read_level_cells(frame, 1)
        self.assertEqual(('7', '0'), tuple(c[0] for c in cells))
        self.assertTrue(all(c[1] >= .8 and c[2] >= .15 for c in cells))

    def test_policy_boundaries_and_unvalidated_resolution(self):
        base = dict(tier='T10', score=.55, margin=.15,
                    cells=(('7', .8, .15), ('0', .8, .15)), source_size=(1280, 720))
        self.assertTrue(EquipmentMenuRecognizer.can_infer_t10(**base))
        for changes in (dict(score=.549999), dict(score=.60), dict(margin=.149999),
                        dict(tier='T9'), dict(scan_level=False), dict(source_size=(2560, 1440)),
                        dict(cells=(('6', .99, .9), ('9', .99, .9))),
                        dict(cells=(('7', .799999, .9), ('0', .99, .9))),
                        dict(cells=(('7', .99, .149999), ('0', .99, .9))),
                        dict(cells=(('7', .99, .9), (None, 0, 0))),
                        dict(cells=(('v', .99, .9), ('7', .99, .9))), dict(cells=())):
            with self.subTest(changes=changes):
                self.assertFalse(EquipmentMenuRecognizer.can_infer_t10(**(base | changes)))

    def test_real_crop_perturbations_use_inferred_provenance_and_can_be_disabled(self):
        reader = self.reader()
        disabled = self.reader(False)
        for row in self.audit['synthetic_perturbation']['rows']:
            if not row['eligible']:
                continue
            index = next(i for i, a in enumerate(json.loads((FIXTURES/'manifest.json').read_text())['assets'])
                         if a['file'] == row['file'])
            slot = row['slot']
            with Image.open(FIXTURES/row['file']) as frame, noisy_tier(
                    frame, reader, slot, row['sigma'], 1700+index*3+slot) as damaged:
                result = reader.recognize(damaged, (slot,))
                original = disabled.recognize(damaged, (slot,))
                tier_only = reader.recognize(damaged, (slot,), scan_level=False)
            self.assertEqual(('T10', 70), (result[f'equip{slot}'].value, result[f'equip{slot}_level'].value))
            for observation in result.values():
                self.assertEqual('inferred', observation.status)
                self.assertEqual('equipment_level70_t10', observation.source)
            self.assertIsNone(original[f'equip{slot}'].value)
            self.assertIsNone(tier_only[f'equip{slot}'].value)
            self.assertNotIn(f'equip{slot}_level', tier_only)

    def test_strong_70_never_overrules_other_real_tiers(self):
        reader = self.reader()
        # Counterfactual mix: genuine lower-tier images + genuine independent 70.
        for asset in json.loads((FIXTURES/'manifest.json').read_text())['assets']:
            with Image.open(FIXTURES/asset['file']) as frame:
                for slot, tier in enumerate(asset['tiers'], 1):
                    if tier == 'T10':
                        continue
                    positive = 'mimori.png' if slot == 2 else 'toki.png'
                    with frame.copy() as changed, Image.open(FIXTURES/positive) as donor:
                        for pos in (1, 2):
                            region = reader.regions[f'equipment_{slot}_level_digit_{pos}']
                            with _ratio_crop(donor, region) as crop:
                                paste_region(changed, region, crop)
                        result = reader.recognize(changed, (slot,))
                    self.assertEqual(tier, result[f'equip{slot}'].value)
                    self.assertIsNone(result[f'equip{slot}_level'].value)
                    self.assertTrue(all(v.source != 'equipment_level70_t10' for v in result.values()))

    def test_tied_tier_or_digit_evidence_never_promotes(self):
        for tie in ('tier', 'digit'):
            reader = self.reader()
            with Image.open(FIXTURES/'toki.png') as frame, noisy_tier(frame, reader, 1, 120, 1710) as damaged:
                self.assertEqual('T10', reader.recognize(damaged, (1,))['equip1'].value)
                if tie == 'tier':
                    reader.tiers['1:T9'] = reader.tiers['1:T10']
                else:
                    reader.digits['1:1:6'] = reader.digits['1:1:7']
                self.assertIsNone(reader.recognize(damaged, (1,))['equip1'].value)

    def test_inferred_level_is_not_used_for_basic_level_learning(self):
        root = Path(__file__).parent/'fixtures/student_equipment_f7_live'
        capture = SimpleNamespace(wait_stable=lambda *_a: Image.open(root/'mika-basic.png').convert('RGB'))
        menu = SimpleNamespace()
        matcher = StudentMatcherAdapter(capture, self.catalog, equipment_menu=menu)
        for reader in (matcher.equipment_controls, matcher.equipment_recognizer, matcher.skill_recognizer,
                       matcher.star_recognizer, matcher.level_recognizer, matcher.potential_recognizer,
                       matcher.weapon_recognizer):
            self.addCleanup(reader.close)
        missing = Observation(None, 0, 'uncertain', 'fixture', '')
        inferred = {f'equip1{suffix}': Observation(value, .57, 'inferred', 'equipment_level70_t10', '')
                    for suffix, value in (('', 'T10'), ('_level', 70))}
        with patch.object(matcher.equipment_recognizer, 'recognize', return_value=(
                {'equip1': missing, 'equip1_level': missing}, (1,))), \
             patch('core.scanner_matchers.resolve_equipment_menu', return_value=inferred), \
             patch.object(matcher.equipment_recognizer, 'learn_basic_level') as learn:
            rows = matcher._scan_current({}, Event(), lambda *_a: None)
        self.addCleanup(matcher._close_answer_specimens, rows)
        self.assertEqual('equipment_level70_t10', rows[0]['payload']['provenance']['equip1'])
        learn.assert_not_called()


if __name__ == '__main__':
    unittest.main()

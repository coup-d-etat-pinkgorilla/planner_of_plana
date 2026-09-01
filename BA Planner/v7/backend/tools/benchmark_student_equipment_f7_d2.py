"""Offline D2 audit. Native originals and synthetic stress remain separate.

Mika is development/calibration; eight newly captured students are independent
of the fixed menu bank. No image here is installed into recognition assets.
"""
import argparse
import hashlib
import json
from pathlib import Path
import random
import sys

from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.recognition_assets import RecognitionAssetCatalog
from core.student_equipment_recognizer import EquipmentMenuRecognizer, _ratio_crop

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / 'backend/tests/fixtures/student_equipment_f7_d2'


def paste_region(frame, region, crop):
    box = tuple(round(region[k]*s) for k, s in zip(('x1', 'y1', 'x2', 'y2'), frame.size*2))
    with crop.resize((box[2]-box[0], box[3]-box[1]), Image.Resampling.BILINEAR) as resized:
        frame.paste(resized, box[:2])


def noisy_tier(frame, reader, slot, sigma, seed):
    changed = frame.copy()
    rng = random.Random(seed)
    region = reader.regions[f'equipment_{slot}']
    with _ratio_crop(frame, region).convert('RGB') as crop:
        crop.putdata([tuple(max(0, min(255, round(v+rng.gauss(0, sigma)))) for v in px)
                      for px in crop.getdata()])
        paste_region(changed, region, crop)
    return changed


def tier_evidence(reader, frame, slot):
    with _ratio_crop(frame, reader.regions[f'equipment_{slot}']) as crop:
        tier, score, margin = reader._rank(crop, {k.split(':', 1)[1]: v for k, v in reader.tiers.items()
                                               if k.startswith(f'{slot}:')})
    cells = reader.read_level_cells(frame, slot)
    return dict(tier=tier, score=score, margin=margin, cells=cells,
                eligible=reader.can_infer_t10(tier, score, margin, cells, source_size=frame.size))


def audit():
    catalog = RecognitionAssetCatalog()
    reader = EquipmentMenuRecognizer(catalog, allow_t10_inference=True)
    native, perturbations, negatives = [], [], []
    calibration = []
    with Image.open(ROOT/'backend/tests/fixtures/student_equipment_f7_live/mika-on.png') as frame:
        for slot in (1, 2, 3):
            for sigma in range(0, 201, 20):
                with noisy_tier(frame, reader, slot, sigma, 710+slot) as changed:
                    calibration.append(dict(slot=slot, sigma=sigma, **tier_evidence(reader, changed, slot)))
    manifest = json.loads((FIXTURES/'manifest.json').read_text())
    for index, asset in enumerate(manifest['assets']):
        path = FIXTURES/asset['file']
        if hashlib.sha256(path.read_bytes()).hexdigest() != asset['sha256']:
            raise ValueError(f'Fixture changed: {path}')
        with Image.open(path).convert('RGB') as frame:
            result = reader.recognize(frame, (1, 2, 3))
            for slot in (1, 2, 3):
                expected = (asset['tiers'][slot-1], asset['levels'][slot-1])
                predicted = (result[f'equip{slot}'].value, result[f'equip{slot}_level'].value)
                native.append(dict(file=asset['file'], slot=slot, expected=expected,
                    predicted=predicted, correct=expected == predicted, **tier_evidence(reader, frame, slot)))
                # Fixed sweep, not selecting an individual corruption after seeing its score.
                for sigma in (100, 110, 120, 130, 140):
                    with noisy_tier(frame, reader, slot, sigma, 1700+index*3+slot) as changed:
                        evidence = tier_evidence(reader, changed, slot)
                        perturbations.append(dict(file=asset['file'], slot=slot, sigma=sigma,
                            positive=expected == ('T10', 70), **evidence))
                if expected != ('T10', 70):
                    continue
                tier_region = reader.regions[f'equipment_{slot}']
                # Keep actual independent 70 visible while replacing only the tier ROI.
                for color in ('white', 'black', 'gray'):
                    with frame.copy() as changed, Image.new('RGB', (59, 29), color) as crop:
                        paste_region(changed, tier_region, crop)
                        negatives.append(dict(case=f'blank-{color}', file=asset['file'], slot=slot,
                                              **tier_evidence(reader, changed, slot)))
                for seed in range(100):
                    rng = random.Random(2700+seed)
                    with frame.copy() as changed, Image.new('RGB', (59, 29)) as crop:
                        crop.putdata([tuple(rng.randrange(256) for _ in range(3)) for _ in range(59*29)])
                        paste_region(changed, tier_region, crop)
                        negatives.append(dict(case='noise', seed=seed, file=asset['file'], slot=slot,
                                              **tier_evidence(reader, changed, slot)))
                for key in (f'equipment_{slot}_level_digit_1', f'equipment_{slot}_level_digit_2',
                            'equipment_button', 'equipment_all_view_check_region'):
                    with frame.copy() as changed, _ratio_crop(frame, reader.regions[key]) as crop:
                        paste_region(changed, tier_region, crop)
                        negatives.append(dict(case=f'wrong-family-{key}', file=asset['file'], slot=slot,
                                              **tier_evidence(reader, changed, slot)))
    return dict(version=1, policy='D2-native1280-v1', normal_tier_threshold=.60,
        candidate_tier_floor=.55, candidate_margin=.15, independent_digit_floor=.80, digit_margin=.15,
        bank_sha256={asset.path: hashlib.sha256(catalog.resolve(asset.path).read_bytes()).hexdigest()
                     for purpose in ('student-equipment-menu-tier-template', 'student-equipment-menu-digit-template',
                                     'student-equipment-menu-flag-template', 'student-equipment-menu-regions')
                     for asset in catalog.assets('student', purpose)},
        calibration=dict(partition='development_mika_not_independent_validation', rows=calibration),
        native=dict(slots=len(native), correct=sum(row['correct'] for row in native), rows=native),
        synthetic_perturbation=dict(count=len(perturbations),
            recovered=sum(r['eligible'] and r['positive'] for r in perturbations),
            false_inferred=sum(r['eligible'] and not r['positive'] for r in perturbations), rows=perturbations),
        synthetic_negatives=dict(count=len(negatives), false_inferred=sum(r['eligible'] for r in negatives), rows=negatives),
        limitations=['No naturally weak T10 observed', 'Synthetic corruption is not natural live failure',
                     'Native2560 inference unvalidated and disabled', 'Small independent student sample'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = audit()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k: {a: b for a, b in v.items() if a != 'rows'} for k, v in report.items() if isinstance(v, dict)}))


if __name__ == '__main__':
    main()

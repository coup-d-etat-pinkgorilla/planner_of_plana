"""A1-b regression against independent A0 sample metadata; integrity for all outputs."""
import argparse
from pathlib import Path
from _research_common import ROOT, load, sha, write_new


def facts(clip, old=False):
    return {'name': clip['name'], 'pathId': clip['pathId'], 'sourceFps': clip['sourceFps'],
            'lengthSeconds': clip['lengthSeconds'],
            'events': [{'time': e['timeSeconds'] if old else e['time'],
                        'name': e['name'] if old else e['functionName'],
                        'data': e['data'] if old else e['stringParameter'],
                        'reference': (e['parameterReference'] or {}).get('m_PathID', 0) if old else e['objectReferencePathId']}
                       for e in clip['events']]}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--src', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    index = load(args.src / 'index.json')
    integrity = [r['path'] for r in index['files'] if sha(ROOT / r['path']) != r['sha256'] or (ROOT / r['path']).stat().st_size != r['bytes']]
    a0 = load(ROOT / 'debug/five_followup_coord_20261008/a0/artifacts/availability-evidence.json')
    sample_results = []
    for sample in a0['samples']:
        old = {c['pathId']: facts(c, True) for c in sample['clips']}
        # Identify by the exact A0 containing bundle, never a similar character name.
        filename = Path(sample['bundle']['path']).name
        rel = next((b['path'] for b in index['bundles'] if Path(b['path']).name == filename), None)
        matched = next((c for c in index['characters'] if rel and rel in (c['clipsBundle'] or [])), None)
        current = load(args.src / matched['file']) if matched else None
        new = {c['pathId']: facts(c) for c in current['clips'] if c['bundlePath'] == rel} if current else {}
        bundle_sha = next((b['sha256'] for b in index['bundles'] if b['path'] == rel), None)
        ok = old == new and bundle_sha == sample['bundle']['sha256']
        sample_results.append({'sample': sample['character'], 'characterId': matched['characterId'] if matched else None,
            'oldClips': len(old), 'newClips': len(new), 'events': sum(len(c['events']) for c in new.values()),
            'pass': ok, 'bundleHashEqual': bundle_sha == sample['bundle']['sha256']})
    # Recompute rather than trust the recorded unmapped flag.
    mapping_errors = []
    for c in index['characters']:
        data = load(args.src / c['file'])
        if not data['clips'] and (data['clipsBundle'] is not None or not data['missingReason']):
            mapping_errors.append({'characterId': c['characterId'], 'reason': 'empty clips missing explicit null/reason'})
        for clip in data['clips']:
            if clip['unmapped'] != (not bool(clip['motionStates'])):
                mapping_errors.append({'characterId': c['characterId'], 'clip': clip['name']})
    result = {'pass': not integrity and not mapping_errors and all(r['pass'] for r in sample_results),
        'a0SampleRegressions': sample_results, 'integrityErrors': integrity, 'mappingErrors': mapping_errors,
        'payloadFileCount': len(index['files']), 'spineRead': False, 'textureMeshRead': False,
        'contractSha256': sha(ROOT/'contracts/animation-spectrum-v1.schema.json'),
        'fixtureSha256': sha(ROOT/'contracts/fixtures/animation-spectrum/binah-sample.json')}
    write_new(args.out, result)
    print(result)
    if not result['pass']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()

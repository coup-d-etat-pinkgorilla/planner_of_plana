"""A1-a meaningful regression: immutable Mika/Binah rows and emitted file integrity."""
from __future__ import annotations
import argparse
from collections import Counter
from pathlib import Path
from _research_common import ROOT, load, sha, write_new


def identity(row):
    s = row['source']
    return (s['database'], s['table'], s.get('key'), s.get('groupId'), s.get('level'))


def comparable(row):
    return {k: row[k] for k in ('status', 'consumedBytes', 'totalBytes', 'decodeError', 'dao')} | {
        'rowSha256': row['source']['rowSha256']}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--src', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    index = load(args.src / 'index.json')
    rows, integrity, counts = {}, [], Counter()
    for rec in index['files']:
        p = ROOT / rec['path']
        ok = sha(p) == rec['sha256'] and p.stat().st_size == rec['bytes']
        if not ok:
            integrity.append(rec['path'])
        payload = load(p)
        for skill in payload['skills'].values():
            for row in skill['logicRows'] + skill['logicEffectRows']:
                ident = identity(row)
                if ident in rows and comparable(rows[ident]) != comparable(row):
                    raise ValueError('conflicting duplicate raw row')
                rows[ident] = row
                if row['status'] == 'full' and (row['consumedBytes'] != row['totalBytes'] or row['decodeError']):
                    raise ValueError('strict consumption invariant violated')
    mika = load(ROOT / 'docs/tactic-editor/evidence/t1-mika-ex-logic-jp-1.73.0.json')
    binah = load(ROOT / 'data/extracted/battle-binah-jp.json')
    results = {}
    for name, baseline in (('mikaSkillLogic', mika['skillLogic']), ('mikaLogicEffectsAllLevels', mika['logicEffects']),
                           ('binahAllVariantSkillRows', binah['skills'])):
        matches, missing, changed = 0, [], []
        for old in baseline:
            ident = identity(old)
            if ident not in rows:
                missing.append(ident)
            elif comparable(rows[ident]) != comparable(old):
                changed.append(ident)
            else:
                matches += 1
        results[name] = {'baselineRows': len(baseline), 'identicalRows': matches,
                         'missing': missing, 'changed': changed, 'pass': matches == len(baseline)}
    torment = load(args.src / '7300700.json')
    counts.update(r['status'] for r in rows.values())
    receipt = {'schema': 'ba-planner.a1a-regression.v1', 'pass': not integrity and all(r['pass'] for r in results.values()),
               'regressions': results, 'integrityErrors': integrity, 'payloadFileCount': len(index['files']),
               'uniqueEmittedRowCounts': dict(counts), 'tormentDirectSkillGroups': torment['skillGroups'],
               'sourceMismatch': '[표] Existing Binah 29 rows cover multiple difficulties/test rows, not Torment only; Torment has six directly listed groups.',
               'contractSha256': sha(ROOT / 'contracts/animation-spectrum-v1.schema.json'),
               'fixtureSha256': sha(ROOT / 'contracts/fixtures/animation-spectrum/binah-sample.json')}
    write_new(args.out, receipt)
    print({k: receipt[k] for k in ('pass', 'payloadFileCount', 'regressions', 'uniqueEmittedRowCounts')})
    if not receipt['pass']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()

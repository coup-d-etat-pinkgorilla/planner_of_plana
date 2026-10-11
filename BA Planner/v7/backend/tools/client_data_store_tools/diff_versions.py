"""Same-server L1/L2 diff. Default: legacy changelog write; --stdout/--out: no store writes.

--out accepts an existing directory outside the store and creates one new report file.
It never creates a directory or overwrites an existing report. --stdout emits only JSON.
Reviewed row keys are opt-in via --id-keys; unreviewed tables retain row-set hashes.
L3 remains NOT_COMPUTED.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path

try:
    from ._common import read_json, store_root, write_json
    from ._validation import component, contained, manifest_identity, version
    from .row_identity import compare_rows, load_reviewed_keys, table_rows
except ImportError:
    from _common import read_json, store_root, write_json
    from _validation import component, contained, manifest_identity, version
    from row_identity import compare_rows, load_reviewed_keys, table_rows


def level1(ma, mb):
    out = {}
    for name in sorted(set(ma['files']) | set(mb['files'])):
        a, b = ma['files'].get(name), mb['files'].get(name)
        if a is None or b is None:
            out[name] = 'only_in_a' if b is None else 'only_in_b'
        else:
            out[name] = 'same' if a['sha256'] == b['sha256'] else 'changed'
    return out


def rows_of(path: Path):
    """Compatibility helper retaining the historical (hash set, row count) result."""
    try:
        from ._common import canonical_json, sha256_bytes
    except ImportError:
        from _common import canonical_json, sha256_bytes
    rows = table_rows(path)
    return {sha256_bytes(canonical_json(row)) for row in rows}, len(rows)


def _json_files(directory: Path):
    return sorted(path.name for path in directory.glob('*.json')
                  if path.name not in ('provenance.json', 'SOURCE.json')) if directory.exists() else []


def diff_exceldb(da: Path, db: Path, reviewed_keys: dict | None = None):
    out = {}
    for name in sorted(set(_json_files(da)) | set(_json_files(db))):
        component(name, 'table filename')
        pa, pb = contained(da, name), contained(db, name)
        present_a, present_b = pa.exists(), pb.exists()
        result = compare_rows(table_rows(pa) if present_a else [], table_rows(pb) if present_b else [],
                              (reviewed_keys or {}).get(name))
        if result['status'] != 'invalid_identity' and not (present_a and present_b):
            result['status'] = 'only_in_a' if present_a else 'only_in_b'
        out[name] = result
    return out


def diff_types(da: Path, db: Path):
    """Preserved type count comparison; signature changes and duplicate names remain limited."""
    def load(directory):
        files = list(directory.glob('*.json'))
        files = [path for path in files if path.name != 'provenance.json']
        if not files:
            return None
        value = read_json(contained(directory, files[0].name))
        return {row['name']: row for row in value}
    ta, tb = load(da), load(db)
    if ta is None or tb is None:
        return {'status': 'missing'}
    added, removed = sorted(set(tb) - set(ta)), sorted(set(ta) - set(tb))
    changed = {}
    for name in set(ta) & set(tb):
        ma, mb = len(ta[name].get('methods', [])), len(tb[name].get('methods', []))
        fa, fb = len(ta[name].get('fields', [])), len(tb[name].get('fields', []))
        if (ma, fa) != (mb, fb):
            changed[name] = {'methods': [ma, mb], 'fields': [fa, fb]}
    return {'types_a': len(ta), 'types_b': len(tb), 'added': added[:200], 'removed': removed[:200],
            'added_count': len(added), 'removed_count': len(removed), 'changed_count': len(changed),
            'changed': dict(sorted(changed.items())[:200])}


def diff_files(da: Path, db: Path):
    pa = read_json(contained(da, 'provenance.json'))['files']
    pb = read_json(contained(db, 'provenance.json'))['files']
    ha, hb = {row['path']: row['sha256'] for row in pa}, {row['path']: row['sha256'] for row in pb}
    return {'same': sum(1 for key in ha if hb.get(key) == ha[key]),
            'changed': sorted(key for key in ha if key in hb and hb[key] != ha[key]),
            'only_in_a': sorted(set(ha) - set(hb)), 'only_in_b': sorted(set(hb) - set(ha))}


def _kind_directories(root: Path):
    result = {}
    if root.exists():
        for path in root.iterdir():
            if path.is_dir():
                component(path.name, 'kind')
                result[path.name] = contained(root, path.name)
    return result


def build_report(store: Path, server: str, a: str, b: str, reviewed_keys=None, *, generated_utc=None):
    """Read-only report construction. Top-level eight-key changelog.v1 shape is preserved."""
    version(server, a)
    version(server, b)
    store = store.resolve()
    ma = read_json(contained(store, 'clients', server, a, 'manifest.json'))
    mb = read_json(contained(store, 'clients', server, b, 'manifest.json'))
    manifest_identity(ma, server, a)
    manifest_identity(mb, server, b)
    report = {'schema': 'ba-client-data.changelog.v1', 'server': server, 'a': a, 'b': b,
              'generated_utc': generated_utc or dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds'),
              'level1_files': level1(ma, mb), 'level2_extracts': {},
              'level3_behavior': 'NOT_COMPUTED: record human judgement with evidence in status/<server>/<version-id>.md'}
    ea = contained(store, 'extracts', server, a)
    eb = contained(store, 'extracts', server, b)
    ka, kb = _kind_directories(ea), _kind_directories(eb)
    for kind in sorted(set(ka) | set(kb)):
        if kind not in ka or kind not in kb:
            report['level2_extracts'][kind] = {
                'status': 'only_in_a' if kind not in kb else 'only_in_b',
                'comparison_mode': 'kind_inventory', 'present_a': kind in ka, 'present_b': kind in kb,
                'limitation': 'Kind absent on one side: no payload comparison was computed.'}
        elif kind.startswith('exceldb-json'):
            report['level2_extracts'][kind] = diff_exceldb(ka[kind], kb[kind], reviewed_keys)
        elif kind.startswith('il2cpp-types'):
            report['level2_extracts'][kind] = diff_types(ka[kind], kb[kind])
        else:
            report['level2_extracts'][kind] = diff_files(ka[kind], kb[kind])
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--server', choices=('jp', 'steam'), required=True)
    parser.add_argument('--a', required=True)
    parser.add_argument('--b', required=True)
    parser.add_argument('--store')
    preview = parser.add_mutually_exclusive_group()
    preview.add_argument('--stdout', action='store_true', help='emit full report JSON without store writes')
    preview.add_argument('--out', type=Path, help='existing directory outside store; create new report without mkdir/overwrite')
    parser.add_argument('--id-keys', type=Path, help='explicit reviewed flat row-key policy JSON')
    args = parser.parse_args(argv)
    try:
        store = store_root(args.store)
        version(args.server, args.a)
        version(args.server, args.b)
        out = None
        if args.out is not None:
            directory = args.out.resolve()
            if directory.is_relative_to(store.resolve()):
                raise ValueError('--out must be outside store')
            if not directory.is_dir():
                raise ValueError('--out directory must already exist; preview does not mkdir')
            out = directory / f'{args.a}__{args.b}.json'
            if out.resolve().is_relative_to(store.resolve()):
                raise ValueError('output path resolves inside store')
            if out.exists():
                raise ValueError('preview output already exists; no overwrite')
        report = build_report(store, args.server, args.a, args.b, load_reviewed_keys(args.id_keys))
    except (ValueError, FileNotFoundError, json.JSONDecodeError) as exc:
        raise SystemExit(str(exc)) from exc
    if args.stdout:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    if out is not None:
        with out.open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({'written': str(out), 'store_written': False}, ensure_ascii=False))
        return 0
    out = contained(store, 'changelog', args.server, f'{args.a}__{args.b}.json')
    write_json(out, report, overwrite=True)
    print(json.dumps({'level1': report['level1_files'], 'level2_kinds': list(report['level2_extracts'])}, indent=2))
    print(f'wrote {out}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

"""W4 bounded JP-only static field inventory; no game code execution."""
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'data/extracted/pipeline'))
from il2cpp_meta import Il2Cpp


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    artifact_dir = Path(__file__).resolve().parent
    output = artifact_dir / 'jp-static-field-inventory-v2.json'
    if output.exists():
        raise SystemExit('preserve prior output')
    lock = json.loads((ROOT / 'ba-data.lock').read_text(encoding='utf-8'))
    manifest = json.loads(Path('C:/Users/brigh/ba-client-data/clients/jp/jp-1.73.0-e2baf70e/manifest.json').read_text(encoding='utf-8'))
    paths = {n: Path(manifest['files'][n]['installed_path']) for n in ['GameAssembly.dll', 'global-metadata.dat']}
    actual = {n: sha(p) for n, p in paths.items()}
    assert all(actual[n] == lock['pins']['jp']['files'][n] for n in paths)
    parser = Il2Cpp(str(paths['GameAssembly.dll']), str(paths['global-metadata.dat']))
    favor_fields, const_fields, cafe_methods, relevant = [], [], [], []
    property_count = 0
    field_count = 0
    favor_pattern = re.compile(r'FavorLevel|ExpType|Favor.*Type', re.I)
    cafe_pattern = re.compile(r'Cafe|Interaction|CoolTime|Interval', re.I)
    for ti in range(parser.n_td):
        name = parser.tdname(ti)
        td = parser.td(ti)
        for fi in range(td['fieldStart'], td['fieldStart'] + td['field_count']):
            field_name, ft = parser.field(fi)
            field_count += 1
            if favor_pattern.search(field_name):
                favor_fields.append({'declaringType': name, 'field': field_name, 'type': parser.tname(ft), 'fieldIndex': fi})
            if name.startswith('MX.Data.Excel.Const') and cafe_pattern.search(field_name):
                const_fields.append({'declaringType': name, 'field': field_name, 'type': parser.tname(ft), 'fieldIndex': fi})
        properties = []
        for k in range(td['property_count']):
            n, getter, _, _, _ = struct.unpack_from('<5i', parser.M, parser.H['properties'][0] + (td['propertyStart'] + k) * 20)
            if getter >= 0:
                properties.append({'name': parser.cstr(n), 'type': parser.tname(parser.method(td['methodStart'] + getter)['returnType'])})
        property_count += len(properties)
        for prop in properties:
            if favor_pattern.search(prop['name']):
                favor_fields.append({'declaringType': name, 'property': prop['name'], 'type': prop['type']})
            if re.search(r'Const.*Excel', name) and cafe_pattern.search(prop['name']):
                const_fields.append({'declaringType': name, 'property': prop['name'], 'type': prop['type']})
        if name in ['MX.Data.Excel.FavorLevelExcel', 'MX.Data.Excel.CafeInteractionExcel', 'MX.Data.Excel.CharacterExcel', 'FlatData.ParcelType'] or (re.search(r'Const.*Excel$', name) and ('Cafe' in name or 'Common' in name)):
            relevant.append(parser.schema(ti))
        if re.search(r'Cafe|Interaction', name, re.I):
            names = [parser.method(mi)['name'] for mi in range(td['methodStart'], td['methodStart'] + td['method_count'])]
            # FlatBuffers generated methods do not ground the client cooldown behavior.
            if not name.startswith('MX.Data.Excel.') and names:
                cafe_methods.append({'declaringType': name, 'methods': parser.method_addresses(name)})
    data = {'schema': 'ba-planner.w4-jp-static-inventory.v1', 'versionId': manifest['version_id'], 'hashes': actual,
            'typeCount': parser.n_td, 'fieldsExamined': field_count, 'propertiesExamined': property_count,
            'favorFieldPattern': favor_pattern.pattern, 'favorReferenceFields': favor_fields,
            'constFieldPattern': cafe_pattern.pattern, 'constCandidateFields': const_fields,
            'relevantTypes': relevant, 'cafeMethodNameInventory': cafe_methods,
            'scope': 'JP pinned metadata only; Steam debug/il2cpp_types is documented as Steam and not used as JP evidence'}
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'typeCount': parser.n_td, 'fieldsExamined': field_count, 'favorReferenceFields': len(favor_fields), 'constCandidateFields': len(const_fields), 'cafeMethodTypes': len(cafe_methods)}))
    print('favor references', json.dumps(favor_fields, ensure_ascii=False))
    print('const candidates', json.dumps(const_fields, ensure_ascii=False))


if __name__ == '__main__':
    main()

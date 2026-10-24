"""Generate reviewed store metadata without fetching or inferring provider data.

The frozen catalog is the explicit retained input for local/KR-only fields.
The crosswalk binds both it and the complete lock. Gift experience uses the
approved frozen table until a separately reviewed source is chosen.
"""
from __future__ import annotations

from copy import deepcopy
import ast
import hashlib
import json
from pathlib import Path
import pprint
import re

from core.canonical_metadata import CanonicalMetadataCatalog
from tools.metadata_store_preview import digest, preview
from tools.sync_student_stats_from_extracted import load_store_pairs

_SHA = re.compile(r'^[0-9a-f]{64}$')


def _rows(section, key):
    if not isinstance(section, dict) or not isinstance(section.get('rows'), list):
        raise ValueError('source rows are missing')
    rows = {}
    for row in section['rows']:
        if (not isinstance(row, dict) or type(row.get(key)) is not int or row[key] in rows
                or not isinstance(row.get('rowSha'), str) or not _SHA.fullmatch(row['rowSha'])):
            raise ValueError('source row ID/hash is invalid or duplicated')
        rows[row[key]] = row
    if type(section.get('rowCount')) is not int or section['rowCount'] != len(rows):
        raise ValueError('source row count differs from its rows')
    return rows


def _ordered_tags(old, new):
    # Preserve semantically equal tag ordering for legacy DTO parity.
    return list(old) if set(old) == set(new) else list(new)


def regenerate(catalog, reader, crosswalk, frozen_exp, old_gifts, form_bindings=None):
    """Return complete generated values and an honest field-source sidecar.

    This function is pure except for verified read-only store access. No input
    is changed, no network provider is imported, and no output is installed.
    """
    if not isinstance(crosswalk, dict):
        raise ValueError('an explicit reviewed crosswalk is required')
    selected = preview(catalog, reader, crosswalk)
    if set(crosswalk['students']) != set(catalog.students):
        raise ValueError('a complete reviewed identity crosswalk is required')
    source = reader.read_json_extract('jp', 'gift-affinity', 'gift-affinity-jp-1.73.0.json')
    version = reader.lock['pins']['jp']['version_id']
    if (not isinstance(source, dict) or source.get('schema') != 'ba-planner.gift-affinity-source.v1'
            or source.get('server') != 'jp' or source.get('versionId') != version):
        raise ValueError('gift source version/server/schema mismatch')
    enum = source['d_enumComparison']['Tag']
    if enum.get('equal') is not True or not isinstance(enum.get('jp'), dict):
        raise ValueError('tag enum must be reviewed equal')
    reverse = {}
    for name, number in enum['jp'].items():
        if not isinstance(name, str) or not name or type(number) is not int or number in reverse:
            raise ValueError('tag enum must be a bijection')
        reverse[number] = name

    def tags(numbers, given_names):
        if not isinstance(numbers, list) or any(type(n) is not int or n not in reverse for n in numbers):
            raise ValueError('unmapped tag; no fallback')
        values = [reverse[n] for n in numbers]
        if len(values) != len(set(values)) or values != given_names:
            raise ValueError('duplicate or inconsistent source tag names')
        return values

    students = _rows(source['a_characterAcademyTags'], 'characterId')
    gifts = _rows(source['b_favorItems'], 'id')
    if (not isinstance(frozen_exp, dict) or type(frozen_exp.get('schemaVersion')) is not int
            or frozen_exp['schemaVersion'] != 1
            or not isinstance(frozen_exp.get('gifts'), dict)
            or set(frozen_exp['gifts']) != {str(gid) for gid in gifts}
            or set(gifts) != set(old_gifts)):
        raise ValueError('frozen gift experience identities differ from source')
    proposed = deepcopy(selected['proposed_catalog'])
    field_sources = deepcopy(selected['projected_fields'])
    for field in field_sources.values():
        field['provenance'].pop('extractedAt', None)
        field['provenance']['tool'] = 'metadata-store-regenerate-v1'
    for sid, spec in crosswalk['students'].items():
        row = students.get(spec['row_id'])
        if row is None:
            raise ValueError('reviewed student has no academy row')
        original = catalog.gift_affinities.get(sid)
        if original is None:
            raise ValueError('missing retained student affinity')
        incoming = {
            'preferred_tags': tags(row['favorItemTags'], row['favorItemTagNames']),
            'unique_tags': tags(row['favorItemUniqueTags'], row['favorItemUniqueTagNames']),
        }
        proposed['gift_affinities'][sid] = {
            name: _ordered_tags(original[name], value) for name, value in incoming.items()}
        for name in incoming:
            field_sources[f'gift_affinities.{sid}.{name}'] = {
                'value': proposed['gift_affinities'][sid][name],
                'provenance': {'kind': 'gift-affinity', 'versionId': version,
                    'table': 'CharacterAcademyTagsExcel', 'rowSha': row['rowSha'],
                    'tool': 'metadata-store-regenerate-v1'}}
    generated_gifts = {}
    raw_tag_changes = []
    for gid, row in sorted(gifts.items()):
        frozen = frozen_exp['gifts'][str(gid)]
        exp = frozen.get('exp_value')
        if type(exp) is not int or exp <= 0 or exp != old_gifts[gid]['exp_value']:
            raise ValueError('gift experience differs from the approved frozen input')
        incoming = tags(row['tags'], row['tagNames'])
        old = old_gifts[gid]
        if old['category'] != 'Favor' or old['id'] != gid:
            raise ValueError('gift identity/category changed')
        generated_gifts[gid] = {'id': gid, 'category': 'Favor',
            'tags': _ordered_tags(old['tags'], incoming), 'exp_value': exp}
        if set(incoming) != set(old['tags']):
            raw_tag_changes.append({'gift_id': gid, 'before': old['tags'], 'after': incoming})
        field_sources[f'gifts.{gid}.tags'] = {'value': generated_gifts[gid]['tags'],
            'provenance': {'kind': 'gift-affinity', 'versionId': version, 'table': 'ItemExcel',
                'rowSha': row['rowSha'], 'tool': 'metadata-store-regenerate-v1'}}
        field_sources[f'gifts.{gid}.exp_value'] = {'value': exp, 'provenance': deepcopy(frozen['provenance'])}
    validated = CanonicalMetadataCatalog.from_payload(proposed)
    stat_pairs = load_store_pairs(reader, 'student-stats')
    stats = {target: raw for _, target, raw, _ in stat_pairs}
    stat_ids = stat_pairs[0][3].students
    retained_forms = {}
    if form_bindings is not None:
        if (not isinstance(form_bindings, dict) or set(form_bindings) != {'schemaVersion','students','provenance'}
                or type(form_bindings['schemaVersion']) is not int or form_bindings['schemaVersion'] != 1
                or not isinstance(form_bindings['students'], dict)
                or set(form_bindings['students']) != set(catalog.students)):
            raise ValueError('invalid retained local form bindings')
        retained_forms = form_bindings['students']
    references = {}
    for sid, spec in crosswalk['students'].items():
        count = max(1, len(catalog.forms.get(sid, ())))
        identities = retained_forms.get(sid, [spec['row_id']])
        if (not isinstance(identities, list) or len(identities) != count or identities[0] != spec['row_id']
                or any(type(number) is not int or number not in stat_ids for number in identities)):
            raise ValueError('a reviewed explicit local binding is required for every form')
        references[sid] = list(identities)
    client_refs = {'schemaVersion': 1, 'students': references, 'provenance': {
        'primary': 'explicit approved crosswalk', 'crosswalk_sha256': digest(crosswalk),
        'secondary_forms': 'retained explicit local bindings, verified present in the pinned stat catalog',
        'form_bindings_sha256': digest(form_bindings) if form_bindings is not None else None}}
    retained = {}
    frozen_catalog_sha = digest(catalog.to_payload())
    for sid, record in catalog.students.items():
        for field in record:
            path = f'students.{sid}.{field}'
            if path not in field_sources:
                retained[path] = {'source': 'retained-local', 'frozen_catalog_sha256': frozen_catalog_sha}
    provenance = {'schemaVersion': 1, 'tool': 'metadata-store-regenerate-v1',
        'lock_sha256': digest(reader.lock), 'frozen_catalog_sha256': frozen_catalog_sha,
        'crosswalk_sha256': digest(crosswalk), 'projected_fields': field_sources,
        'retained_fields': retained,
        'retained_sections': ['forms', 'server_availability', 'favorite_items', 'provider_refs'],
        'notes': ['Provider references are retained compatibility data until the paired removal slice.',
                  'Provisional ConstCommon fields are not consumed; current local affinity rule is unchanged.']}
    return {'catalog': validated, 'gifts': generated_gifts, 'stats': stats,
            'frozen_exp': deepcopy(frozen_exp),
            'client_refs': client_refs,
            'provenance': provenance, 'raw_gift_tag_changes': raw_tag_changes}


def load_frozen_gifts(source_path, frozen_exp):
    raw = Path(source_path).read_bytes()
    module = ast.parse(raw.decode('utf-8-sig'))
    assignments = [node for node in module.body if isinstance(node, ast.AnnAssign)
                   and isinstance(node.target, ast.Name) and node.target.id == 'GIFT_ITEMS']
    if len(assignments) != 1:
        raise ValueError('expected one literal GIFT_ITEMS declaration')
    gifts = ast.literal_eval(assignments[0].value)
    if not isinstance(gifts, dict) or any(type(gid) is not int for gid in gifts):
        raise ValueError('invalid frozen gift identities')
    frozen = frozen_exp.get('gifts', {})
    if (set(frozen) != {str(gid) for gid in gifts}
            or any(not isinstance(gift, dict) or gift.get('id') != gid
                   or type(gift.get('exp_value')) is not int
                   or gift['exp_value'] != frozen[str(gid)]['exp_value'] for gid, gift in gifts.items())):
        raise ValueError('gift experience differs from the approved frozen snapshot')
    # sourceFileSha256 records the original freeze's provenance. A generated
    # declaration can have reviewed new tags/formatting; its 52 experience
    # values still have to match that immutable approved snapshot exactly.
    return gifts


def render_student_source(catalog):
    values = [('FAVORITE_ITEM_STUDENT_IDS', 'frozenset[str]', catalog.favorite_item_student_ids),
              ('FAVORITE_ITEM_MAX_TIER', 'str', catalog.favorite_item_max_tier),
              ('JP_ONLY_STUDENT_IDS', 'frozenset[str]', catalog.jp_only_student_ids),
              ('MULTI_FORM_STUDENTS', 'dict[str, tuple[StudentFormMeta, ...]]', catalog.forms),
              ('STUDENTS', 'dict[str, StudentMeta]', catalog.legacy_students())]
    source = ('"""Generated by tools/export_canonical_metadata.py from reviewed store and retained local inputs."""\n'
              'from __future__ import annotations\n'
              'from core.student_meta_types import StudentFormMeta, StudentMeta\n\n')
    for name, annotation, value in values:
        rendered = ('frozenset(' + repr(sorted(value)) + ')' if isinstance(value, frozenset)
                    else pprint.pformat(value, width=100, sort_dicts=False))
        source += f'{name}: {annotation} = {rendered}\n\n'
    ast.parse(source)
    return source.rstrip() + '\n'


def render_gift_source(gifts):
    source = ('"""Generated gift metadata from reviewed JP tags and approved frozen experience."""\n'
              'from __future__ import annotations\nfrom typing import TypedDict\n\n'
              'class GiftMeta(TypedDict):\n    id: int\n    category: str\n'
              '    tags: list[str]\n    exp_value: int\n\n'
              'GIFT_ITEMS: dict[int, GiftMeta] = ' + pprint.pformat(gifts, width=100, sort_dicts=False) + '\n')
    ast.parse(source)
    return source


def bundle_outputs(result):
    encode = lambda value: (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode('utf-8')
    return {'data/metadata/v1/student_catalog.json': encode(result['catalog'].to_payload()),
            'data/metadata/v1/client-character-refs.json': encode(result['client_refs']),
            'data/metadata/v1/gift-exp-frozen-v1.json': encode(result['frozen_exp']),
            'data/metadata/v1/store-provenance.json': encode(result['provenance']),
            'core/student_meta_data.py': render_student_source(result['catalog']).encode('utf-8'),
            'core/gift_meta_data.py': render_gift_source(result['gifts']).encode('utf-8'),
            **{'data/student_stats/v1/' + name: raw for name, raw in result['stats'].items()}}


def write_bundle(result, directory, *, forbidden_roots=()):
    """Write only into a new staging directory; publish after independent checks."""
    directory = Path(directory).resolve()
    if directory.exists() or any(directory == Path(root).resolve() or directory.is_relative_to(Path(root).resolve())
                                 for root in forbidden_roots):
        raise ValueError('generation needs a fresh staging directory outside protected inputs')
    outputs = bundle_outputs(result)  # Validate/serialize all outputs before creating anything.
    directory.mkdir(parents=True)
    for relative, raw in outputs.items():
        target = directory / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    return {name: {'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}
            for name, raw in outputs.items()}

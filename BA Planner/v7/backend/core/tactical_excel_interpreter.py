"""FB7 explicit spreadsheet interpretation; no repository writes or fuzzy approval."""
from __future__ import annotations

from collections import defaultdict
from copy import deepcopy
from datetime import date, datetime, time, timedelta, timezone
from difflib import SequenceMatcher
import hashlib
import re
from typing import Any

from core import student_meta
from core.repository_dto import canonical_json
from core.repository_store import RepositoryError
from core.tactical_fb6 import canonical_deck, deck_identity, legacy_date
from core.tactical_fb6_store import request_match
from core.tactical_excel_reader import RawCell, SourceDocument


SCALARS = ('date', 'kind', 'opponent', 'season', 'result', 'attempts', 'notes')
SLOTS = tuple(f'{side}_{role}_{position}' for side in ('own', 'opponent')
              for role, count in (('striker', 4), ('special', 2))
              for position in range(1, count + 1))
FIELDS = frozenset((*SCALARS, *SLOTS))
REQUIRED = frozenset(('date', 'kind', 'opponent', 'result', 'attempts'))
HEADERS = {
    'date': ('date', 'datetime', '날짜', '일시'), 'kind': ('kind', '공방', '구분'),
    'opponent': ('opponent', '상대', '상대이름'), 'season': ('season', '시즌'),
    'result': ('result', '결과', '승패'), 'attempts': ('attempts', '시도', '시도횟수'),
    'notes': ('notes', '메모', '비고'),
}
KINDS = {'attack': 'attack', 'defense': 'defense', '공격': 'attack', '방어': 'defense'}
RESULTS = {'win': 'win', 'loss': 'loss', '승': 'win', '패': 'loss', '승리': 'win', '패배': 'loss'}


def invalid(message: str) -> None:
    raise RepositoryError('invalid_payload', message)


def digest(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode('utf-8')).hexdigest()


def raw_value(value: Any) -> Any:
    if isinstance(value, (date, datetime, time)):
        return value.isoformat()
    if isinstance(value, timedelta):
        return str(value)
    return value


def raw_key(value: Any) -> str:
    # Preserve type and exact spelling. Normalized suggestions cannot approve a rule.
    return canonical_json({'type': type(value).__name__, 'value': raw_value(value)})


def row_id(document: SourceDocument, number: int) -> str:
    return 'excel-row-' + digest([document.fingerprint, document.selected_sheet, number])[:32]


def catalog_context(owned: set[str], opponents: list[dict], matches: list[dict]) -> dict:
    students = {sid: {'name': student_meta.display_name(sid), 'role': student_meta.combat_class(sid)}
                for sid in sorted(student_meta.STUDENTS)}
    return {'students': students, 'owned': sorted(owned), 'opponents': deepcopy(opponents),
            'matches': deepcopy(matches), 'catalog_fingerprint': digest(students)}


def mapping_candidates(document: SourceDocument) -> list[dict]:
    candidates = []
    for row in document.rows[:20]:
        columns = {}
        ambiguous = []
        for field in FIELDS:
            names = HEADERS.get(field, (field,))
            found = [cell.column for cell in row if isinstance(cell.value, str)
                     and re.sub(r'\s+', '', cell.value).casefold() in names]
            if len(found) == 1:
                columns[field] = found[0]
            elif len(found) > 1:
                ambiguous.append(field)
        if len(columns.keys() & REQUIRED) >= 3:
            candidates.append({'header_row': row[0].row, 'columns': columns,
                               'ambiguous_fields': sorted(ambiguous), 'requires_confirmation': True})
    return candidates


def validate_mapping(mapping: Any) -> dict:
    if not isinstance(mapping, dict) or set(mapping) != {'header_row', 'columns'}:
        invalid('column_mapping requires header_row and columns')
    header, columns = mapping['header_row'], mapping['columns']
    if type(header) is not int or not 1 <= header <= 10_000:
        invalid('header_row must be an explicit one-based row')
    if not isinstance(columns, dict) or not REQUIRED <= columns.keys() or not columns.keys() <= FIELDS:
        invalid('column_mapping has missing required or unknown fields')
    if any(type(c) is not int or not 1 <= c <= 64 for c in columns.values()):
        invalid('columns must be one-based bounded integers')
    if len(set(columns.values())) != len(columns):
        invalid('each semantic field must use its own column')
    return deepcopy(mapping)


def validate_resolutions(resolutions: Any) -> list[dict]:
    if not isinstance(resolutions, list) or len(resolutions) > 4096:
        invalid('resolutions must be a bounded list')
    result, seen = [], set()
    for item in resolutions:
        if not isinstance(item, dict) or set(item) not in (
            {'field', 'raw', 'action', 'value'}, {'row', 'field', 'raw', 'action', 'value'}):
            invalid('resolution requires field/raw/action/value and optional row')
        field, action = item['field'], item['action']
        if not isinstance(field, str) or not isinstance(action, str) or field not in FIELDS or action not in {'value', 'wildcard', 'notes', 'ignore', 'skip'}:
            invalid('resolution field/action is invalid')
        if 'row' in item and (type(item['row']) is not int or not 1 <= item['row'] <= 10_000):
            invalid('resolution row is invalid')
        if not isinstance(item['raw'], str) or len(item['raw'].encode('utf-8')) > 8192:
            invalid('resolution raw must be the typed raw key from preview')
        if action == 'wildcard' and field not in SLOTS:
            invalid('wildcard is only an explicit student slot resolution')
        if action != 'value' and item['value'] is not None:
            invalid('non-value actions require null value')
        identity = (item.get('row'), field, item['raw'])
        if identity in seen:
            invalid('duplicate resolution')
        seen.add(identity)
        result.append(deepcopy(item))
    return result


def validate_rules(rules: Any) -> dict:
    if rules is None:
        return {'version': 1, 'revision': 0, 'column_mapping': None, 'resolutions': []}
    if not isinstance(rules, dict) or set(rules) != {'version', 'revision', 'column_mapping', 'resolutions'}:
        invalid('private Excel rules shape is invalid')
    if type(rules['version']) is not int or rules['version'] != 1 or type(rules['revision']) is not int or rules['revision'] < 0:
        invalid('private Excel rule version/revision is invalid')
    if rules['column_mapping'] is not None:
        validate_mapping(rules['column_mapping'])
    resolutions = validate_resolutions(rules['resolutions'])
    if any('row' in r or r['action'] == 'skip' for r in resolutions):
        invalid('saved rules cannot retain source rows or row-skip decisions')
    return deepcopy(rules)


def _slot(position: int, sid: str | None = None, *, wildcard: bool = False) -> dict:
    return {'version': 2, 'position': position, 'student_id': sid,
            'state': 'manual' if sid else 'unknown', 'source': 'manual', 'confidence': None,
            'review_status': 'confirmed' if sid or wildcard else 'unreviewed', 'wildcard': wildcard}


def _date_value(value: Any, cell: RawCell) -> dict:
    if isinstance(value, datetime):
        if value.tzinfo is not None:
            return {'occurred_at': value.astimezone(timezone.utc).isoformat(), 'occurred_precision': 'instant'}
        # Workbook dates have no timezone. Only an explicitly date-formatted midnight is date precision.
        from openpyxl.styles.numbers import is_datetime
        if value.time().isoformat() == '00:00:00' and is_datetime(cell.number_format or '') == 'date':
            return legacy_date(value.date().isoformat())
        raise ValueError('timezone_required')
    if isinstance(value, date):
        return legacy_date(value.isoformat())
    if not isinstance(value, str):
        raise ValueError('date_required')
    text = value.strip()
    if re.fullmatch(r'\d{4}-\d{2}-\d{2}', text):
        return legacy_date(text)
    try:
        parsed = datetime.fromisoformat(text.replace('Z', '+00:00'))
    except ValueError as error:
        raise ValueError('date_invalid') from error
    if parsed.tzinfo is None:
        raise ValueError('timezone_required')
    return {'occurred_at': parsed.astimezone(timezone.utc).isoformat(), 'occurred_precision': 'instant'}


def _suggest_students(text: str, role: str, context: dict) -> list[dict]:
    ranks = [(SequenceMatcher(None, text, item['name']).ratio(), sid, item['name'])
             for sid, item in context['students'].items() if item['role'] == role]
    return [{'student_id': sid, 'display_name': name, 'score': round(score, 4), 'requires_confirmation': True}
            for score, sid, name in sorted(ranks, key=lambda r: (-r[0], r[1]))[:3] if score >= .35]


def _student(value: Any, role: str, context: dict) -> str | None:
    if value in (None, ''):
        return None
    if not isinstance(value, str):
        raise ValueError('student_unknown')
    text = value.strip()
    if text in context['students']:
        sid = text
    else:
        matches = [sid for sid, item in context['students'].items() if item['name'] == text]
        if len(matches) != 1:
            raise ValueError('student_unknown' if not matches else 'student_ambiguous')
        sid = matches[0]
    if context['students'][sid]['role'] != role:
        raise ValueError('student_role_mismatch')
    return sid


def _opponent(value: Any, context: dict) -> dict:
    if isinstance(value, dict) and set(value) == {'identity_id', 'display_name'}:
        identity, name = value['identity_id'], value['display_name']
        if not isinstance(identity, str) or re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,63}', identity) is None:
            raise ValueError('opponent_identity_invalid')
        if not isinstance(name, str) or not name.strip() or len(name) > 4096:
            raise ValueError('opponent_name_required')
        old = next((o for o in context['opponents'] if o['identity_id'] == identity), None)
        if old and name not in {old['current_display_name'], *old['aliases']}:
            raise ValueError('opponent_alias_required')
        return {'opponent_identity_id': identity, 'opponent_display_name': name}
    if isinstance(value, str):
        old = next((o for o in context['opponents'] if o['identity_id'] == value), None)
        if old:
            return {'opponent_identity_id': value, 'opponent_display_name': old['current_display_name']}
    raise ValueError('opponent_resolution_required')


def semantic_key(item: dict) -> tuple:
    return (item['kind'], item['occurred_at'], item['occurred_precision'], item['opponent_identity_id'],
            item['season'], deck_identity(item['attack_deck']), deck_identity(item['defense_deck']))


def _coarse(item: dict) -> bool:
    return item['occurred_precision'] != 'instant' or any(
        s['student_id'] is None for key in ('attack_deck', 'defense_deck')
        for role in ('strikers', 'specials') for s in item[key][role])


def _potential(left: dict, right: dict) -> bool:
    if semantic_key(left) == semantic_key(right):
        return True
    if not (_coarse(left) or _coarse(right)):
        return False
    if (left['kind'], left['opponent_identity_id'], left['season']) != (right['kind'], right['opponent_identity_id'], right['season']):
        return False
    def day(item):
        value = item['occurred_at']
        return datetime.fromisoformat(value).astimezone(timezone(timedelta(hours=9))).date() if value else None
    if day(left) != day(right):
        return False
    for field in ('attack_deck', 'defense_deck'):
        for a, b in zip(deck_identity(left[field]), deck_identity(right[field])):
            if a not in ('?', '*') and b not in ('?', '*') and a != b:
                return False
    return True


def _decisions(decisions: Any) -> dict[int, dict]:
    if not isinstance(decisions, list) or len(decisions) > 10_000:
        invalid('row_decisions must be a bounded list')
    result = {}
    for item in decisions:
        if not isinstance(item, dict) or set(item) != {'row', 'action', 'target_match_id'}:
            invalid('row decision requires row/action/target_match_id')
        row, action, target = item['row'], item['action'], item['target_match_id']
        if type(row) is not int or not 1 <= row <= 10_000 or row in result:
            invalid('row decision row is invalid/duplicated')
        if not isinstance(action, str) or action not in {'skip', 'keep_separate', 'overwrite'}:
            invalid('row decision action is invalid')
        if (action == 'overwrite') != (isinstance(target, str) and bool(target)) or (action != 'overwrite' and target is not None):
            invalid('only overwrite requires an explicit target match ID')
        result[row] = deepcopy(item)
    return result


def interpret(document: SourceDocument, context: dict, *, column_mapping: dict | None,
              resolutions: list[dict], row_decisions: list[dict], rules: dict | None = None,
              on_conflict: str = 'skip') -> dict:
    if not isinstance(on_conflict, str) or on_conflict not in {'skip', 'overwrite'}:
        invalid('on_conflict must be skip or overwrite')
    rules = validate_rules(rules)
    resolutions = validate_resolutions(resolutions)
    decisions = _decisions(row_decisions)
    mapping = validate_mapping(column_mapping) if column_mapping is not None else None
    result = {'fingerprint': document.fingerprint, 'format': document.format,
              'sheet_names': list(document.sheet_names), 'selected_sheet': document.selected_sheet,
              'mapping_candidates': mapping_candidates(document), 'saved_mapping': rules['column_mapping'],
              'column_mapping': mapping, 'rows': [], 'string_groups': [], 'conflicts': [],
              'summary': {'read_rows': 0, 'empty_rows': 0, 'skipped_rows': 0, 'parsed_rows': 0,
                          'unresolved_rows': 0, 'conflict_rows': 0, 'eligible_rows': 0},
              'issues': []}
    result['interpretation_fingerprint'] = digest({'file': document.fingerprint, 'sheet': document.selected_sheet,
        'mapping': mapping, 'resolutions': resolutions, 'row_decisions': row_decisions,
        'rules': rules, 'context': context, 'on_conflict': on_conflict})
    if mapping is None:
        result['issues'].append({'code': 'mapping_confirmation_required'})
        return result
    if not any(row and row[0].row == mapping['header_row'] for row in document.rows):
        invalid('header_row is outside the source')
    explicit = {(r.get('row'), r['field'], r['raw']): r for r in resolutions}
    saved = {(None, r['field'], r['raw']): r for r in rules['resolutions']}
    groups = defaultdict(lambda: {'raw': None, 'places': [], 'suggestions': []})
    prospective_opponents = {o['identity_id']: {o['current_display_name'], *o['aliases']} for o in context['opponents']}
    consumed_resolutions, consumed_decisions = set(), set()
    for cells in document.rows:
        if not cells or cells[0].row <= mapping['header_row']:
            continue
        number = cells[0].row
        result['summary']['read_rows'] += 1
        row = {'row_id': row_id(document, number), 'row_number': number, 'raw_cells': [],
               'status': 'unresolved', 'issues': [], 'match': None, 'target_match_id': None}
        result['rows'].append(row)
        if number in decisions:
            consumed_decisions.add(number)
        decision = decisions.get(number)
        if all(c.value in (None, '') for c in cells):
            row['status'] = 'empty'
            result['summary']['empty_rows'] += 1
            continue
        if decision and decision['action'] == 'skip':
            row['status'] = 'skipped'
            result['summary']['skipped_rows'] += 1
            continue
        parsed = {'season': '', 'notes': ''}
        decks = {side: {'version': 2, 'strikers': [_slot(i) for i in range(4)],
                         'specials': [_slot(i) for i in range(2)]} for side in ('own', 'opponent')}
        extra_notes = []
        skip = False
        for field in (*SCALARS, *SLOTS):
            column = mapping['columns'].get(field)
            cell = next((c for c in cells if c.column == column), RawCell(number, column or 0, None, 'n'))
            raw, key = cell.value, raw_key(cell.value)
            row['raw_cells'].append({'field': field, 'column': column, 'raw': raw_value(raw),
                                     'raw_key': key, 'formula': cell.formula,
                                     'cached_value': raw_value(cell.cached_value)})
            rid = (number, field, key) if (number, field, key) in explicit else (None, field, key)
            resolution = explicit.get(rid) or saved.get((None, field, key))
            if rid in explicit:
                consumed_resolutions.add(rid)
            value = raw
            wildcard = False
            code = None
            suggestions = []
            if resolution:
                action = resolution['action']
                if action == 'skip':
                    skip = True
                    continue
                if action == 'value':
                    value = resolution['value']
                else:
                    value = None
                    wildcard = action == 'wildcard'
                    if action == 'notes' and raw not in (None, ''):
                        extra_notes.append(str(raw_value(raw)))
            elif cell.formula:
                # Cached scalars do not bypass explicit acceptance of a formula.
                code = 'formula_acceptance_required' if cell.cached_value is not None else 'formula_cache_missing'
                value = None
            try:
                if code:
                    raise ValueError(code)
                if resolution and rid not in explicit and field == 'opponent':
                    identity = value.get('identity_id') if isinstance(value, dict) else value
                    if identity not in {o['identity_id'] for o in context['opponents']}:
                        raise ValueError('saved_opponent_identity_missing')
                if field in SLOTS:
                    side, role, position = field.split('_')
                    sid = _student(value, role, context)
                    decks[side][role + 's'][int(position) - 1] = _slot(int(position) - 1, sid, wildcard=wildcard)
                elif field == 'date':
                    parsed.update(_date_value(value, cell))
                elif field == 'kind':
                    if not isinstance(value, str) or value.strip().casefold() not in KINDS:
                        raise ValueError('kind_required')
                    parsed['kind'] = KINDS[value.strip().casefold()]
                elif field == 'opponent':
                    parsed.update(_opponent(value, context))
                elif field == 'result':
                    if not isinstance(value, str) or value.strip().casefold() not in RESULTS:
                        if isinstance(value, str) and re.fullmatch(r'승\s*\(\s*([1-9]\d*)\s*트\s*\)', value.strip()):
                            suggestions = [{'result': 'win', 'attempt_count': int(re.search(r'\d+', value).group()), 'requires_confirmation': True}]
                        raise ValueError('result_resolution_required')
                    parsed['result'] = RESULTS[value.strip().casefold()]
                elif field == 'attempts':
                    if isinstance(value, str) and re.fullmatch(r'[1-9]\d*', value.strip()):
                        value = int(value.strip())
                    if type(value) is not int or value < 1:
                        raise ValueError('positive_attempts_required')
                    parsed['attempt_count'] = value
                else:
                    if value is None:
                        value = ''
                    if not isinstance(value, str):
                        raise ValueError('text_required')
                    parsed[field] = value
            except (ValueError, RepositoryError) as error:
                code = str(error) if isinstance(error, ValueError) else 'date_invalid'
                if field in SLOTS and isinstance(raw, str):
                    suggestions = _suggest_students(raw, field.split('_')[1], context)
                if field == 'opponent' and isinstance(raw, str):
                    suggestions = [{'identity_id': o['identity_id'], 'display_name': o['current_display_name'],
                                    'requires_confirmation': True} for o in context['opponents']
                                   if raw == o['current_display_name'] or raw in o['aliases']]
                issue = {'field': field, 'column': column, 'code': code, 'raw_key': key,
                         'raw': raw_value(raw), 'from_saved_rule': resolution is not None and rid not in explicit}
                row['issues'].append(issue)
                group = groups[(field, key, code)]
                group['raw'] = raw_value(raw)
                group['places'].append({'row': number, 'column': column})
                group['suggestions'] = suggestions
        if skip:
            row['status'] = 'skipped'
            row['issues'] = []
            result['summary']['skipped_rows'] += 1
            for group in groups.values():
                group['places'] = [p for p in group['places'] if p['row'] != number]
            continue
        if extra_notes:
            parsed['notes'] = '\n'.join(filter(None, (parsed['notes'], *extra_notes)))
        if not row['issues']:
            identity, name = parsed['opponent_identity_id'], parsed['opponent_display_name']
            if identity in prospective_opponents and name not in prospective_opponents[identity]:
                row['issues'].append({'field': 'opponent', 'column': mapping['columns']['opponent'],
                    'code': 'opponent_alias_required', 'raw_key': None, 'raw': name,
                    'from_saved_rule': False})
            else:
                prospective_opponents.setdefault(identity, {name})
        if not row['issues']:
            own_key = 'attack_deck' if parsed['kind'] == 'attack' else 'defense_deck'
            rival_key = 'defense_deck' if parsed['kind'] == 'attack' else 'attack_deck'
            item = {'version': 2, 'match_id': 'excel-match-' + digest(row['row_id'])[:32], **parsed,
                    own_key: decks['own'], rival_key: decks['opponent']}
            try:
                item = request_match(item)
                canonical_deck(item[own_key], owned=set(context['owned']))
                row['match'] = item
                row['status'] = 'eligible'
                result['summary']['parsed_rows'] += 1
            except RepositoryError as error:
                row['issues'].append({'field': 'deck', 'column': None, 'code': error.code, 'raw_key': None,
                                      'raw': None, 'message': str(error), 'from_saved_rule': False})
        if row['issues']:
            result['summary']['unresolved_rows'] += 1
    if consumed_resolutions != set(explicit) or consumed_decisions != set(decisions):
        invalid('resolution/row decision does not match an actual data cell or row')
    for (field, key, code), group in sorted(groups.items()):
        if not group['places']:
            continue
        result['string_groups'].append({'group_id': 'excel-group-' + digest([field, key, code])[:32],
            'field': field, 'raw_key': key, 'code': code, 'count': len(group['places']), **group})
    eligible = [r for r in result['rows'] if r['match'] is not None]
    for row in eligible:
        item = row['match']
        existing = [m for m in context['matches'] if _potential(item, m)]
        peers = [other['row_number'] for other in eligible if other is not row and _potential(item, other['match'])]
        replay = next((m for m in context['matches'] if m.get('source_record_id') == row['row_id']), None)
        prior_source = context.get('source_rows', {}).get(row['row_id'])
        decision = decisions.get(row['row_number'])
        if replay or prior_source:
            row['status'] = 'replay'
            row['target_match_id'] = replay['match_id'] if replay else prior_source
            continue
        if existing or peers:
            result['conflicts'].append({'row_id': row['row_id'], 'row_number': row['row_number'],
                'match_ids': [m['match_id'] for m in existing], 'peer_rows': peers,
                'ambiguous': _coarse(item) or len(existing) > 1 or bool(peers)})
            result['summary']['conflict_rows'] += 1
            if decision and decision['action'] == 'keep_separate':
                pass
            elif decision and decision['action'] == 'overwrite':
                if decision['target_match_id'] not in {m['match_id'] for m in existing}:
                    invalid('overwrite target is not an actual conflicting match')
                row.update(status='overwrite', target_match_id=decision['target_match_id'])
            elif peers:
                row['status'] = 'conflict'
            elif on_conflict == 'skip':
                row['status'] = 'conflict_skipped'
            elif len(existing) == 1 and not _coarse(item):
                row.update(status='overwrite', target_match_id=existing[0]['match_id'])
            else:
                row['status'] = 'conflict'
        elif decision and decision['action'] == 'overwrite':
            invalid('overwrite target requires a matching existing record')
    targets = [r['target_match_id'] for r in eligible if r['status'] == 'overwrite']
    if len(targets) != len(set(targets)):
        invalid('several import rows cannot overwrite the same match')
    result['summary']['eligible_rows'] = sum(r['status'] in {'eligible', 'overwrite'} for r in result['rows'])
    return result

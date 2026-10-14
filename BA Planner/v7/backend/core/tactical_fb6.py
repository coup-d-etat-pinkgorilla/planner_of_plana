"""FB-6 write primitives; no storage side effects or inferred observations."""
from copy import deepcopy
from datetime import date, datetime, timedelta, timezone
import hashlib
import math

from core import student_meta
from core.repository_dto import canonical_json
from core.repository_store import RepositoryError


SLOT_KEYS = {'version', 'position', 'student_id', 'state', 'source', 'confidence', 'review_status', 'wildcard'}
SLOT_STATES = {'unknown', 'empty', 'visible_lobby', 'revealed_after_battle', 'manual', 'community_reported'}
SOURCES = {'v6_import', 'manual', 'lobby_scan', 'battle_result', 'community_report', 'prediction'}
REVIEWS = {'unreviewed', 'review_required', 'confirmed', 'rejected'}


def invalid(message):
    raise RepositoryError('invalid_payload', message)


def canonical_attempt_count(value, *, legacy=False):
    if legacy and value is None:
        return None
    if type(value) is not int or value < 1:
        invalid('attempt_count must be an explicit positive integer')
    return value


def canonical_deck(value, *, owned=None):
    """Validate 4+2 ordered observations without losing unknowns or provenance.

    owned is a frozen confirmed set for new own decks, None for opponent or
    historical decks. Catalog/class/duplicate checks apply in both cases.
    """
    if not isinstance(value, dict) or set(value) != {'version', 'strikers', 'specials'} or type(value['version']) is not int or value['version'] != 2:
        invalid('deck must have the exact version2 shape')
    result = {'version': 2}
    seen = set()
    for role, combat_class, count in (('strikers', 'striker', 4), ('specials', 'special', 2)):
        slots = value[role]
        if not isinstance(slots, list) or len(slots) != count:
            invalid(f'{role} must have exactly {count} slots')
        result[role] = []
        for position, slot in enumerate(slots):
            if not isinstance(slot, dict) or set(slot) != SLOT_KEYS:
                invalid('slot must preserve all version2 observation fields')
            if type(slot['version']) is not int or slot['version'] != 2 or type(slot['position']) is not int or slot['position'] != position:
                invalid('slot version or ordered position is invalid')
            state, sid = slot['state'], slot['student_id']
            if not isinstance(state, str) or state not in SLOT_STATES:
                invalid('slot state is invalid')
            if not isinstance(slot['source'], str) or slot['source'] not in SOURCES or not isinstance(slot['review_status'], str) or slot['review_status'] not in REVIEWS:
                invalid('slot provenance or review status is invalid')
            confidence = slot['confidence']
            if confidence is not None and (type(confidence) not in (int, float) or not math.isfinite(confidence) or not 0 <= confidence <= 1):
                invalid('slot confidence must be finite 0..1 or null')
            if type(slot['wildcard']) is not bool:
                invalid('slot wildcard must be a boolean')
            observed = state not in {'unknown', 'empty'}
            if slot['wildcard'] and (sid is not None or state != 'unknown'):
                invalid('wildcard requires unknown state and no student identity')
            if observed != (sid is not None):
                invalid('slot observation state and student identity disagree')
            if sid is not None:
                if not isinstance(sid, str) or sid not in student_meta.STUDENTS:
                    invalid('slot student must be a canonical catalog identity')
                if student_meta.combat_class(sid) != combat_class:
                    invalid('slot student combat class does not match role')
                if sid in seen:
                    invalid('deck must not contain duplicate student identities')
                if owned is not None and sid not in owned:
                    invalid('own deck student is not confirmed in this profile')
                seen.add(sid)
            result[role].append(deepcopy(slot))
    return result


def deck_identity(deck):
    """Positions matter; wildcard, unknown and confirmed empty stay distinct."""
    return tuple(
        slot['student_id'] if slot['student_id'] is not None else
        '*' if slot['wildcard'] else 'empty' if slot['state'] == 'empty' else '?'
        for role in ('strikers', 'specials') for slot in deck[role]
    )


def lineage_id(defense, attack):
    raw = canonical_json({'defense': deck_identity(defense), 'attack': deck_identity(attack)})
    return 'lineage-' + hashlib.sha256(raw.encode('utf-8')).hexdigest()[:32]


def matches_defense_pattern(pattern, observed):
    """Only an explicitly saved wildcard matches any value; unknown is unknown."""
    left, right = deck_identity(pattern), deck_identity(observed)
    return len(left) == len(right) == 6 and all(a == '*' or a == b for a, b in zip(left, right))


def complete_confirmed_deck(deck):
    return all(slot['student_id'] is not None and not slot['wildcard'] and slot['review_status'] == 'confirmed'
               for role in ('strikers', 'specials') for slot in deck[role])


def legacy_date(value):
    """Keep date precision; midnight is a transport representation, not observation."""
    if value is None:
        return {'occurred_at': None, 'occurred_precision': 'unknown'}
    if not isinstance(value, str):
        invalid('legacy date must be YYYY-MM-DD or null')
    try:
        parsed = date.fromisoformat(value)
    except ValueError:
        invalid('legacy date must be YYYY-MM-DD or null')
    if parsed.isoformat() != value:
        invalid('legacy date must be canonical YYYY-MM-DD')
    return {'occurred_at': datetime(parsed.year, parsed.month, parsed.day, tzinfo=timezone(timedelta(hours=9))).isoformat(), 'occurred_precision': 'date'}


def legacy_deck(value):
    """A v1 null had no wildcard/provenance evidence; preserve it as unknown."""
    if not isinstance(value, dict) or set(value) != {'version', 'strikers', 'specials'} or type(value['version']) is not int or value['version'] != 1:
        invalid('legacy deck must have the exact version1 shape')
    converted = {'version': 2}
    for role, count in (('strikers', 4), ('specials', 2)):
        items = value[role]
        if not isinstance(items, list) or len(items) != count:
            invalid('legacy deck slot count is invalid')
        converted[role] = [
            {'version': 2, 'position': position, 'student_id': sid,
             'state': 'manual' if sid is not None else 'unknown', 'source': 'manual',
             'confidence': None, 'review_status': 'confirmed' if sid is not None else 'unreviewed',
             'wildcard': False}
            for position, sid in enumerate(items)
        ]
    return canonical_deck(converted)

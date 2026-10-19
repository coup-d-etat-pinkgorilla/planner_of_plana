"""Versioned sparse review metadata; quantities and scan history stay separate."""
from __future__ import annotations

from core.current_history import HistoryError
from core.inventory_catalog import canonical_resource_key

MAX_KEYS = 4096


def keys_from_wire(value: object) -> list[str]:
    if not isinstance(value, list) or len(value) > MAX_KEYS:
        raise HistoryError('invalid_inventory_review', 'Review keys must be a bounded array')
    keys = []
    for key in value:
        if not isinstance(key, str):
            raise HistoryError('invalid_inventory_review', 'Review identity must be text')
        try:
            size = len(key.encode('utf-8'))
        except UnicodeEncodeError as error:
            raise HistoryError('invalid_inventory_review', 'Review identity must be UTF-8') from error
        if not 1 <= size <= 1024:
            raise HistoryError('invalid_inventory_review', 'Review identity must be 1..1024 UTF-8 bytes')
        keys.append(canonical_resource_key(key))
    if len(set(keys)) != len(keys):
        raise HistoryError('duplicate_identity', 'Duplicate canonical review identity')
    return sorted(keys)


def from_wire(value: object) -> dict:
    if not isinstance(value, dict) or set(value) != {'version', 'needs_review_keys'}:
        raise HistoryError('invalid_inventory_review', 'Inventory review metadata has an invalid shape')
    if type(value['version']) is not int:
        raise HistoryError('invalid_inventory_review', 'Inventory review version must be an exact integer')
    if value['version'] != 1:
        raise HistoryError('unsupported_version', 'Inventory review version is unsupported')
    keys = keys_from_wire(value['needs_review_keys'])
    if keys != value['needs_review_keys']:
        raise HistoryError('invalid_inventory_review', 'Stored review keys must be sorted canonical identities')
    return {'version': 1, 'needs_review_keys': keys}


def quantity_changes(before: dict, after: dict) -> set[str]:
    old = {row['resource_key']: row['quantity'] for row in before['inventory']}
    new = {row['resource_key']: row['quantity'] for row in after['inventory']}
    missing = object()
    return {key for key in old.keys() | new.keys() if old.get(key, missing) != new.get(key, missing)}


def transition(profile: dict, before: dict, after: dict, *, source: str,
               flat_context: dict | None, history_context, applied_resource_keys: list[str] | None) -> None:
    existing = profile.get('inventory_review')
    pending = set(from_wire(existing)['needs_review_keys']) if existing is not None else set()
    changed = quantity_changes(before, after)
    if source == 'scan':
        applied = set(history_context.to_wire()['applied_scope']['resource_keys'])
        if flat_context is not None:
            excluded = set(flat_context['excluded_keys'])
            if not changed.issubset(applied):
                raise HistoryError('scan_scope_mismatch', 'Scan quantities changed outside applied identities')
            pending.update(excluded)
        pending.difference_update(applied)
    elif source == 'manual':
        # Legacy full-snapshot clients cannot express which unchanged keys the
        # user acknowledged. Only actual quantity changes clear their flags.
        applied = changed if applied_resource_keys is None else set(applied_resource_keys)
        identities = {row['resource_key'] for row in before['inventory'] + after['inventory']}
        if not applied.issubset(identities) or not changed.issubset(applied):
            raise HistoryError('scan_scope_mismatch', 'Manual quantities changed outside explicit applied identities')
        pending.difference_update(applied)
    if existing is not None or pending:
        profile['inventory_review'] = from_wire({'version': 1, 'needs_review_keys': sorted(pending)})

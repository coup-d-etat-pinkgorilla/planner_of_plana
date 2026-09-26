"""Typed scanner context replacing the ``target`` dict with ``_scanner_*`` side keys (C3 X12).

Scanner components read typed fields and derive variants with ``replace``. Capture/input
ports still receive a read-only mapping: the public target keys plus the legacy
``_scanner_*`` view, so the port boundary is the only place those names exist.
"""
from __future__ import annotations

from collections.abc import Iterator, Mapping
from dataclasses import dataclass, field, fields, replace as dataclass_replace
from threading import Event
from typing import Any


# Legacy mapping key -> ScanContext field, for dict targets and the port boundary.
LEGACY_KEYS = {
    "_scanner_cancel": "cancel",
    "_scanner_cleanup": "cleanup",
    "_scanner_scroll_point": "scroll_point",
    "_scanner_session_id": "session_id",
    "_scanner_generation": "generation",
    "_inventory_profile_verified": "inventory_profile_verified",
    "_first_student": "first_student",
    "_seen_students": "seen_students",
}
_FIELD_KEYS = {name: key for key, name in LEGACY_KEYS.items()}


@dataclass(frozen=True, eq=False)
class ScanContext(Mapping[str, Any]):
    """One scan's target plus scanner-owned state. Unset fields are absent from the mapping."""

    target: Mapping[str, Any] = field(default_factory=dict)
    cancel: Event | None = None
    cleanup: bool | None = None
    scroll_point: tuple[float, float] | None = None
    session_id: str | None = None
    generation: int | None = None
    inventory_profile_verified: bool | None = None
    first_student: bool | None = None
    seen_students: tuple[str, ...] | None = None

    @classmethod
    def of(cls, value: Mapping[str, Any] | None) -> "ScanContext":
        """Accept a context unchanged, or split a dict target into public keys and typed fields."""
        if isinstance(value, ScanContext):
            return value
        value = dict(value or {})
        typed = {LEGACY_KEYS[key]: value.pop(key) for key in list(value) if key in LEGACY_KEYS}
        return cls(target=value, **typed)

    def replace(self, **changes: Any) -> "ScanContext":
        """Copy with typed fields changed; unknown names update the public target."""
        typed = {name: value for name, value in changes.items() if name in _FIELD_KEYS}
        public = {name: value for name, value in changes.items() if name not in _FIELD_KEYS}
        if public:
            typed["target"] = {**self.target, **public}
        return dataclass_replace(self, **typed)

    def _legacy_view(self) -> dict[str, Any]:
        return {
            _FIELD_KEYS[item.name]: getattr(self, item.name)
            for item in fields(self)
            if item.name in _FIELD_KEYS and getattr(self, item.name) is not None
        }

    def __getitem__(self, key: str) -> Any:
        name = LEGACY_KEYS.get(key)
        if name is not None:
            value = getattr(self, name)
            if value is None:
                raise KeyError(key)
            return value
        return self.target[key]

    def __iter__(self) -> Iterator[str]:
        yield from self.target
        yield from self._legacy_view()

    def __len__(self) -> int:
        return len(self.target) + len(self._legacy_view())

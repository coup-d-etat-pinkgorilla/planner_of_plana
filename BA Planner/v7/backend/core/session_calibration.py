from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass
from threading import RLock

from PIL import Image

from core.studio_numeric_bank import source_digit_mask


ELIGIBLE_DETAIL_SOURCES = frozenset({"level_tab_template", "equipment_menu_digit"})


@dataclass(frozen=True, slots=True)
class SessionNumericSample:
    sample_id: str
    student_ref: str
    field: str
    roi_name: str
    digit: str
    image: Image.Image
    detail_source: str


class SessionCalibrationStore:
    """Bounded, memory-only automatic samples owned by one scanner session."""

    def __init__(self, session_id: str, generation: int, *, maximum_per_key: int = 4) -> None:
        if not session_id or generation < 1:
            raise ValueError("session_id and positive generation are required")
        self.session_id = session_id
        self.generation = generation
        self.maximum_per_key = maximum_per_key
        self._profile_id: str | None = None
        self._source_size: tuple[int, int] | None = None
        self._samples: dict[
            tuple[str, str, str, str], OrderedDict[str, SessionNumericSample]
        ] = {}
        self._sequence = 0
        self._lock = RLock()

    @property
    def scope(self) -> tuple[str, tuple[int, int]] | None:
        with self._lock:
            if self._profile_id is None or self._source_size is None:
                return None
            return self._profile_id, self._source_size

    @property
    def sample_count(self) -> int:
        with self._lock:
            return sum(len(samples) for samples in self._samples.values())

    def bind_scope(self, profile_id: str | None, source_size: tuple[int, int]) -> bool:
        """Bind actual account/resolution, discarding samples if either changes."""
        valid = (
            isinstance(profile_id, str)
            and bool(profile_id)
            and len(source_size) == 2
            and all(isinstance(value, int) and value > 0 for value in source_size)
        )
        with self._lock:
            if not valid:
                self._discard_locked()
                self._profile_id = None
                self._source_size = None
                return False
            normalized = (int(source_size[0]), int(source_size[1]))
            if self._profile_id is None:
                self._profile_id = profile_id
                self._source_size = normalized
            elif (self._profile_id, self._source_size) != (profile_id, normalized):
                self._discard_locked()
                self._profile_id = profile_id
                self._source_size = normalized
            return True

    def add_numeric(
        self,
        *,
        profile_id: str | None,
        source_size: tuple[int, int],
        student_ref: str,
        field: str,
        value: int,
        cells: tuple[Image.Image, ...] | None,
        roi_names: tuple[str, ...],
        detail_source: str,
        detail_panel_verified: bool,
        value_confirmed: bool,
        conflict: bool,
    ) -> int:
        if (
            not detail_panel_verified
            or not value_confirmed
            or conflict
            or detail_source not in ELIGIBLE_DETAIL_SOURCES
            or not student_ref
            or not field
            or not isinstance(value, int)
            or isinstance(value, bool)
            or value < 0
            or not cells
        ):
            return 0
        digits = str(value)
        if len(cells) < len(digits) or len(roi_names) < len(digits):
            return 0
        with self._lock:
            if not self.bind_scope(profile_id, source_size):
                return 0
            added = 0
            for cell, roi_name, digit in zip(cells, roi_names, digits):
                mask = source_digit_mask(cell, field)
                if mask.getbbox() is None:
                    mask.close()
                    continue
                self._sequence += 1
                sample_id = (
                    f"session:{self.session_id}:{self.generation}:{self._sequence}"
                )
                key = (student_ref, field, roi_name, digit)
                samples = self._samples.setdefault(key, OrderedDict())
                sample = SessionNumericSample(
                    sample_id, student_ref, field, roi_name, digit, mask, detail_source,
                )
                samples[sample_id] = sample
                while len(samples) > self.maximum_per_key:
                    _sample_id, expired = samples.popitem(last=False)
                    expired.image.close()
                added += 1
            return added

    def numeric_samples(
        self,
        *,
        profile_id: str | None,
        source_size: tuple[int, int],
        student_ref: str,
    ) -> tuple[SessionNumericSample, ...]:
        with self._lock:
            if (
                self._profile_id is None
                or (profile_id, tuple(source_size)) != (self._profile_id, self._source_size)
            ):
                return ()
            return tuple(
                sample
                for (sample_student_ref, _field, _roi, _digit), samples in self._samples.items()
                if sample_student_ref == student_ref
                for sample in samples.values()
            )

    def discard(self) -> None:
        with self._lock:
            self._discard_locked()
            self._profile_id = None
            self._source_size = None

    def _discard_locked(self) -> None:
        for samples in self._samples.values():
            for sample in samples.values():
                sample.image.close()
        self._samples.clear()

    def close(self) -> None:
        self.discard()

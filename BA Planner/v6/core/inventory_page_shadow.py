"""Page-level inventory recognition using profile-order joint inference.

The solver itself has no scanner side effects.  It ranks every visible slot
without row anchors and combines those candidates under the profile's monotonic
display order.  The scanner may consume the result in comparison or authoritative
mode.
"""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from time import perf_counter
from typing import Mapping, Sequence

from PIL import Image

from core.inventory_grid_matcher import rank_inventory_grid_templates


@dataclass(frozen=True)
class InventoryShadowCandidate:
    item_id: str
    score: float
    profile_index: int


@dataclass(frozen=True)
class InventoryShadowSlotEvidence:
    slot_index: int
    candidates: tuple[InventoryShadowCandidate, ...]


@dataclass(frozen=True)
class InventoryShadowAssignment:
    slot_index: int
    item_id: str | None
    score: float
    profile_index: int | None


@dataclass(frozen=True)
class InventoryPageShadowResult:
    assignments: tuple[InventoryShadowAssignment, ...]
    worker_count: int
    elapsed_ms: float = 0.0

    def comparison(self, actual_item_ids: Mapping[int, str]) -> dict[str, int]:
        comparable = agreed = disagreed = shadow_only = actual_only = 0
        predicted = {row.slot_index: row.item_id for row in self.assignments}
        for slot_index in sorted(set(predicted) | set(actual_item_ids)):
            shadow_item_id = predicted.get(slot_index)
            actual_item_id = actual_item_ids.get(slot_index)
            if shadow_item_id and actual_item_id:
                comparable += 1
                if shadow_item_id == actual_item_id:
                    agreed += 1
                else:
                    disagreed += 1
            elif shadow_item_id:
                shadow_only += 1
            elif actual_item_id:
                actual_only += 1
        return {
            "comparable": comparable,
            "agreed": agreed,
            "disagreed": disagreed,
            "shadow_only": shadow_only,
            "actual_only": actual_only,
        }


def _crop_normalized(image: Image.Image, region: Mapping[str, float]) -> Image.Image:
    width, height = image.size
    return image.crop(
        (
            round(float(region["x1"]) * width),
            round(float(region["y1"]) * height),
            round(float(region["x2"]) * width),
            round(float(region["y2"]) * height),
        )
    )


def collect_inventory_shadow_evidence(
    image: Image.Image,
    slots: Sequence[Mapping[str, float]],
    catalog: list[tuple[str, str]],
    config: dict,
    ordered_item_ids: Sequence[str | None],
    *,
    scan_indices: set[int] | None = None,
    top_k: int = 4,
    workers: int = 4,
) -> tuple[InventoryShadowSlotEvidence, ...]:
    """Rank slots independently; returned evidence has no scanner side effects."""
    profile_indices = {
        item_id: profile_index
        for profile_index, item_id in enumerate(ordered_item_ids)
        if item_id is not None
    }
    selected = [
        slot_index
        for slot_index in range(len(slots))
        if scan_indices is None or slot_index in scan_indices
    ]

    def rank_slot(slot_index: int) -> InventoryShadowSlotEvidence:
        ranked = rank_inventory_grid_templates(
            _crop_normalized(image, slots[slot_index]),
            catalog,
            config,
            use_tier_hint=True,
        )
        candidates = tuple(
            InventoryShadowCandidate(item_id, float(score), profile_indices[item_id])
            for item_id, score in ranked
            if item_id in profile_indices
        )[: max(1, top_k)]
        return InventoryShadowSlotEvidence(slot_index, candidates)

    worker_count = max(1, min(int(workers), len(selected) or 1))
    if worker_count == 1:
        return tuple(rank_slot(slot_index) for slot_index in selected)
    with ThreadPoolExecutor(max_workers=worker_count, thread_name_prefix="inventory-shadow") as executor:
        return tuple(executor.map(rank_slot, selected))


def solve_inventory_shadow_page(
    evidence: Sequence[InventoryShadowSlotEvidence],
    *,
    min_score: float = 0.55,
) -> tuple[InventoryShadowAssignment, ...]:
    """Choose the best strictly increasing profile-order path.

    An unresolved slot is always available at zero utility. Candidate utility
    starts at ``score - min_score`` so weak visual matches are not manufactured
    into answers merely because they fit the expected order.
    """
    # last profile index -> (utility, assignments)
    states: dict[int, tuple[float, tuple[InventoryShadowAssignment, ...]]] = {-1: (0.0, ())}
    for slot in sorted(evidence, key=lambda row: row.slot_index):
        next_states: dict[int, tuple[float, tuple[InventoryShadowAssignment, ...]]] = {}

        def keep(last_index: int, utility: float, rows: tuple[InventoryShadowAssignment, ...]) -> None:
            previous = next_states.get(last_index)
            if previous is None or utility > previous[0]:
                next_states[last_index] = (utility, rows)

        for last_index, (utility, rows) in states.items():
            keep(
                last_index,
                utility,
                rows + (InventoryShadowAssignment(slot.slot_index, None, 0.0, None),),
            )
            for candidate in slot.candidates:
                if candidate.score < min_score or candidate.profile_index <= last_index:
                    continue
                keep(
                    candidate.profile_index,
                    utility + candidate.score - min_score,
                    rows
                    + (
                        InventoryShadowAssignment(
                            slot.slot_index,
                            candidate.item_id,
                            candidate.score,
                            candidate.profile_index,
                        ),
                    ),
                )
        states = next_states
    return max(states.values(), key=lambda row: row[0])[1] if states else ()


def evaluate_inventory_page_shadow(
    image: Image.Image,
    slots: Sequence[Mapping[str, float]],
    catalog: list[tuple[str, str]],
    config: dict,
    ordered_item_ids: Sequence[str | None],
    *,
    scan_indices: set[int] | None = None,
    top_k: int = 4,
    workers: int = 4,
    min_score: float = 0.55,
) -> InventoryPageShadowResult:
    started = perf_counter()
    evidence = collect_inventory_shadow_evidence(
        image,
        slots,
        catalog,
        config,
        ordered_item_ids,
        scan_indices=scan_indices,
        top_k=top_k,
        workers=workers,
    )
    assignments = solve_inventory_shadow_page(evidence, min_score=min_score)
    return InventoryPageShadowResult(
        assignments,
        max(1, min(int(workers), len(evidence) or 1)),
        (perf_counter() - started) * 1000.0,
    )

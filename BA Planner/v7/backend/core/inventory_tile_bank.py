"""C5e-2 tile bank: grid identity from tiles the detail panel (or the user) already confirmed.

Bundled icon art does not match current-client tiles, but a tile crop confirmed once matches the same
tile in later pages and scans (E2 M4; live 1280 across two scans: 196/196 top-1, margin >= .023).
Entries live for the adapter's session (keyed by client size); only user-approved samples persist (D1).
"""
from __future__ import annotations

from dataclasses import dataclass, field

from PIL import Image

from core import recognition_thresholds as rt
from core.recognition_image_ops import icon_vector_similarity, icon_vectors
from core.recognition_synth import normalize_tile

# Samples kept per identity; later confirmations of an identity add variation (e.g. a selected tile).
MAX_SAMPLES = 3
TIERS = ("synth", "session", "user_confirmed")
# Synthetic tiles use the planner dataset window (card left+2/top+2, 98x91 @720p); a runtime slot crop is the
# 117x95 slot region, so it is cut to that window first. Live: 1 px inset suits items, 2 px equipment (+-1 px
# alignment), so a synthetic entry scores the better of both (C5e-6c).
SYNTH_QUERY_INSETS = ((1, 1, 99, 92), (2, 2, 100, 93))
SLOT_REGION_720 = (117, 95)


@dataclass(frozen=True)
class BankMatch:
    identity: str | None
    score: float
    margin: float
    tier: str | None = None
    ranked: tuple[tuple[str, float], ...] = ()

    @property
    def confident(self) -> bool:
        return (self.identity is not None and self.score >= rt.value("inventory.tile_bank.score")
                and self.margin >= rt.value("inventory.tile_bank.margin"))


@dataclass
class _Entry:
    tier: str
    samples: list[tuple[list[float] | None, ...]] = field(default_factory=list)


def synth_query_vectors(crop: Image.Image) -> list[tuple[list[float] | None, ...]]:
    """Query vectors of a runtime slot crop in the synthetic tiles' window (one per inset)."""
    width, height = crop.size
    vectors = []
    for x1, y1, x2, y2 in SYNTH_QUERY_INSETS:
        box = (round(x1 * width / SLOT_REGION_720[0]), round(y1 * height / SLOT_REGION_720[1]),
               round(x2 * width / SLOT_REGION_720[0]), round(y2 * height / SLOT_REGION_720[1]))
        with crop.crop(box) as window, normalize_tile(window) as normalized:
            vectors.append(icon_vectors(normalized))
    return vectors


def shifted_query_vectors(crop: Image.Image) -> list[tuple[list[float] | None, ...]]:
    """Query vectors of a slot crop moved by up to ``inventory.tile_bank.shift`` px (720p units) each way.

    The same tile read in another scan can sit a pixel off (scroll phase, 95/96 px slot rows); near-identical
    families such as the universal blueprints differ only in a small mark that one pixel of offset erases
    (live 2026-09-28: Charm read as Gloves at .933 vs .897 unshifted, identical at dy=-1).
    """
    reach = round(rt.value("inventory.tile_bank.shift") * crop.height / SLOT_REGION_720[1])
    width, height = crop.size
    vectors = []
    for dy in range(-reach, reach + 1):
        for dx in range(-(reach // 2), reach // 2 + 1):
            if dx == dy == 0:
                continue
            with crop.crop((dx, dy, width + dx, height + dy)) as moved:
                vectors.append(icon_vectors(moved))
    return vectors


class TileBank:
    def __init__(self) -> None:
        self.entries: dict[str, _Entry] = {}
        # Synthetic vectors stay available for drift scoring after a real tier replaces the entry.
        self.synth: dict[str, tuple[list[float] | None, ...]] = {}

    def __len__(self) -> int:
        return len(self.entries)

    def add(self, identity: str, crop: Image.Image, tier: str = "session") -> None:
        if tier not in TIERS[1:]:
            raise ValueError(f"unknown real tile bank tier: {tier}")
        entry = self.entries.get(identity)
        if entry is None or entry.tier == "synth":
            # A real tile of this identity replaces its synthetic entry (C5e-6c: upper tiers exclude synth).
            entry = self.entries[identity] = _Entry(tier)
        elif tier == "user_confirmed" and entry.tier == "session":
            entry = self.entries[identity] = _Entry(tier, entry.samples)
        if len(entry.samples) < MAX_SAMPLES:
            entry.samples.append(icon_vectors(crop))

    def add_synth(self, identity: str, tile: Image.Image) -> None:
        """Lowest tier (C5e-6c): a normalized synthetic tile, used only while no real tile is banked."""
        vectors = icon_vectors(tile)
        self.synth[identity] = vectors
        if identity not in self.entries:
            self.entries[identity] = _Entry("synth", [vectors])

    def synth_score(self, identity: str, crop: Image.Image) -> float | None:
        vectors = self.synth.get(identity)
        if vectors is None:
            return None
        return max(icon_vector_similarity(vectors, query) for query in synth_query_vectors(crop))

    def match(self, crop: Image.Image, candidates=None, vectors=None, allow_synth: bool = True) -> BankMatch:
        """Best identity among candidates (all when None) and its margin over the next identity."""
        query = vectors if vectors is not None else icon_vectors(crop)
        synth_queries = None
        scores = []
        for identity, entry in self.entries.items():
            if candidates is not None and identity not in candidates:
                continue
            if entry.tier == "synth":
                if not allow_synth:
                    continue
                if synth_queries is None:
                    synth_queries = synth_query_vectors(crop)
                scores.append((identity, max(icon_vector_similarity(sample, q) for sample in entry.samples for q in synth_queries)))
                continue
            scores.append((identity, max(icon_vector_similarity(sample, query) for sample in entry.samples)))
        if not scores:
            return BankMatch(None, 0.0, 0.0)
        scores.sort(key=lambda item: item[1], reverse=True)
        # Real-tier contenders near the top are re-scored at small offsets (their best alignment counts).
        window = scores[0][1] - rt.value("inventory.tile_bank.rescore_window")
        contenders = [identity for identity, score in scores if score >= window and self.entries[identity].tier != "synth"]
        if contenders:
            shifted = shifted_query_vectors(crop)
            best = dict(scores)
            for identity in contenders:
                best[identity] = max(best[identity], *(icon_vector_similarity(sample, query)
                                                       for sample in self.entries[identity].samples for query in shifted))
            scores = sorted(best.items(), key=lambda item: item[1], reverse=True)
        best, score = scores[0]
        margin = score - (scores[1][1] if len(scores) > 1 else 0.0)
        return BankMatch(best, score, margin, self.entries[best].tier, tuple(scores[:3]))

    def match_between(self, crop: Image.Image, allowed, order: dict[str, int], low: int | None, high: int | None,
                      allow_synth: bool = True) -> tuple[BankMatch, BankMatch]:
        """Order prior (C5e-2): the unrestricted best and the best among items ordered between the neighbours.

        The sorted list shows items in catalog order, so a slot between two confirmed neighbours can only
        hold an item whose order_index lies strictly between theirs.
        """
        vectors = icon_vectors(crop)
        overall = self.match(crop, allowed, vectors, allow_synth)
        between = {identity for identity in (allowed if allowed is not None else self.entries)
                   if identity in order and (low is None or order[identity] > low) and (high is None or order[identity] < high)}
        return overall, self.match(crop, between, vectors, allow_synth)

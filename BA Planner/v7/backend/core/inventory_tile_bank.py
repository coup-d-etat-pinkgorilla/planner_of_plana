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

# Samples kept per identity; later confirmations of an identity add variation (e.g. a selected tile).
MAX_SAMPLES = 3
TIERS = ("session", "user_confirmed")


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


class TileBank:
    def __init__(self) -> None:
        self.entries: dict[str, _Entry] = {}

    def __len__(self) -> int:
        return len(self.entries)

    def add(self, identity: str, crop: Image.Image, tier: str = "session") -> None:
        if tier not in TIERS:
            raise ValueError(f"unknown tile bank tier: {tier}")
        entry = self.entries.get(identity)
        if entry is None or (tier == "user_confirmed" and entry.tier == "session"):
            entry = self.entries[identity] = _Entry(tier, [] if entry is None else entry.samples)
        if len(entry.samples) < MAX_SAMPLES:
            entry.samples.append(icon_vectors(crop))

    def match(self, crop: Image.Image, candidates=None, vectors=None) -> BankMatch:
        """Best identity among candidates (all when None) and its margin over the next identity."""
        query = vectors if vectors is not None else icon_vectors(crop)
        scores = []
        for identity, entry in self.entries.items():
            if candidates is not None and identity not in candidates:
                continue
            scores.append((identity, max(icon_vector_similarity(sample, query) for sample in entry.samples)))
        if not scores:
            return BankMatch(None, 0.0, 0.0)
        scores.sort(key=lambda item: item[1], reverse=True)
        best, score = scores[0]
        margin = score - (scores[1][1] if len(scores) > 1 else 0.0)
        return BankMatch(best, score, margin, self.entries[best].tier, tuple(scores[:3]))

    def match_between(self, crop: Image.Image, allowed, order: dict[str, int], low: int | None, high: int | None) -> tuple[BankMatch, BankMatch]:
        """Order prior (C5e-2): the unrestricted best and the best among items ordered between the neighbours.

        The sorted list shows items in catalog order, so a slot between two confirmed neighbours can only
        hold an item whose order_index lies strictly between theirs.
        """
        vectors = icon_vectors(crop)
        overall = self.match(crop, allowed, vectors)
        between = {identity for identity in (allowed if allowed is not None else self.entries)
                   if identity in order and (low is None or order[identity] > low) and (high is None or order[identity] < high)}
        return overall, self.match(crop, between, vectors)

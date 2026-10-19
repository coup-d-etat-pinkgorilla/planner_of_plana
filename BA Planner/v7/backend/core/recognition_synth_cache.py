"""C5e-6b: incremental disk cache of synthetic templates and the synth-vs-real drift guard (D19, D25).

Tiles and detail icons are stored once at the normalized size (D25), so the cache is keyed by client and
spec version, not by window size; glyphs depend on the window and are rendered on demand (milliseconds).
Each identity's entry records the tuple of inputs it was made from (icon pixel sha, card sprite pixel sha,
rarity, generator version); a changed tuple, a missing or unreadable file re-synthesizes that identity only.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import json
import os
import zlib
from pathlib import Path
from typing import Any

from PIL import Image

from core import recognition_thresholds as rt
from core.recognition_image_ops import icon_vector_similarity, icon_vectors
from core.recognition_synth import (DETAIL_SIZE, GENERATOR_VERSION, ITEM_CARD_EQUIPMENT, SPEC_VERSION, TILE_SIZE,
                                    SynthTemplateSet, SynthUnavailable, glyph_em_candidates, normalize_tile,
                                    profile_universe, render_glyphs, synthesize, ui_scale)


def _input_key(identity: str, profile: str, manifest: dict[str, Any], rarity: dict[str, Any]) -> str | None:
    table = rarity.get("equipment" if profile == "equipment" else "items", {})
    row = table.get(identity)
    if row is None:
        return None
    blueprint = profile == "equipment" and row.get("category") not in ITEM_CARD_EQUIPMENT
    icon_name = identity + "_Piece" if blueprint and identity + "_Piece" in manifest["icons"] else identity
    icon = manifest["icons"].get(icon_name)
    card = manifest["sprites"].get("Card_Item_Bg_C" if blueprint else f"Card_Item_Bg_{row.get('rarity')}")
    if icon is None or card is None:
        return None
    return "|".join((icon_name, icon["pixel_sha256"], card["pixel_sha256"], str(row.get("rarity")), f"g{GENERATOR_VERSION}"))


class SynthCache:
    """``<root>/<client>/<spec_version>/{pack.bin, index.json}``.

    Images are zlib-compressed raw RGB blobs appended to one pack file, so a cache hit is one file open
    (live: 152 separate PNGs took ~1 s to open on this PC, mostly per-file overhead). Rebuilt entries are
    appended; the pack is rewritten when more than half of it is stale.
    """

    def __init__(self, root: Path, client: str = "kr") -> None:
        self.dir = Path(root) / client / SPEC_VERSION
        self.stats = {"hit": 0, "built": 0, "repaired": 0}

    def _index(self) -> dict[str, Any]:
        try:
            index = json.loads((self.dir / "index.json").read_text(encoding="utf-8"))
            if index.get("generator_version") == GENERATOR_VERSION and (self.dir / "pack.bin").is_file():
                return index
        except (OSError, ValueError):
            pass
        return {"generator_version": GENERATOR_VERSION, "entries": {}}

    @staticmethod
    def _decode(pack: bytes, slot: list[int] | None, size: tuple[int, int]) -> Image.Image | None:
        if not slot:
            return None
        offset, length = slot
        try:
            raw = zlib.decompress(pack[offset:offset + length])
            return Image.frombytes("RGB", size, raw) if len(raw) == size[0] * size[1] * 3 else None
        except (zlib.error, ValueError):
            return None

    def templates(self, assets: Any, rarity: dict[str, Any], *, profile: str, window: tuple[int, int] = (1280, 720),
                  glyph_sizes: tuple[int, ...] | None = None) -> SynthTemplateSet:
        """The profile's synthetic set from the cache, synthesizing only new, changed or damaged identities."""
        manifest = getattr(assets, "manifest", None)
        if not manifest:
            raise SynthUnavailable("no extracted asset cache")
        index = self._index()
        entries = index["entries"]
        try:
            pack = (self.dir / "pack.bin").read_bytes() if entries else b""
        except OSError:
            pack, entries = b"", {}
            index["entries"] = entries
        result = SynthTemplateSet(profile)
        missing = []
        for identity in profile_universe(profile, rarity):
            key = _input_key(identity, profile, manifest, rarity)
            if key is None:
                continue
            entry = entries.get(identity)
            if entry and entry.get("key") == key:
                tile = self._decode(pack, entry.get("tile"), TILE_SIZE)
                detail = self._decode(pack, entry.get("detail"), DETAIL_SIZE)
                if tile is not None and (detail is not None or not entry.get("detail")):
                    result.tiles[identity] = tile
                    if detail is not None:
                        result.details[identity] = detail
                    self.stats["hit"] += 1
                    continue
                self.stats["repaired"] += 1
            missing.append((identity, key))
        if missing:
            built = synthesize(assets, rarity, profile=profile, identities=[identity for identity, _ in missing], glyph_sizes=())
            blobs = bytearray()
            end = len(pack)
            for identity, key in missing:
                entry = {"key": key}
                for kind, images in (("tile", built.tiles), ("detail", built.details)):
                    if identity in images:
                        blob = zlib.compress(images[identity].tobytes(), 1)
                        entry[kind] = [end + len(blobs), len(blob)]
                        blobs += blob
                entries[identity] = entry
                result.tiles[identity] = built.tiles[identity]
                if identity in built.details:
                    result.details[identity] = built.details[identity]
                self.stats["built"] += 1
            self._store(index, pack, bytes(blobs))
        font = assets.font("GyeonggiTitle-Bold")
        for size in glyph_sizes if glyph_sizes is not None else glyph_em_candidates(window):
            if font is None:
                raise SynthUnavailable("count font is missing")
            result.glyphs[size] = render_glyphs(Path(font), size, ui_scale(*window))
        result.fingerprint = "|".join(sorted(entries[i]["key"] for i in result.tiles if i in entries))
        return result

    def _store(self, index: dict[str, Any], pack: bytes, appended: bytes) -> None:
        self.dir.mkdir(parents=True, exist_ok=True)
        live = sum(slot[1] for entry in index["entries"].values() for kind in ("tile", "detail") if (slot := entry.get(kind)))
        total = len(pack) + len(appended)
        if total and live * 2 < total:
            # Compact: keep only live blobs, in index order.
            data = pack + appended
            compacted = bytearray()
            for entry in index["entries"].values():
                for kind in ("tile", "detail"):
                    if slot := entry.get(kind):
                        blob = data[slot[0]:slot[0] + slot[1]]
                        entry[kind] = [len(compacted), len(blob)]
                        compacted += blob
            pack, appended = b"", bytes(compacted)
        temporary = self.dir / "pack.bin.tmp"
        temporary.write_bytes(pack + appended)
        os.replace(temporary, self.dir / "pack.bin")
        temporary = self.dir / "index.json.tmp"
        temporary.write_text(json.dumps(index, ensure_ascii=False, sort_keys=True), encoding="utf-8")
        os.replace(temporary, self.dir / "index.json")


def drift_scores(synth: SynthTemplateSet, confirmed: list[tuple[str, Image.Image]]) -> list[float]:
    """Synthetic M4 score of each detail-confirmed tile against its own synthetic tile."""
    scores = []
    for identity, crop in confirmed:
        tile = synth.tiles.get(identity)
        if tile is not None:
            scores.append(icon_vector_similarity(icon_vectors(normalize_tile(crop)), icon_vectors(tile)))
    return scores


@dataclass
class SynthDriftGuard:
    """Session guard (D19): two scans in a row whose synth p10 falls below the floor disable that profile's tier."""
    low_runs: dict[str, int] = field(default_factory=dict)
    disabled: set[str] = field(default_factory=set)

    def record(self, profile: str, scores: list[float]) -> dict[str, Any]:
        """Evidence ``synth_drift`` for one scan; adds ``synth_drift_detected`` when the tier is switched off."""
        if not scores:
            return {"field": "synth_drift", "status": "uncertain", "source": "synth_bank", "confidence": 0.0,
                    "note": f"profile={profile};n=0"}
        ordered = sorted(scores)
        p10 = ordered[int(len(ordered) * .1)]
        median = ordered[len(ordered) // 2]
        low = p10 < rt.value("inventory.synth.drift_floor")
        self.low_runs[profile] = self.low_runs.get(profile, 0) + 1 if low else 0
        detected = self.low_runs[profile] >= 2 and profile not in self.disabled
        if detected:
            self.disabled.add(profile)
        note = f"profile={profile};n={len(scores)};p10={p10:.3f};median={median:.3f}"
        if detected:
            note += ";synth_drift_detected"
        return {"field": "synth_drift", "status": "uncertain" if low else "ok", "source": "synth_bank",
                "confidence": round(p10, 6), "note": note}

    def enabled(self, profile: str) -> bool:
        return profile not in self.disabled

"""C5e-6c: one scanner session's access to the synthetic tier (extract once, then the incremental cache).

Any failure (no client folder, extraction or synthesis failure) is remembered for the session and reported
as ``SynthUnavailable``; the scan continues without the synthetic tier (detail panel, labeling).
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Callable

from core.recognition_asset_extract import AssetExtractFailed, extract, find_game_dir
from core.recognition_synth import SynthTemplateSet, SynthUnavailable
from core.recognition_synth_cache import SynthCache


class SynthProvider:
    def __init__(self, extracted_root: Path, synth_root: Path, rarity_path: Path,
                 game_dir: Callable[[], Path | None] = find_game_dir,
                 assets_loader: Callable | None = None) -> None:
        self.extracted_root, self.synth_root, self.rarity_path = Path(extracted_root), Path(synth_root), Path(rarity_path)
        self._game_dir = game_dir
        self._assets_loader = assets_loader
        self._assets = None
        self._rarity = None
        self._failure: str | None = None
        self._sets: dict[tuple[str, tuple[int, int]], SynthTemplateSet] = {}

    def __call__(self, profile: str, window: tuple[int, int]) -> SynthTemplateSet:
        if self._failure is not None and self._assets_loader is None:
            raise SynthUnavailable(self._failure)
        key = (profile, tuple(window))
        try:
            if self._assets_loader is not None:
                assets = self._assets_loader()
                if self._assets is None or self._assets.manifest != assets.manifest or self._assets.root != assets.root:
                    self._assets, self._rarity = assets, json.loads(assets.rarity_path.read_text(encoding='utf-8'))
                    self._sets.clear()
                self._failure = None
            if key in self._sets:
                return self._sets[key]
            if self._assets is None:
                game = self._game_dir()
                if game is None:
                    raise SynthUnavailable("game client folder not found")
                self._assets = extract(game, self.extracted_root, self.rarity_path)
                self._rarity = json.loads(self._assets.rarity_path.read_text(encoding="utf-8"))
            templates = SynthCache(self.synth_root).templates(self._assets, self._rarity, profile=profile, window=tuple(window))
        except AssetExtractFailed as exc:
            self._failure = f"asset_extract_failed: {exc.message}"
            raise SynthUnavailable(self._failure) from exc
        except SynthUnavailable as exc:
            self._failure = exc.reason
            raise
        self._sets[key] = templates
        return templates

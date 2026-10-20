"""F2 local derived-cache identity checks, independent of Unity/native imports."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath

from core.recognition_asset_extract import (AssetCache, ATLAS_SPRITES, FONTS,
                                            EXTRACTOR_VERSION, resource_dir)


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open('rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            value.update(block)
    return value.hexdigest()


def game_identity(path: Path | None, source: str) -> dict:
    result = {'path': str(path) if path else None, 'source': source,
              'valid': False, 'reason': 'game_dir_not_found',
              'catalog_sha256': None, 'bundle_revision': None}
    if path is None or not path.is_dir():
        return result
    resources = resource_dir(path)
    if not resources.is_dir():
        result['reason'] = 'not_blue_archive'
        return result
    catalog = resources / 'Catalog/Windows/catalog_Windows.bytes'
    try:
        if not catalog.is_file():
            result['reason'] = 'catalog_missing'
            return result
        with catalog.open('rb') as handle:
            if handle.read(5) != b'CCDB\x01':
                result['reason'] = 'catalog_invalid'
                return result
        result['catalog_sha256'] = digest(catalog)
        revisions = []
        for section in ('Preload', 'Catalog', 'GameData'):
            revision = resources / section / 'BundleRevision'
            if not revision.is_file():
                result['reason'] = 'bundle_revision_missing'
                return result
            if revision.stat().st_size > 128:
                result['reason'] = 'bundle_revision_invalid'
                return result
            text = revision.read_text(encoding='utf-8-sig').strip()
            if not text.isascii() or not text.isdigit():
                result['reason'] = 'bundle_revision_invalid'
                return result
            revisions.append(text)
        if len(set(revisions)) != 1:
            result['reason'] = 'bundle_revision_mismatch'
            return result
        result.update(valid=True, reason=None, bundle_revision=revisions[0])
    except (OSError, UnicodeError, ValueError):
        result['reason'] = 'game_dir_unreadable'
    return result


def cache_counts(manifest: dict) -> dict:
    return {**{key: len(manifest.get(key, {})) for key in ('icons', 'sprites', 'fonts')},
            'failed': len(set(manifest.get('missing', [])))}


def entry_path(root: Path, name: str) -> Path:
    if not isinstance(name, str) or '\\' in name or ':' in name:
        raise ValueError('invalid cache member path')
    parts = name.split('/')
    if PurePosixPath(name).is_absolute() or any(p in ('', '.', '..') for p in parts):
        raise ValueError('invalid cache member path')
    path = root.joinpath(*parts)
    if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
        raise ValueError('cache member escaped its root')
    return path


def validated_cache(root: Path, catalog_sha: str, rarity_path: Path,
                    bundle_revision: str | None) -> AssetCache | None:
    """Never trust only manifest existence or the catalog-named directory."""
    try:
        if root.is_symlink():
            return None
        manifest = json.loads((root/'manifest.json').read_text(encoding='utf-8'))
        if (manifest.get('extractor_version') != EXTRACTOR_VERSION
                or manifest.get('catalog_sha256') != catalog_sha
                or manifest.get('bundle_revision') != bundle_revision
                or manifest.get('rarity_sha256') != digest(rarity_path)
                or digest(root/'item-rarity.json') != manifest['rarity_sha256']):
            return None
        if not manifest.get('icons') or not set((*ATLAS_SPRITES, 'Card_Item_Bg_C')).issubset(manifest.get('sprites', {})):
            return None
        if not set(FONTS).issubset(manifest.get('fonts', {})):
            return None
        for section in ('icons', 'sprites', 'fonts'):
            for entry in manifest[section].values():
                path = entry_path(root, entry['path'])
                if digest(path) != entry['sha256']:
                    return None
        cache_counts(manifest)
        return AssetCache(root, manifest)
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return None

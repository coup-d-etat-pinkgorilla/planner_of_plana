"""Shared helpers for ba-client-data tools (stdlib only; read-only on game files).

Independent implementations of public algorithms: xxHash64 (for JP TableBundles names),
streaming SHA-256, canonical JSON hashing. Nothing here modifies a game file.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

_M64 = (1 << 64) - 1
_Q = (11400714785074694791, 14029467366897019727, 1609587929392839161,
      9650029242287828579, 2870177450012600261)


def _rot64(x, r):
    return ((x << r) | (x >> (64 - r))) & _M64


def _round64(a, i):
    return (_rot64((a + i * _Q[1]) & _M64, 31) * _Q[0]) & _M64


def xxh64(data, seed=0):
    if isinstance(data, str):
        data = data.encode()
    P1, P2, P3, P4, P5 = _Q
    n, i = len(data), 0
    if n >= 32:
        v = [(seed + P1 + P2) & _M64, (seed + P2) & _M64, seed, (seed - P1) & _M64]
        while i <= n - 32:
            for k in range(4):
                v[k] = _round64(v[k], int.from_bytes(data[i:i + 8], 'little')); i += 8
        h = (_rot64(v[0], 1) + _rot64(v[1], 7) + _rot64(v[2], 12) + _rot64(v[3], 18)) & _M64
        for k in range(4):
            h ^= _round64(0, v[k]); h = (h * P1 + P4) & _M64
    else:
        h = (seed + P5) & _M64
    h = (h + n) & _M64
    while i <= n - 8:
        h ^= _round64(0, int.from_bytes(data[i:i + 8], 'little')); h = (_rot64(h, 27) * P1 + P4) & _M64; i += 8
    if i <= n - 4:
        h ^= (int.from_bytes(data[i:i + 4], 'little') * P1) & _M64; h = (_rot64(h, 23) * P2 + P3) & _M64; i += 4
    while i < n:
        h ^= (data[i] * P5) & _M64; h = (_rot64(h, 11) * P1) & _M64; i += 1
    h ^= h >> 33; h = (h * P2) & _M64; h ^= h >> 29; h = (h * P3) & _M64; h ^= h >> 32
    return h


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json(value) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')


def write_json(path: Path, value, *, overwrite=False):
    path = Path(path)
    data = json.dumps(value, ensure_ascii=False, indent=2) + '\n'
    if path.exists() and not overwrite:
        if path.read_text(encoding='utf-8') == data:
            return False
        raise FileExistsError(f'{path} exists with different content (store entries are immutable)')
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(data)
    return True


def read_json(path: Path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def jp_bundle_path(table_dir: Path, original_name: str) -> Path:
    """JP PC client stores TableBundles as '<xxh64(lowercase name)>_<crc32>'."""
    prefix = f'{xxh64(original_name.lower())}_'
    hits = [n for n in os.listdir(table_dir) if n.startswith(prefix)]
    if len(hits) != 1:
        raise FileNotFoundError(f'{original_name}: {hits}')
    return table_dir / hits[0]


def store_root(arg: str | None) -> Path:
    root = Path(arg or os.environ.get('BA_CLIENT_DATA') or Path.home() / 'ba-client-data').resolve()
    if not (root / 'README.md').exists():
        raise SystemExit(f'store root not found (no README.md): {root}')
    return root


def client_manifest(store: Path, server: str, version_id: str) -> dict:
    path = store / 'clients' / server / version_id / 'manifest.json'
    if not path.exists():
        raise SystemExit(f'client manifest not found: {path}')
    return read_json(path)


def list_versions(store: Path, server: str) -> list[str]:
    base = store / 'clients' / server
    return sorted(p.name for p in base.iterdir() if (p / 'manifest.json').exists()) if base.exists() else []

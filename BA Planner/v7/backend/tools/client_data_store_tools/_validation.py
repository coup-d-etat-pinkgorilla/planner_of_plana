"""Path/identity checks shared by the new store CLI candidates (stdlib only)."""
from __future__ import annotations

import re
from pathlib import Path


def component(value: str, label: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', value):
        raise ValueError(f'invalid {label}')
    if value in ('.', '..') or value.endswith('.'):
        raise ValueError(f'invalid {label}')
    return value


def version(server: str, value: str) -> str:
    if server not in ('jp', 'steam'):
        raise ValueError('invalid server')
    component(value, 'version-id')
    if not value.startswith(server + '-'):
        raise ValueError('version-id belongs to a different server')
    return value


def contained(root: Path, *parts: str) -> Path:
    root = root.resolve()
    path = root.joinpath(*parts).resolve()
    if not path.is_relative_to(root):
        raise ValueError('path escapes store root')
    return path


def manifest_identity(manifest: dict, server: str, version_id: str) -> None:
    if not isinstance(manifest, dict) or manifest.get('server') != server or manifest.get('version_id') != version_id:
        raise ValueError('client manifest identity mismatch')
    if not isinstance(manifest.get('files'), dict):
        raise ValueError('client manifest files must be an object')

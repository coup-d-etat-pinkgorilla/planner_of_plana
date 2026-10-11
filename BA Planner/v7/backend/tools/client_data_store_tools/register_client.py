"""Register hashes with legacy CLI behavior, or emit write-free JSON with --dry-run.

Dry-run reads the selected installation and existing manifest only. It never creates
a directory, registers a manifest or copies an archive, even when --archive is set.
Normal mode retains the original archive/write behavior and immutable-manifest rule.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import sys
from pathlib import Path

try:
    from ._common import jp_bundle_path, read_json, sha256_file, store_root, write_json
    from ._validation import component, contained, manifest_identity, version
except ImportError:
    from _common import jp_bundle_path, read_json, sha256_file, store_root, write_json
    from _validation import component, contained, manifest_identity, version

SMALL_ARCHIVE = {'global-metadata.dat', 'Excel.zip'}


def jp_files(root: Path) -> dict[str, Path]:
    tb = root / 'BlueArchive_Data' / 'StreamingAssets' / 'TableBundles'
    out = {
        'GameAssembly.dll': root / 'GameAssembly.dll',
        'global-metadata.dat': root / 'BlueArchive_Data' / 'il2cpp_data' / 'Metadata' / 'global-metadata.dat',
    }
    for name in ('ExcelDB.db', 'Excel.zip', 'LevelSkillDataDBSchema.db', 'LogicEffectDataDBSchema.db'):
        try:
            out[name] = jp_bundle_path(tb, name)
        except FileNotFoundError as exc:
            print(f'warning: {exc}', file=sys.stderr)
    return out


def steam_files(root: Path) -> dict[str, Path]:
    tb = root / 'BlueArchive_Data' / 'StreamingAssets' / 'PUB' / 'Resource' / 'Preload' / 'TableBundles'
    out = {
        'GameAssembly.dll': root / 'GameAssembly.dll',
        'global-metadata.dat': root / 'BlueArchive_Data' / 'il2cpp_data' / 'Metadata' / 'global-metadata.dat',
    }
    for name in ('ExcelDB.db', 'Excel.zip', 'LevelSkillDataDBSchema.db', 'LogicEffectDataDBSchema.db', 'TableCatalog.bytes'):
        path = tb / name
        if path.exists():
            out[name] = path
        else:
            print(f'warning: missing {path}', file=sys.stderr)
    return out


def build_manifest(args, *, registered_utc=None):
    root = Path(args.root)
    if not root.is_dir():
        raise ValueError(f'client root not found: {root}')
    files = jp_files(root) if args.server == 'jp' else steam_files(root)
    if 'GameAssembly.dll' not in files or not files['GameAssembly.dll'].exists():
        raise ValueError('GameAssembly.dll not found')
    client_version = args.version
    if args.server == 'jp' and not client_version:
        cfg = root / 'game-launcher-config.json'
        client_version = read_json(cfg)['version'] if cfg.exists() else None
    if args.server == 'steam' and not args.revision:
        raise ValueError('--revision is required for steam (e.g. 464491)')
    # Components are validated before hashes or any potential writes. Existing conventional IDs are unchanged.
    if client_version is not None:
        component(client_version, 'client version')
    if args.revision is not None:
        component(args.revision, 'bundle revision')
    hashes = {}
    for name, path in files.items():
        if path.exists():
            print(f'hashing {name} ...', file=sys.stderr)
            hashes[name] = {'sha256': sha256_file(path), 'size': path.stat().st_size, 'installed_path': str(path)}
    ga8 = hashes['GameAssembly.dll']['sha256'][:8]
    version_id = f'jp-{client_version}-{ga8}' if args.server == 'jp' else f'steam-r{args.revision}-{ga8}'
    version(args.server, version_id)
    manifest = {'schema': 'ba-client-data.client-manifest.v1', 'server': args.server, 'version_id': version_id,
                'client_version': client_version, 'bundle_revision': args.revision,
                'registered_utc': registered_utc or dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds'),
                'client_root': str(root), 'files': hashes, 'note': args.note, 'archive': []}
    return manifest, files


def registration_preview(store: Path, manifest: dict, files: dict, archive_requested: bool):
    entry = contained(store, 'clients', manifest['server'], manifest['version_id'])
    path = contained(store, 'clients', manifest['server'], manifest['version_id'], 'manifest.json')
    present = path.exists()
    content_match = None
    if present:
        existing = read_json(path)
        manifest_identity(existing, manifest['server'], manifest['version_id'])
        ignored = {'registered_utc', 'archive'}
        content_match = ({key: value for key, value in existing.items() if key not in ignored}
                         == {key: value for key, value in manifest.items() if key not in ignored})
    archives = sorted(name for name in SMALL_ARCHIVE if name in files and files[name].exists()) if archive_requested else []
    return {'schema': 'ba-client-data.registration-preview.v1', 'version_id': manifest['version_id'],
            'dry_run': True, 'written': False, 'would_register': not present,
            'action': 'STOP_ALREADY_REGISTERED' if present else 'WOULD_REGISTER',
            'target_manifest': str(path), 'existing_manifest': present,
            'content_match_ignoring_registration_time_and_archive': content_match,
            'archive_requested': archive_requested, 'would_archive': archives, 'archive_written': False,
            'candidate_manifest': manifest}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--server', choices=('jp', 'steam'), required=True)
    parser.add_argument('--root', required=True, help='installed client root')
    parser.add_argument('--store', help='store root (default: %BA_CLIENT_DATA% or ~/ba-client-data)')
    parser.add_argument('--revision', help='Steam bundle revision; required for steam')
    parser.add_argument('--version', help='override JP client version string')
    parser.add_argument('--note', default='')
    parser.add_argument('--archive', action='store_true', help='legacy normal mode: copy small reproducibility files')
    parser.add_argument('--dry-run', action='store_true', help='emit JSON preview; no mkdir, archive or registration')
    args = parser.parse_args(argv)
    try:
        store = store_root(args.store)
        manifest, files = build_manifest(args)
        entry = contained(store, 'clients', args.server, manifest['version_id'])
        if args.dry_run:
            print(json.dumps(registration_preview(store, manifest, files, args.archive), ensure_ascii=False, indent=2))
            return 0
    except (ValueError, FileNotFoundError, json.JSONDecodeError) as exc:
        raise SystemExit(str(exc)) from exc
    if args.archive:
        for name in SMALL_ARCHIVE:
            if name in files and files[name].exists():
                dst = contained(store, 'clients', args.server, manifest['version_id'], 'archive', name)
                if dst.exists():
                    if sha256_file(dst) != manifest['files'][name]['sha256']:
                        raise SystemExit(f'archive differs: {dst}')
                else:
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(files[name], dst)
                manifest['archive'].append(name)
    changed = write_json(contained(store, 'clients', args.server, manifest['version_id'], 'manifest.json'), manifest)
    print(json.dumps({'version_id': manifest['version_id'], 'written': changed,
                      'files': {key: value['sha256'][:12] for key, value in manifest['files'].items()}}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

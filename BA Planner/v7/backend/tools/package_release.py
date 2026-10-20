"""M6 offline release packager. Reads a built bundle/lock; never reads the store.

Update ZIPs have app-relative payloads below app/ and release-manifest.json at
the archive root. A full ZIP also contains the explicitly supplied launcher.
No build, download, upload, game extraction or user-data migration is performed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath, PureWindowsPath
import re
import stat
import sys
import tempfile
from urllib.parse import urlsplit
import zipfile

BACKEND = Path(__file__).resolve().parents[1]
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))
from core.client_data_store import ClientDataStore  # noqa: E402

SEMVER = re.compile(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?\Z')
RESERVED = {'.ba_planner_data_snapshot.json', 'CHANGELOG-data.md', 'latest.json',
            'latest-app.json', 'latest-data.json', 'release-manifest.json'}
PRIVATE = {'profiles', 'repository', 'logs', 'debug', 'scan-results', 'screenshots',
           'recognition-assets', 'recognition-synth-cache', 'user-data', 'developer_tools'}
IMAGES = {'.png', '.jpg', '.jpeg', '.webp', '.bmp', '.dds', '.tga'}
GYEONGGI_PATH = 'data/flutter_assets/assets/fonts/GyeonggiTitle-Medium.ttf'
GYEONGGI_SHA256 = 'da6fc2e29f3fdc1f25a1f94e18549040acef06ac8d7d9dc373e0f6eabbcae8da'
GYEONGGI_NOTICE = BACKEND / 'licenses/GyeonggiTitle-LICENSE.txt'


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + '\n').encode('utf-8')


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def file_pin(path):
    digest = hashlib.sha256()
    size = 0
    with path.open('rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
            size += len(block)
    return {'bytes': size, 'sha256': digest.hexdigest()}


def portable_path(name):
    if not isinstance(name, str) or not name or '\\' in name or ':' in name:
        raise ValueError('unsafe package path')
    parts = name.split('/')
    if PurePosixPath(name).is_absolute() or any(
        part in ('', '.', '..') or part.endswith((' ', '.')) or PureWindowsPath(part).is_reserved()
        or any(ord(c) < 32 for c in part) for part in parts
    ):
        raise ValueError('unsafe package path')
    return name


def _under(path, parent):
    return path == parent or path.is_relative_to(parent)


def _regular(path, root):
    # Reject even an inward symlink/junction: package identity must be portable.
    cursor = path
    while _under(cursor, root):
        if _linked(cursor):
            raise ValueError('linked package inputs are unsupported')
        if cursor == root:
            break
        cursor = cursor.parent
    if not path.resolve().is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError('package input escaped the bundle')


def _linked(path):
    return path.is_symlink() or bool(getattr(path.lstat(), 'st_file_attributes', 0)
                                     & getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0x400))


def inventory(bundle, mode, output, allow_bundled_ui_assets=False):
    base = bundle / 'backend/data' if mode == 'data' else bundle
    if not base.is_dir():
        raise ValueError('built bundle/backend/data is required')
    result = {}
    seen = set()
    for directory, dirs, names in os.walk(base, followlinks=False):
        directory = Path(directory)
        for child in dirs[:]:
            path = directory / child
            if _linked(path):
                raise ValueError('linked package directory is unsupported')
            if output != bundle and _under(path.resolve(), output):
                dirs.remove(child)
                continue
            if child in {'__pycache__', '.pytest_cache'}:
                dirs.remove(child)
                continue
            if directory == bundle and child == 'developer_tools':
                # sync_windows_release intentionally preserves the separate devtools bundle.
                dirs.remove(child)
                continue
            if child.casefold() in PRIVATE or child.casefold() == '.git':
                raise ValueError('private/developer directory in release bundle: ' + child)
            if path.relative_to(bundle).as_posix().casefold() == 'backend/tools':
                raise ValueError('developer tools must not be distributed')
        for name in sorted(names):
            path = directory / name
            relative = portable_path(path.relative_to(bundle).as_posix())
            if directory == bundle and (name in RESERVED or name.startswith('BA-Planner-v7-')
                                        and name.endswith(('.zip', '.sha256'))):
                continue
            if name.endswith(('.pyc', '.pyo')):
                continue
            _regular(path, bundle)
            if relative.casefold() in seen:
                raise ValueError('case-insensitive package path collision')
            seen.add(relative.casefold())
            parts = relative.casefold().split('/')
            if any(part in PRIVATE for part in parts) or name.casefold() in {'ba-data.lock', 'config.json'}:
                raise ValueError('private/local state in release bundle')
            if name.casefold() == 'developer_tools.py':
                raise ValueError('developer tool entrypoint in release bundle')
            backend_image = relative.startswith('backend/assets/') and path.suffix.lower() in IMAGES
            ui_image = relative.startswith('data/flutter_assets/assets/') and path.suffix.lower() in IMAGES
            if backend_image or ui_image and not allow_bundled_ui_assets:
                raise ValueError('first-run game assets must not be distributed: ' + relative)
            if name.casefold() == 'gyeonggititle-medium.ttf':
                if relative != GYEONGGI_PATH or file_pin(path)['sha256'] != GYEONGGI_SHA256:
                    raise ValueError('unapproved GyeonggiTitle font payload: ' + relative)
            if mode == 'data' and path.suffix.lower() not in {'.json', '.md', '.txt'}:
                raise ValueError('data-only release accepts derived JSON/text files only')
            result[relative] = path
    if not any(p.startswith('backend/data/') for p in result):
        raise ValueError('release has no backend data')
    if mode == 'app' and 'ba_planner_v7.exe' not in result:
        raise ValueError('full release requires ba_planner_v7.exe')
    return dict(sorted(result.items()))


def make_snapshot(lock_path, files, data_server):
    raw = lock_path.read_bytes()
    # Constructor validates lock shape and paths only; no store manifest/extract is opened.
    reader = ClientDataStore(lock_path, lock_path.parent / '.unused-m6-store')
    lock = reader.lock
    if data_server not in lock['pins']:
        raise ValueError('data server is not pinned')
    pins = {server: {'versionId': value['version_id'], 'clientVersion': value['client_version'],
                     'bundleRevision': value['bundle_revision'], 'files': value['files']}
            for server, value in sorted(lock['pins'].items())}
    extracts = [{'server': row['server'], 'versionId': row['version_id'], 'kind': row['kind'],
                 'provenanceSha256': row['provenance_sha256'], 'filesSha256': sha(json_bytes(row['files']))}
                for row in sorted(lock['extracts'], key=lambda row: (row['server'], row['kind']))]
    value = {'schemaVersion': 1, 'dataVersionId': pins[data_server]['versionId'],
             'lockSha256': sha(raw), 'pins': pins, 'extracts': extracts,
             'provenanceScope': 'lock-records-only; shipped-files-hashed-separately; manual-fields-retained',
             'files': [{'path': name, **file_pin(path)} for name, path in files.items()
                       if name.startswith('backend/data/')]}
    if lock_path.read_bytes() != raw:
        raise ValueError('lock changed during snapshot generation')
    return value


def _atomic(path, raw):
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '-', suffix='.tmp', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as handle:
            handle.write(raw)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _zip_entry(archive, name, raw=None, source=None, expected=None):
    info = zipfile.ZipInfo(portable_path(name), date_time=(1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    digest = hashlib.sha256()
    size = 0
    with archive.open(info, 'w', force_zip64=True) as target:
        if source is None:
            target.write(raw)
            digest.update(raw)
            size = len(raw)
        else:
            with source.open('rb') as handle:
                for block in iter(lambda: handle.read(1 << 20), b''):
                    target.write(block)
                    digest.update(block)
                    size += len(block)
    actual = {'bytes': size, 'sha256': digest.hexdigest()}
    if expected is not None and actual != expected:
        raise ValueError('package input changed while archiving: ' + name)


def generate_release(*, bundle_dir, output_dir, lock_path, mode, app_version, zip_url,
                     notes, min_launcher='1.0.0', data_server='jp', launcher=None,
                     allow_bundled_ui_assets=False):
    bundle = Path(bundle_dir).absolute()
    output = Path(output_dir).absolute()
    lock_path = Path(lock_path).resolve()
    if mode not in {'app', 'data'} or not all(isinstance(v, str) and SEMVER.fullmatch(v)
                                             for v in (app_version, min_launcher)):
        raise ValueError('release mode and semantic versions are required')
    if not isinstance(allow_bundled_ui_assets, bool) or allow_bundled_ui_assets and mode != 'app':
        raise ValueError('bundled UI assets are an explicit app-only alpha-1 option')
    url = urlsplit(zip_url)
    if url.scheme != 'https' or not url.hostname or url.username or url.password or url.fragment or any(c.isspace() for c in zip_url):
        raise ValueError('zip URL must be an absolute HTTPS URL without credentials/fragment')
    if not isinstance(notes, str) or not 1 <= len(notes) <= 8192:
        raise ValueError('release notes must contain 1..8192 characters')
    # Never turn release generation into a shared-store or application-data writer.
    lock = json.loads(lock_path.read_text(encoding='utf-8'))
    store = Path(lock['store_root']).expanduser().resolve()
    if _under(output.resolve(), store) or any(p.casefold() in PRIVATE - {'debug'} for p in output.parts):
        raise ValueError('output must be outside shared store and user-data roots')
    if any(p.casefold() == 'extracted' for p in output.parts) or _under(output.resolve(), (bundle / 'backend/data').resolve()):
        raise ValueError('output must not overwrite source data')
    files = inventory(bundle, mode, output.resolve(), allow_bundled_ui_assets)
    snapshot = make_snapshot(lock_path, files, data_server)
    snapshot_raw = json_bytes(snapshot)
    snapshot_sha = sha(snapshot_raw)
    zip_name = f'BA-Planner-v7-{mode}-{app_version}-{snapshot["dataVersionId"]}-{snapshot_sha[:12]}.zip'
    zip_path = output / zip_name
    zip_url = zip_url.replace('{filename}', zip_name)
    url = urlsplit(zip_url)
    if url.path.rsplit('/', 1)[-1] != zip_name:
        raise ValueError('zip URL filename must equal generated filename: ' + zip_name)
    if mode == 'app':
        if launcher is None:
            raise ValueError('full ZIP requires an explicit distribution launcher')
        launcher = Path(launcher)
        _regular(launcher.absolute(), launcher.absolute().parent)
    elif launcher is not None:
        raise ValueError('data-only ZIP must not contain a launcher')
    old_changelog_path = output / 'CHANGELOG-data.md'
    if not old_changelog_path.exists():
        old_changelog_path = bundle / 'CHANGELOG-data.md'
    old = old_changelog_path.read_text(encoding='utf-8') if old_changelog_path.exists() else '# Data releases\n'
    marker = f'<!-- ba-data:{mode}:{app_version}:{snapshot_sha} -->'
    entry = f'{marker}\n## {app_version} / {snapshot["dataVersionId"]} ({mode})\n\n{notes}\n\nLock SHA256: `{snapshot["lockSha256"]}`\nSnapshot SHA256: `{snapshot_sha}`\n'
    if marker in old and entry not in old:
        raise ValueError('same release identity has different changelog notes')
    changelog = old if marker in old else old.rstrip() + '\n\n' + entry
    generated = {'app/.ba_planner_data_snapshot.json': snapshot_raw,
                 'app/CHANGELOG-data.md': changelog.encode('utf-8')}
    if GYEONGGI_PATH in files:
        notice_path = 'licenses/GyeonggiTitle-LICENSE.txt'
        notice = GYEONGGI_NOTICE.read_bytes()
        if not notice.strip():
            raise ValueError('GyeonggiTitle license notice is required')
        if notice_path in files and files[notice_path].read_bytes() != notice:
            raise ValueError('bundled GyeonggiTitle notice differs from approved notice')
        if notice_path not in files:
            generated['app/' + notice_path] = notice
    sources = {'app/' + name: path for name, path in files.items()}
    if launcher is not None:
        sources['BA Planner v7.exe'] = launcher
    pins = {name: file_pin(path) for name, path in sources.items()}
    pins.update({name: {'bytes': len(raw), 'sha256': sha(raw)} for name, raw in generated.items()})
    manifest = {'schemaVersion': 1, 'releaseType': mode, 'appVersion': app_version,
                'dataVersionId': snapshot['dataVersionId'], 'dataSnapshotSha256': snapshot_sha,
                'bundledUiAssets': allow_bundled_ui_assets,
                'files': [{'path': name, **pin} for name, pin in sorted(pins.items())]}
    output.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.m6-package-', suffix='.tmp', dir=output)
    os.close(fd)
    try:
        with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            _zip_entry(archive, 'release-manifest.json', raw=json_bytes(manifest))
            for name in sorted(pins):
                _zip_entry(archive, name, raw=generated.get(name), source=sources.get(name), expected=pins[name])
        zip_pin = file_pin(Path(temporary))
        if zip_path.exists() and file_pin(zip_path) != zip_pin:
            raise ValueError('immutable release filename already exists with different bytes; use a new app/data release version')
        latest = {'schemaVersion': 1, 'releaseType': mode, 'appVersion': app_version,
                  'dataVersionId': snapshot['dataVersionId'], 'dataSnapshotSha256': snapshot_sha,
                  'zipUrl': zip_url, 'sha256': zip_pin['sha256'], 'notes': notes, 'minLauncher': min_launcher}
        if not zip_path.exists():
            os.replace(temporary, zip_path)
        _atomic(output / '.ba_planner_data_snapshot.json', snapshot_raw)
        _atomic(output / 'CHANGELOG-data.md', changelog.encode('utf-8'))
        _atomic(output / (zip_name + '.sha256'), (zip_pin['sha256'] + '  ' + zip_name + '\n').encode('ascii'))
        # Each channel has a stable independent URL. Publishing data never removes
        # the app descriptor needed by an older installed app (CM X1-b).
        descriptor = output / ('latest-' + mode + '.json')
        _atomic(descriptor, json_bytes(latest))
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return {'zip': str(zip_path), 'zipBytes': zip_pin['bytes'], 'latest': latest,
            'latestPath': str(descriptor), 'snapshot': snapshot,
            'verification': 'offline-package-only; launcher-update/native-alpha-not-verified'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle-dir', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--lock', type=Path, default=BACKEND.parent / 'ba-data.lock')
    parser.add_argument('--mode', choices=('app', 'data'), required=True)
    parser.add_argument('--app-version', required=True)
    parser.add_argument('--zip-url', required=True)
    parser.add_argument('--notes', required=True)
    parser.add_argument('--min-launcher', default='1.0.0')
    parser.add_argument('--data-server', choices=('jp', 'steam'), default='jp')
    parser.add_argument('--launcher', type=Path)
    parser.add_argument('--allow-bundled-ui-assets', action='store_true',
                        help='alpha-1 app ZIP only: include existing Flutter UI images; never recognition assets')
    args = parser.parse_args()
    try:
        result = generate_release(bundle_dir=args.bundle_dir, output_dir=args.output_dir, lock_path=args.lock,
            mode=args.mode, app_version=args.app_version, zip_url=args.zip_url, notes=args.notes,
            min_launcher=args.min_launcher, data_server=args.data_server, launcher=args.launcher,
            allow_bundled_ui_assets=args.allow_bundled_ui_assets)
    except (ValueError, OSError, zipfile.BadZipFile) as error:
        parser.exit(1, 'M6 packaging failed: ' + str(error) + '\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'snapshot'}, ensure_ascii=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

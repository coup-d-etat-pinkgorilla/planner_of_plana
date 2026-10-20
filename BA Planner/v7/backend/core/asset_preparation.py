"""F2 explicit recognition-cache jobs. Does not enumerate/capture game windows."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
import json
import os
import re
from pathlib import Path
from threading import Event, RLock
from uuid import uuid4

from core.asset_preparation_cache import cache_counts, digest, game_identity, validated_cache
from core.recognition_asset_extract import AssetExtractFailed, extract, find_game_dir
from core.recognition_synth import SynthUnavailable
from core.scanner_session import ScannerError


class OperationGate:
    """One atomic owner for scanning, preparation and game-folder changes."""
    def __init__(self):
        self._lock = RLock()
        self._owner = None

    def acquire(self, kind, token):
        with self._lock:
            if self._owner:
                code = 'scanner_busy' if self._owner[0] == 'scanner' else 'asset_prepare_busy'
                raise ScannerError(code, 'another scanner or asset preparation operation is active')
            self._owner = (kind, token)

    def release(self, token):
        with self._lock:
            if self._owner and self._owner[1] == token:
                self._owner = None

    def owner(self):
        with self._lock:
            return self._owner[0] if self._owner else None


class PreparationGuardedScanner:
    """Composition keeps existing scanner lifecycle/DTO bytes unchanged."""
    def __init__(self, scanner, gate):
        self._scanner, self._gate = scanner, gate
        self._sink = lambda _event: None
        self._token = None
        scanner.set_event_sink(self._event)

    def __getattr__(self, name):
        return getattr(self._scanner, name)

    def set_event_sink(self, sink):
        self._sink = sink

    def _event(self, event):
        if event.get('payload', {}).get('event_kind') == 'terminal':
            token, self._token = self._token, None
            self._gate.release(token)
        self._sink(event)

    def start(self, *args, **kwargs):
        token = uuid4().hex
        self._gate.acquire('scanner', token)
        self._token = token
        try:
            return self._scanner.start(*args, **kwargs)
        except BaseException:
            self._gate.release(token)
            if self._token == token:
                self._token = None
            raise


def _atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name('.' + path.name + '.' + uuid4().hex + '.tmp')
    try:
        with temporary.open('w', encoding='utf-8', newline='\n') as handle:
            json.dump(value, handle, ensure_ascii=False, sort_keys=True, allow_nan=False)
            handle.write('\n')
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


class AssetPreparationService:
    def __init__(self, *, storage_root, cache_root, rarity_path, gate,
                 game_finder=find_game_dir, extractor=extract, snapshot_path=None):
        self.storage_root, self.cache_root = Path(storage_root), Path(cache_root)
        self.rarity_path, self.gate = Path(rarity_path), gate
        self.find_game, self.extractor = game_finder, extractor
        self.snapshot_path = Path(snapshot_path) if snapshot_path else None
        self.settings = self.storage_root/'asset-preparation.json'
        self.last_path = self.storage_root/'asset-preparation-result.json'
        self._lock = RLock()
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix='asset-prepare')
        self._sink = lambda _event: None
        self._job = None
        self._generation = 0
        self._future = None
        self._cancel = Event()
        self._closed = False

    def set_event_sink(self, sink):
        with self._lock:
            self._sink = sink

    @staticmethod
    def _read(path):
        try:
            value = json.loads(path.read_text(encoding='utf-8'))
            return value if isinstance(value, dict) else {}
        except (OSError, ValueError):
            return {}

    def _game(self):
        path = self._read(self.settings).get('game_dir')
        if isinstance(path, str) and path:
            return game_identity(Path(path), 'user')
        try:
            found = self.find_game()
        except (OSError, ValueError):
            found = None
        return game_identity(Path(found) if found else None, 'auto' if found else 'none')

    def _cache(self, game):
        empty = {'state': 'missing', 'catalog_sha256': None, 'bundle_revision': None,
                 'icons': 0, 'sprites': 0, 'fonts': 0, 'failed': None}
        if not game['valid']:
            return {**empty, 'state': 'unknown'}, None
        target = self.cache_root/game['catalog_sha256'][:16]
        cache = validated_cache(target, game['catalog_sha256'], self.rarity_path, game['bundle_revision'])
        if cache:
            counts = cache_counts(cache.manifest)
            return {'state': 'partial' if counts['failed'] else 'ready',
                    'catalog_sha256': game['catalog_sha256'], 'bundle_revision': game['bundle_revision'], **counts}, cache
        if target.exists():
            manifest = self._read(target/'manifest.json')
            stale = (manifest.get('catalog_sha256') == game['catalog_sha256']
                     and (manifest.get('bundle_revision') != game['bundle_revision']
                          or manifest.get('rarity_sha256') != self._rarity_sha()))
            return {**empty, 'state': 'stale' if stale else 'invalid'}, None
        try:
            previous = any(p.is_dir() and not p.name.startswith('.') for p in self.cache_root.iterdir())
        except OSError:
            previous = False
        return {**empty, 'state': 'stale' if previous else 'missing'}, None

    def _rarity_sha(self):
        try:
            return digest(self.rarity_path)
        except OSError:
            return None

    def _metadata(self, game):
        value = self._read(self.snapshot_path) if self.snapshot_path else {}
        try:
            revision = value.get('pins', {}).get('steam', {}).get('bundleRevision')
            snapshot_sha = digest(self.snapshot_path) if value else None
        except (OSError, AttributeError, TypeError):
            value, revision, snapshot_sha = {}, None, None
        if not isinstance(revision, str) or not revision.isascii() or not revision.isdigit():
            revision = None
        version = value.get('dataVersionId')
        if not isinstance(version, str) or not re.fullmatch(r'(jp|steam)-[a-z0-9][a-z0-9._-]*', version):
            version = None
        matches = revision == game['bundle_revision'] if revision and game['valid'] else None
        return {'data_version_id': version,
                'data_snapshot_sha256': snapshot_sha,
                'steam_bundle_revision': revision, 'steam_matches_snapshot': matches,
                'jp_update_required': None}

    def status(self):
        game = self._game()
        cache, _ = self._cache(game)
        with self._lock:
            job = deepcopy(self._job)
        owner = self.gate.owner()
        return {'game_dir': game, 'cache': cache, 'busy': owner == 'prepare',
                'scanner_busy': owner == 'scanner', 'job': job,
                'last_result': self._last_result(), 'metadata': self._metadata(game)}

    def _last_result(self):
        value = self._read(self.last_path)
        keys = {'job_id','generation','sequence','state','stage','done','total','unit',
                'created','available','reused','failed','reason_codes'}
        if set(value) != keys or value.get('state') not in {'succeeded','partial','failed','cancelled'}:
            return None
        if (not isinstance(value['job_id'], str) or not re.fullmatch(r'[0-9a-f]{32}', value['job_id'])
                or value['stage'] != 'complete' or value['unit'] != 'bundles'):
            return None
        for key in ('generation','sequence','done','available','total','created','reused','failed'):
            number = value[key]
            if number is None and key in {'total','created','reused','failed'}:
                continue
            if type(number) is not int or number < (1 if key in {'generation','sequence'} else 0):
                return None
        allowed = {'assets_missing','cancelled','asset_cache_invalid','asset_extract_failed','result_not_saved'}
        if not isinstance(value['reason_codes'],list) or any(not isinstance(r,str) or r not in allowed for r in value['reason_codes']):
            return None
        return value

    def set_game_dir(self, path):
        token = uuid4().hex
        self.gate.acquire('prepare', token)
        try:
            if path is not None:
                path = str(Path(path).expanduser().resolve())
                game = game_identity(Path(path), 'user')
                if not game['valid']:
                    raise ScannerError('invalid_game_dir', 'game folder is invalid', details={'reason': game['reason']})
            _atomic_json(self.settings, {'schema_version': 1, 'game_dir': path})
        finally:
            self.gate.release(token)
        return self.status()

    def prepared_assets(self):
        _, cache = self._cache(self._game())
        if cache is None:
            raise SynthUnavailable('recognition assets are not prepared')
        return cache

    def start(self):
        token = uuid4().hex
        self.gate.acquire('prepare', token)
        try:
            with self._lock:
                if self._closed:
                    raise ScannerError('asset_prepare_unavailable', 'asset preparation service is closed')
                game = self._game()
                if not game['valid']:
                    raise ScannerError('invalid_game_dir', 'game folder is invalid', details={'reason': game['reason']})
                self._generation += 1
                self._cancel = Event()
                self._job = {'job_id': token, 'generation': self._generation, 'sequence': 0,
                             'state': 'running', 'stage': 'validating', 'done': 0, 'total': None,
                             'unit': 'bundles', 'created': None, 'available': 0, 'reused': None,
                             'failed': None, 'reason_codes': []}
                self._future = self._executor.submit(self._run, token, game)
                return {'job_id': token, 'generation': self._generation}
        except BaseException:
            self.gate.release(token)
            raise

    def _require(self, job_id, generation):
        if not self._job or self._job['job_id'] != job_id or self._job['generation'] != generation:
            raise ScannerError('asset_prepare_job_not_found', 'asset preparation job was not found')

    def snapshot(self, job_id, generation):
        with self._lock:
            self._require(job_id, generation)
            return {'job': deepcopy(self._job)}

    def cancel(self, job_id, generation):
        with self._lock:
            self._require(job_id, generation)
            active = self._job['state'] in {'running', 'cancelling'}
            if active:
                self._cancel.set()
                self._job['state'] = 'cancelling'
            return {'job_id': job_id, 'generation': generation, 'cancel_requested': active}

    def _progress(self, stage, done, total):
        if self._cancel.is_set():
            raise ScannerError('asset_prepare_cancelled', 'asset preparation was cancelled')
        with self._lock:
            self._job.update(stage=stage, done=done, total=total)
            self._emit('progress')

    def _emit(self, kind):
        self._job['sequence'] += 1
        self._sink({'protocol': 1, 'type': 'event', 'method': 'assets.prepare.event',
                    'payload': {'event_kind': kind, **deepcopy(self._job)}})

    def _run(self, token, game):
        state, counts, reasons = 'failed', {'created': None, 'available': 0, 'reused': None, 'failed': None}, []
        try:
            self._progress('validating', 0, None)
            _, cache = self._cache(game)
            refresh = cache is not None and bool(cache.manifest.get('missing'))
            ready = cache is not None and not refresh
            if refresh:
                cache = None
            if cache is None:
                cache = self.extractor(Path(game['path']), self.cache_root, self.rarity_path,
                                       self._progress, cancelled=self._cancel.is_set, force=refresh)
            if self._cancel.is_set():
                raise ScannerError('asset_prepare_cancelled', 'asset preparation was cancelled')
            # Refuse a fake/partial publication before announcing availability.
            checked = validated_cache(cache.root, game['catalog_sha256'], self.rarity_path, game['bundle_revision'])
            if checked is None or self._game() != game:
                raise ScannerError('asset_cache_invalid', 'prepared cache failed identity validation')
            sections = cache_counts(checked.manifest)
            available = sum(sections[k] for k in ('icons','sprites','fonts'))
            reused = available if ready else checked.manifest.get('reused_files', 0)
            counts = {'created': available-reused, 'available': available, 'reused': reused, 'failed': sections['failed']}
            state = 'partial' if sections['failed'] else 'succeeded'
            reasons = ['assets_missing'] if sections['failed'] else []
        except ScannerError as exc:
            state = 'cancelled' if exc.code == 'asset_prepare_cancelled' or self._cancel.is_set() else 'failed'
            reasons = ['cancelled'] if state == 'cancelled' else [exc.code if exc.code in {'asset_cache_invalid'} else 'asset_extract_failed']
        except Exception:
            state, reasons = ('cancelled', ['cancelled']) if self._cancel.is_set() else ('failed', ['asset_extract_failed'])
        finally:
            with self._lock:
                self._job.update(state=state, stage='complete', reason_codes=reasons, **counts)
                result = deepcopy(self._job)
                result['sequence'] += 1
                try:
                    _atomic_json(self.last_path, result)
                except OSError:
                    self._job['reason_codes'].append('result_not_saved')
                # Ownership ends only after the extractor and its staging cleanup return.
                self.gate.release(token)
                self._emit('terminal')

    def wait(self, timeout=5):
        if self._future:
            self._future.result(timeout=timeout)

    def close(self):
        with self._lock:
            self._closed = True
            self._cancel.set()
        self._executor.shutdown(wait=True)

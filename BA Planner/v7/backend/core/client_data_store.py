"""M1: lock-only extract reader; no writes or installed-client access."""
from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PureWindowsPath
import re

DEFAULT_STORE = Path(r"C:\Users\brigh\ba-client-data")
_TOKEN = re.compile(r"[a-z0-9][a-z0-9._-]*\Z")
_SHA = re.compile(r"[a-f0-9]{64}\Z")


class ClientDataStoreError(ValueError):
    def __init__(self, code: str, message: str):
        self.code = code
        super().__init__(f"{code}: {message}")


def _fail(code, message):
    raise ClientDataStoreError(code, message)


def _token(value):
    if not isinstance(value, str) or not _TOKEN.fullmatch(value) or value.endswith('.'):
        _fail('store_invalid_path', 'Invalid identity component')
    return value


def _parts(value: object):
    if not isinstance(value, str) or not value or '\\' in value or ':' in value:
        _fail('store_invalid_path', 'Expected portable relative path')
    parts = value.split('/')
    if PureWindowsPath(value).is_absolute() or any(p in ('', '.', '..') or p.endswith((' ', '.')) or PureWindowsPath(p).is_reserved() for p in parts):
        _fail('store_invalid_path', 'Unsafe relative path')
    return parts


def _relative(base: Path, value: object) -> Path:
    parts = _parts(value)
    base = base.resolve()
    target = base.joinpath(*parts).resolve()
    if not target.is_relative_to(base):
        _fail('store_invalid_path', 'Resolved path escapes owned root')
    return target


def _unique_pairs(pairs):
    obj = {}
    for key, value in pairs:
        if key in obj:
            _fail('store_malformed_data', 'Duplicate JSON object key')
        obj[key] = value
    return obj


def _decode(raw: bytes):
    try:
        return json.loads(raw.decode('utf-8'), object_pairs_hook=_unique_pairs,
                          parse_constant=lambda _: _fail('store_malformed_data', 'Nonfinite JSON'))
    except (UnicodeError, json.JSONDecodeError):
        _fail('store_malformed_data', 'Invalid UTF-8 JSON')


def _read(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except FileNotFoundError:
        _fail('store_missing_data', 'Required registered file is missing')
    except OSError:
        _fail('store_read_failed', 'Registered file cannot be read')


def _hashes(value, label):
    if not isinstance(value, dict) or not value:
        _fail('store_invalid_lock', f'{label} must be a nonempty hash map')
    seen = set()
    for name, sha in value.items():
        _parts(name)  # lexical only; no unrelated filesystem resolution
        if name.casefold() in seen or not isinstance(sha, str) or not _SHA.fullmatch(sha):
            _fail('store_invalid_lock', f'Invalid or duplicate {label} hash entry')
        seen.add(name.casefold())
    return dict(value)


class ClientDataStore:
    def __init__(self, lock_path: Path, store_root: Path | None = None):
        self.root = Path(store_root if store_root is not None else
                         os.environ.get('BA_CLIENT_DATA_DIR') or DEFAULT_STORE).expanduser().resolve()
        self.lock = _decode(_read(Path(lock_path)))
        lock = self.lock
        if not isinstance(lock, dict) or set(lock)!={'schema','consumer','store_root','written_utc','pins','extracts'} or lock.get('schema') != 'ba-client-data.lock.v1' or lock.get('consumer') != 'v7':
            _fail('store_invalid_lock', 'Expected v7 lock v1')
        if not isinstance(lock.get('pins'), dict) or not lock['pins'] or not isinstance(lock.get('extracts'), list):
            _fail('store_invalid_lock', 'Pins and extracts are required')
        for server, pin in lock['pins'].items():
            if server not in ('jp', 'steam') or not isinstance(pin, dict) or set(pin)!={'version_id','client_version','bundle_revision','files'}:
                _fail('store_invalid_lock', 'Unsupported pin identity')
            if any(pin[key] is not None and not isinstance(pin[key],str) for key in ('client_version','bundle_revision')):
                _fail('store_invalid_lock', 'Invalid nullable pin metadata')
            version = _token(pin.get('version_id'))
            if not version.startswith(server+'-'):
                _fail('store_mixed_version', 'Pin/server mismatch')
            _hashes(pin.get('files'), 'client')
        self.extracts = {}
        for ex in lock['extracts']:
            if not isinstance(ex, dict) or set(ex) != {'server','version_id','kind','path','provenance_sha256','files'}:
                _fail('store_invalid_lock', 'Invalid extract record shape')
            server = ex['server']; kind = _token(ex['kind'])
            if not isinstance(server,str) or server not in lock['pins'] or ex['version_id'] != lock['pins'][server]['version_id']:
                _fail('store_mixed_version', 'Extract is not the pinned version')
            expected = f'extracts/{server}/{ex["version_id"]}/{kind}'
            _relative(self.root, ex['path'])
            if ex['path'] != expected:
                _fail('store_mixed_version', 'Extract path does not name the pin/kind')
            sha = ex['provenance_sha256']
            if not isinstance(sha, str) or not _SHA.fullmatch(sha):
                _fail('store_invalid_lock', 'Invalid provenance hash')
            _hashes(ex['files'], 'extract')
            if 'provenance.json' in ex['files'] or (server,kind) in self.extracts:
                _fail('store_invalid_lock', 'Duplicate extract or reserved provenance entry')
            self.extracts[(server,kind)] = deepcopy(ex)

    def status(self):
        return {'state': 'connected' if self.root.is_dir() else 'disconnected',
                'store_root': str(self.root), 'pins': deepcopy(self.lock['pins']),
                'extracts': deepcopy(self.lock['extracts']), 'verification': 'not_verified',
                'missing_kinds': ['addressables-catalog'] if not any(k=='addressables-catalog' for _,k in self.extracts) else []}

    def _connected(self):
        if not self.root.is_dir():
            _fail('store_disconnected', 'Client data store is not connected')

    def _manifest(self, server, version):
        self._connected()
        if server not in ('jp','steam') or not _token(version).startswith(server+'-'):
            _fail('store_mixed_version', 'Version/server mismatch')
        path = _relative(self.root, f'clients/{server}/{version}/manifest.json')
        raw = _read(path); value = _decode(raw)
        if not isinstance(value, dict) or value.get('schema') != 'ba-client-data.client-manifest.v1':
            _fail('store_malformed_data', 'Invalid client manifest')
        if (value.get('server'),value.get('version_id')) != (server,version):
            _fail('store_mixed_version', 'Manifest identity mismatch')
        if any(value.get(key) is not None and not isinstance(value[key],str) for key in ('client_version','bundle_revision')):
            _fail('store_malformed_data', 'Invalid nullable manifest metadata')
        files = value.get('files')
        if not isinstance(files,dict) or not files:
            _fail('store_malformed_data', 'Missing manifest file hashes')
        pin = self.lock['pins'].get(server)
        if pin and pin['version_id']==version:
            for name,sha in pin['files'].items():
                if not isinstance(files.get(name),dict) or files[name].get('sha256')!=sha:
                    _fail('store_hash_mismatch', 'Pinned client manifest changed')
        return value, hashlib.sha256(raw).hexdigest()

    def versions(self):
        if not self.root.is_dir():
            return {'state':'disconnected','versions':[]}
        rows = []
        for server in ('jp','steam'):
            directory = _relative(self.root, 'clients/'+server)
            if not directory.exists(): continue
            for entry in sorted(directory.iterdir(),key=lambda p:p.name):
                if not entry.is_dir() or not _relative(directory,entry.name+'/manifest.json').is_file(): continue
                manifest,sha = self._manifest(server,entry.name)
                rows.append({'server':server,'version_id':entry.name,
                             'pinned':self.lock['pins'].get(server,{}).get('version_id')==entry.name,
                             'client_version':manifest.get('client_version'),
                             'bundle_revision':manifest.get('bundle_revision'),
                             'manifest_sha256':sha,'verification':'manifest_only'})
        return {'state':'connected','versions':rows}

    def read_extract(self, server: str, kind: str, relative_file: str) -> bytes:
        self._connected()
        ex = self.extracts.get((server,kind))
        if ex is None or relative_file not in ex['files']:
            _fail('store_unpinned_extract', 'Requested kind/file is not lock-pinned')
        self._manifest(server,ex['version_id'])
        base = _relative(self.root,ex['path'])
        prov_raw = _read(_relative(base,'provenance.json'))
        if hashlib.sha256(prov_raw).hexdigest()!=ex['provenance_sha256']:
            _fail('store_hash_mismatch', 'Extract provenance hash mismatch')
        prov = _decode(prov_raw)
        if not isinstance(prov,dict) or prov.get('schema')!='ba-client-data.extract-provenance.v1':
            _fail('store_malformed_data', 'Invalid extract provenance')
        if (prov.get('server'),prov.get('version_id'),prov.get('kind'))!=(server,ex['version_id'],kind):
            _fail('store_mixed_version', 'Extract provenance identity mismatch')
        if prov.get('client_manifest_files')!=self.lock['pins'][server]['files']:
            _fail('store_mixed_version', 'Extract originated from different client hashes')
        claims = prov.get('hash_claims',[])
        if not isinstance(claims,list) or any(not isinstance(c,dict) or c.get('matches_client_manifest') is not True for c in claims):
            _fail('store_mixed_version', 'Declared extract source hash mismatch')
        records = prov.get('files')
        if not isinstance(records,list): _fail('store_malformed_data','Missing provenance file list')
        actual = {}
        for row in records:
            if not isinstance(row,dict) or set(row)!={'path','sha256','size'}:
                _fail('store_malformed_data','Invalid provenance file entry')
            _parts(row['path'])
            if row['path'] in actual or type(row['size']) is not int or row['size']<0:
                _fail('store_malformed_data','Duplicate/invalid provenance file entry')
            actual[row['path']] = row
        if {p:r['sha256'] for p,r in actual.items()}!=ex['files']:
            _fail('store_hash_mismatch','Lock/provenance file hash inventory mismatch')
        verified = {}
        for name,sha in ex['files'].items():
            raw = _read(_relative(base,name))
            if len(raw)!=actual[name]['size'] or hashlib.sha256(raw).hexdigest()!=sha:
                _fail('store_hash_mismatch','Extract file bytes/hash mismatch')
            verified[name] = raw
        return verified[relative_file]

    def read_json_extract(self, server, kind, relative_file):
        return _decode(self.read_extract(server,kind,relative_file))

    def diff(self, before: dict, after: dict):
        for ref in (before,after):
            if not isinstance(ref,dict) or set(ref)!={'server','version_id'}:
                _fail('store_invalid_request','from/to require server and version_id')
            if ref['server'] not in ('jp','steam') or not _token(ref['version_id']).startswith(ref['server']+'-'):
                _fail('store_mixed_version','Invalid comparison identity')
        if before['server']!=after['server']:
            _fail('store_mixed_version','Cross-server comparison is unsupported')
        result={'state':'disconnected','from':deepcopy(before),'to':deepcopy(after),'report':None,
                'coverage':'existing-report-only; intersection kinds; no stable-ID or L3 inference',
                'verification':'not_verified'}
        if not self.root.is_dir(): return result
        server=before['server']; a=before['version_id']; b=after['version_id']
        self._manifest(server,a); self._manifest(server,b)
        path=_relative(self.root,f'changelog/{server}/{a}__{b}.json')
        if not path.exists():
            result['state']='missing'
            return result
        report=_decode(_read(path))
        required={'schema','server','a','b','generated_utc','level1_files','level2_extracts','level3_behavior'}
        if not isinstance(report,dict) or set(report)!=required or report['schema']!='ba-client-data.changelog.v1':
            _fail('store_malformed_data','Invalid changelog report shape')
        if (report['server'],report['a'],report['b'])!=(server,a,b):
            _fail('store_mixed_version','Report from/to identity mismatch')
        if not isinstance(report['level1_files'],dict) or any(v not in ('same','changed','only_in_a','only_in_b') for v in report['level1_files'].values()):
            _fail('store_malformed_data','Invalid L1 file statuses')
        if not isinstance(report['level2_extracts'],dict) or any(not isinstance(v,dict) for v in report['level2_extracts'].values()):
            _fail('store_malformed_data','Invalid L2 extract objects')
        if not isinstance(report['generated_utc'],str) or not isinstance(report['level3_behavior'],str):
            _fail('store_malformed_data','Invalid report metadata')
        try:
            timestamp=datetime.fromisoformat(report['generated_utc'].replace('Z','+00:00'))
            valid=timestamp.tzinfo is not None and timestamp.utcoffset()==timezone.utc.utcoffset(timestamp)
        except ValueError:
            valid=False
        if not valid:
            _fail('store_malformed_data','Invalid UTC report timestamp')
        result.update(state='available',report=report,verification='report_identity_only')
        return result

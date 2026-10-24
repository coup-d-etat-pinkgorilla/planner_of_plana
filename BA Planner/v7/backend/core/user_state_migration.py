"""Copy legacy user state once into v7, preserving every original byte."""
from contextlib import ExitStack, contextmanager
import hashlib
import json
import os
import ntpath
from pathlib import Path
import shutil
import uuid

FOLDERS=('repository','recognition-assets','recognition-synth-cache','assets')
MIGRATION_BLOCKED_MESSAGE = (
    '사용자 자료 이관을 완료하지 못했습니다. 기존 자료는 보존되어 있습니다. '
    '오류 원인을 해결한 뒤 앱을 다시 실행해 주세요.'
)
MIGRATION_FAILURE_REASONS = frozenset({
    'user_data_busy', 'user_data_link_not_migrated', 'user_data_folder_invalid',
    'v7_user_root_invalid', 'v7_destination_unrecognised',
    'legacy_repository_recovery_required', 'user_data_changed_during_migration',
    'user_data_io_error', 'user_data_migration_failed',
})


class UserStateMigrationError(RuntimeError):
    pass


def _windows_extended_name(absolute):
    """Normalize before the prefix: extended Win32 paths bypass normalization."""
    name = ntpath.normpath(str(absolute))
    if name.startswith('\\\\?\\'):
        return name
    if not ntpath.isabs(name):
        raise ValueError('extended paths must be absolute')
    if name.startswith('\\\\'):
        return '\\\\?\\UNC\\' + name[2:]
    drive, tail = ntpath.splitdrive(name)
    if len(drive) != 2 or drive[1] != ':' or not tail.startswith('\\'):
        raise ValueError('extended path needs an absolute drive or UNC share')
    return '\\\\?\\' + name


def _filesystem_path(path):
    path = Path(path).absolute()
    return Path(_windows_extended_name(path)) if os.name == 'nt' else path


def migration_failure_details(error):
    reason = str(error) if isinstance(error, UserStateMigrationError) else 'user_data_io_error'
    if reason not in MIGRATION_FAILURE_REASONS:
        reason = 'user_data_migration_failed'
    return {'reason':reason, 'source_kept':True, 'restart_required':True}


class MigrationBlockedProtocol:
    """A startup failure cannot expose an empty or partially migrated repository."""
    def __init__(self, error):
        self.details = migration_failure_details(error)

    def handle(self, message):
        from core.protocol_envelope_v1 import trusted_request
        request = trusted_request(message)
        if request is None:
            return None
        return {'protocol':1, 'id':request['id'], 'type':'response', 'method':request['method'],
                'payload':{'error':{'code':'user_data_migration_failed',
                    'message':MIGRATION_BLOCKED_MESSAGE, 'details':dict(self.details)}}}


def legacy_user_root(environ=None):
    environ=os.environ if environ is None else environ
    return (Path(environ['LOCALAPPDATA'])/'BA Planner' if environ.get('LOCALAPPDATA')
            else Path.home()/'.ba-planner')


def user_root(environ=None):
    environ=os.environ if environ is None else environ
    return (Path(environ['BA_PLANNER_USER_DIR']).expanduser() if environ.get('BA_PLANNER_USER_DIR')
            else legacy_user_root(environ)/'v7')


def _no_link(path):
    if path.is_symlink() or getattr(path.lstat(),'st_file_attributes',0)&0x400:
        raise UserStateMigrationError('user_data_link_not_migrated')


def _inventory(root):
    root = _filesystem_path(root)
    result={}
    for name in FOLDERS:
        directory=root/name
        if not directory.exists():continue
        _no_link(directory)
        if not directory.is_dir():raise UserStateMigrationError('user_data_folder_invalid')
        for path in directory.rglob('*'):
            _no_link(path)
            if path.is_file():
                relative=path.relative_to(root).as_posix()
                # Guard files belong to the old process, never to the copy.
                if path.name in {'.repository.guard','.repository.lock'}:continue
                raw=path.read_bytes()
                result[relative]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    return result


@contextmanager
def _guard(path):
    # The persistent file is an anchor; only the held OS lock means "busy".
    path = _filesystem_path(path)
    descriptor=os.open(path,os.O_CREAT|os.O_RDWR,0o600)
    acquired=False
    try:
        if os.fstat(descriptor).st_size==0:os.write(descriptor,b'0')
        os.lseek(descriptor,0,os.SEEK_SET)
        try:
            if os.name=='nt':
                import msvcrt
                msvcrt.locking(descriptor,msvcrt.LK_NBLCK,1)
            else:
                import fcntl
                fcntl.flock(descriptor,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except OSError as error:
            raise UserStateMigrationError('user_data_busy') from error
        acquired=True
        yield
    finally:
        if acquired:
            os.lseek(descriptor,0,os.SEEK_SET)
            if os.name=='nt':
                import msvcrt
                msvcrt.locking(descriptor,msvcrt.LK_UNLCK,1)
            else:
                import fcntl
                fcntl.flock(descriptor,fcntl.LOCK_UN)
        os.close(descriptor)


def migrate(legacy_root,*,copy_file=shutil.copy2):
    supplied=_filesystem_path(legacy_root)
    if supplied.exists():_no_link(supplied)
    legacy=_filesystem_path(supplied.resolve())
    legacy.mkdir(parents=True,exist_ok=True)
    _no_link(legacy)
    destination=legacy/'v7'
    with _guard(legacy/'.v7-migration.guard'),ExitStack() as stack:
        if destination.exists():
            _no_link(destination)
            if not destination.is_dir():raise UserStateMigrationError('v7_user_root_invalid')
            if not (destination/'.v7-migration.json').is_file() and not (destination/'repository/catalog.json').is_file():
                raise UserStateMigrationError('v7_destination_unrecognised')
            return {'state':'existing','source_kept':True,'copied_files':0}
        repository=legacy/'repository'
        if repository.exists():
            _no_link(repository)
            stack.enter_context(_guard(repository/'.repository.guard'))
            # Let the existing repository recovery path resolve any incomplete
            # journal before migration; never snapshot an in-flight transaction.
            if any((repository/name).exists() for name in (
                    '.repository.transaction.json','.profile-delete.transaction.json',
                    '.tactical.lock','.tactical-v2.lock','.tactical-share-v1.lock','.repository.lock')):
                raise UserStateMigrationError('legacy_repository_recovery_required')
        before=_inventory(legacy)
        staging=legacy/('.v7-migration-'+uuid.uuid4().hex)
        staging.mkdir()
        try:
            for relative in before:
                source=legacy/relative
                target=staging/relative
                target.parent.mkdir(parents=True,exist_ok=True)
                copy_file(source,target)
            if _inventory(staging)!=before or _inventory(legacy)!=before:
                raise UserStateMigrationError('user_data_changed_during_migration')
            record={'schemaVersion':1,'state':'copied','source_kept':True,'files':before}
            with (staging/'.v7-migration.json').open('w',encoding='utf-8') as out:
                json.dump(record,out,sort_keys=True);out.write('\n');out.flush();os.fsync(out.fileno())
            os.rename(staging,destination)
            return {'state':'copied','source_kept':True,'copied_files':len(before)}
        finally:
            if staging.exists():
                # Only the fresh UUID staging owned by this invocation is removed.
                assert staging.resolve().parent==legacy and staging.name.startswith('.v7-migration-')
                _no_link(staging)
                shutil.rmtree(staging)


def ensure_default_user_root(environ=None):
    environ=os.environ if environ is None else environ
    if environ.get('BA_PLANNER_USER_DIR') or environ.get('BA_PLANNER_STORAGE_ROOT'):
        return {'state':'explicit-override','source_kept':True,'copied_files':0}
    return migrate(legacy_user_root(environ))

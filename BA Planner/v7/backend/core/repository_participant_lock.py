"""Root guard before compatibility store markers; known crashed owners are recoverable."""
from dataclasses import dataclass
import json
import os
from pathlib import Path

from core.repository_dto import canonical_json
from core.repository_transaction import Lease, acquire, release

MARKERS = ('.tactical.lock', '.tactical-v2.lock', '.tactical-share-v1.lock')


def _owned(value, name):
    return (isinstance(value, dict) and set(value) == {'version', 'owner', 'marker'}
            and type(value['version']) is int and value['version'] == 1
            and value['owner'] == 'repository_participant' and value['marker'] == name)


def discard_stale_participants_locked(root: Path) -> None:
    """The caller has newly acquired the OS guard, excluding live participants.

    A crash can precede journal creation or follow journal removal. Normal reads
    also reclaim our exact owned markers in these two cases; manual markers stay.
    Reentrant root acquisitions never run this cleanup while markers are live.
    """
    for name in MARKERS:
        marker = root / name
        if marker.is_symlink() or not marker.exists():
            continue
        try:
            known = _owned(json.loads(marker.read_text(encoding='utf-8')), name)
        except (OSError, ValueError, UnicodeError):
            known = False
        if known:
            marker.unlink()


@dataclass
class ParticipantLease:
    guard: Lease
    marker: Path
    descriptor: int


def acquire_participant(root: Path, name: str, error_type) -> ParticipantLease:
    assert name in MARKERS
    guard = acquire(root, error_type)
    marker = guard.root / name
    descriptor = -1
    owned = False
    expected = {'version': 1, 'owner': 'repository_participant', 'marker': name}
    try:
        if marker.is_symlink() or marker.resolve() != marker:
            raise error_type('corrupt_data', 'participant marker is not a canonical path')
        if marker.exists():
            # New OS guard acquisitions already removed our crashed markers.
            # A marker surviving a reentrant guard may still be owned by this
            # thread; never unlink it while its participant lease is live.
            raise error_type('repository_busy', 'a participant lock already exists', retryable=True)
        descriptor = os.open(marker, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        owned = True
        raw = canonical_json(expected).encode('utf-8')
        with os.fdopen(descriptor, 'wb', closefd=False) as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        return ParticipantLease(guard, marker, descriptor)
    except Exception:
        try:
            if descriptor >= 0:
                os.close(descriptor)
            if owned:
                marker.unlink(missing_ok=True)
        finally:
            release(guard)
        raise


def release_participant(lease: ParticipantLease) -> None:
    try:
        try:
            os.close(lease.descriptor)
        finally:
            lease.marker.unlink(missing_ok=True)
    except OSError as error:
        raise lease.guard.error_type('persistence_failed', 'participant lock cleanup failed', retryable=True) from error
    finally:
        release(lease.guard)

"""One process-released repository lock and durable before/after journal.

Order: OS guard -> compatibility marker -> recovery -> repository files.
All nested reads on the same thread/root reuse the guard. No second store lock.
"""
from __future__ import annotations

import base64
from dataclasses import dataclass
from functools import wraps
import hashlib
import json
import os
from pathlib import Path
import re
import threading
from typing import Any, Callable
import uuid

from core.repository_dto import canonical_json

JOURNAL = ".repository.transaction.json"
_MARKER = {"version": 1, "owner": "repository_transaction"}
_mutex = threading.Lock()
_leases: dict[str, "Lease"] = {}


@dataclass
class Lease:
    root: Path
    key: str
    thread: int
    error_type: type[RuntimeError]
    descriptor: int = -1
    depth: int = 1


def _os_lock(descriptor: int, *, unlock: bool = False) -> None:
    if os.name == "nt":
        import msvcrt
        os.lseek(descriptor, 0, os.SEEK_SET)
        msvcrt.locking(descriptor, msvcrt.LK_UNLCK if unlock else msvcrt.LK_NBLCK, 1)
    else:
        import fcntl
        fcntl.flock(descriptor, fcntl.LOCK_UN if unlock else fcntl.LOCK_EX | fcntl.LOCK_NB)


def _write_bytes(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _image(content: bytes | None) -> dict[str, str] | None:
    if content is None:
        return None
    return {"data": base64.b64encode(content).decode("ascii"), "sha256": hashlib.sha256(content).hexdigest()}


def _decode(value: object) -> bytes | None:
    if value is None:
        return None
    if not isinstance(value, dict) or set(value) != {"data", "sha256"}:
        raise ValueError("invalid journal image")
    content = base64.b64decode(value["data"], validate=True)
    if hashlib.sha256(content).hexdigest() != value["sha256"]:
        raise ValueError("journal image checksum mismatch")
    return content


def _target(root: Path, name: object) -> Path:
    if not isinstance(name, str) or re.fullmatch(r"catalog\.json|(?:profiles|scenarios)/[0-9a-f]{24}\.json", name) is None:
        raise ValueError("invalid journal target")
    path = root / name
    if not path.resolve().is_relative_to(root.resolve()):
        raise ValueError("journal target escapes repository")
    return path


def recover_locked(root: Path, error_type: type[RuntimeError]) -> None:
    path = root / JOURNAL
    if not path.exists():
        return
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(value, dict) or set(value) != {"version", "state", "writes"} or type(value["version"]) is not int or value["version"] != 1 or value["state"] not in ("prepared", "committed"):
            raise ValueError("invalid journal header")
        if not isinstance(value["writes"], list) or not 1 <= len(value["writes"]) <= 3:
            raise ValueError("invalid journal writes")
        writes = []
        seen = set()
        for item in value["writes"]:
            if not isinstance(item, dict) or set(item) != {"path", "before", "after"} or item["path"] in seen:
                raise ValueError("invalid journal entry")
            target = _target(root, item["path"])
            seen.add(item["path"])
            before, after = _decode(item["before"]), _decode(item["after"])
            if after is None:
                raise ValueError("missing journal after image")
            writes.append((target, before if value["state"] == "prepared" else after))
    except (ValueError, TypeError, KeyError, UnicodeError, OSError) as error:
        raise error_type("corrupt_data", "repository transaction journal cannot be read", details={"reason": str(error)}) from error
    try:
        # Validate every image/path before applying any. Repeating recovery is safe.
        for target, content in writes:
            if content is None:
                target.unlink(missing_ok=True)
            else:
                _write_bytes(target, content)
        path.unlink()
    except OSError as error:
        raise error_type("persistence_failed", "repository transaction recovery failed", retryable=True) from error


def acquire(root: Path, error_type: type[RuntimeError]) -> Lease:
    root = root.resolve()
    key = os.path.normcase(str(root))
    thread = threading.get_ident()
    with _mutex:
        existing = _leases.get(key)
        if existing is not None:
            if existing.thread != thread:
                raise error_type("repository_busy", "another repository reader/writer holds the lock", retryable=True)
            existing.depth += 1
            return existing
        lease = Lease(root, key, thread, error_type)
        _leases[key] = lease
    marker = root / ".repository.lock"
    locked = False
    marker_owned = False
    try:
        root.mkdir(parents=True, exist_ok=True)
        lease.descriptor = os.open(root / ".repository.guard", os.O_CREAT | os.O_RDWR, 0o600)
        if os.fstat(lease.descriptor).st_size == 0:
            os.write(lease.descriptor, b"0")
        try:
            _os_lock(lease.descriptor)
        except OSError as error:
            raise error_type("repository_busy", "another repository reader/writer holds the lock", retryable=True) from error
        locked = True
        if marker.exists():
            try:
                stale = json.loads(marker.read_text(encoding="utf-8")) == _MARKER
            except (OSError, ValueError, UnicodeError):
                stale = False
            if not stale:
                # Keep older/manual locks meaningful; never guess their owner died.
                raise error_type("repository_busy", "an unrecognized repository lock exists", retryable=True)
        _write_bytes(marker, canonical_json(_MARKER).encode("utf-8"))
        marker_owned = True
        recover_locked(root, error_type)
        return lease
    except Exception as error:
        cleanup_error = None
        try:
            if marker_owned:
                marker.unlink(missing_ok=True)
        except OSError as failed:
            cleanup_error = failed
        finally:
            try:
                if locked:
                    _os_lock(lease.descriptor, unlock=True)
            finally:
                if lease.descriptor >= 0:
                    os.close(lease.descriptor)
                with _mutex:
                    _leases.pop(key, None)
        if cleanup_error is not None:
            raise error_type("persistence_failed", "repository lock cleanup failed", retryable=True) from cleanup_error
        if hasattr(error, "code"):
            raise
        raise error_type("persistence_failed", "repository lock could not be acquired", retryable=True) from error


def release(lease: Lease) -> None:
    with _mutex:
        lease.depth -= 1
        if lease.depth:
            return
        cleanup_error = None
        try:
            (lease.root / ".repository.lock").unlink(missing_ok=True)
        except OSError as error:
            cleanup_error = error
        finally:
            try:
                _os_lock(lease.descriptor, unlock=True)
            finally:
                os.close(lease.descriptor)
                _leases.pop(lease.key, None)
        if cleanup_error is not None:
            raise lease.error_type("persistence_failed", "repository lock cleanup failed", retryable=True) from cleanup_error


def locked(error_type: type[RuntimeError]):
    def decorate(method):
        @wraps(method)
        def wrapped(self, *args, **kwargs):
            lease = acquire(self.root, error_type)
            try:
                return method(self, *args, **kwargs)
            finally:
                release(lease)
        return wrapped
    return decorate


def write_transaction(
    root: Path,
    writes: list[tuple[Path, dict[str, Any]]],
    write: Callable[[Path, dict[str, Any]], None],
    fault: Callable[[str], None],
    error_type: type[RuntimeError],
) -> None:
    """Caller holds the guard. A durable commit marker selects before vs after."""
    journal = root / JOURNAL
    try:
        entries = []
        for path, value in writes:
            name = path.relative_to(root).as_posix()
            _target(root, name)
            entries.append({"path": name, "before": _image(path.read_bytes() if path.exists() else None), "after": _image(canonical_json(value).encode("utf-8"))})
        record = {"version": 1, "state": "prepared", "writes": entries}
        fault("before_journal")
        _write_bytes(journal, canonical_json(record).encode("utf-8"))
        fault("journal_prepared")
        for (path, value), stage in zip(writes, ("profile_written", "catalog_written", "scenarios_written")):
            write(path, value)
            fault(stage)
        fault("before_commit")
        record["state"] = "committed"
        _write_bytes(journal, canonical_json(record).encode("utf-8"))
        fault("journal_committed")
        journal.unlink()
        fault("journal_removed")
    except Exception as error:
        if journal.exists():
            recover_locked(root, error_type)
        if hasattr(error, "code"):
            raise
        raise error_type("persistence_failed", "repository transaction failed", retryable=True, details={"stage": str(error)}) from error

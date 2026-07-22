from __future__ import annotations

from collections import OrderedDict
from copy import deepcopy
import json
from queue import Empty, Full, Queue
from threading import RLock, Thread
from typing import Any, TextIO


_STOP = object()


class JsonlMultiplexer:
    """Serializes responses and scanner events without interleaving JSON lines."""

    def __init__(self, stdout: TextIO, *, capacity: int = 128) -> None:
        if capacity < 2:
            raise ValueError("JSONL queue capacity must be at least 2")
        self._stdout = stdout
        self._queue: Queue[dict[str, Any] | object] = Queue(maxsize=capacity)
        self._lock = RLock()
        self._session_lock = RLock()
        self._held: dict[str, list[dict[str, Any]]] = {}
        self._released: set[str] = set()
        self._coalesced: OrderedDict[tuple[str, int], dict[str, Any]] = OrderedDict()
        self._closed = False
        self._thread = Thread(target=self._run, name="jsonl-output", daemon=True)
        self._thread.start()

    def publish_response(self, response: dict[str, Any]) -> None:
        self._reliable_put(deepcopy(response))
        if response.get("method") != "scanner.session.start":
            return
        payload = response.get("payload")
        if not isinstance(payload, dict) or "error" in payload:
            return
        session_id = payload.get("session_id")
        if not isinstance(session_id, str):
            return
        with self._session_lock:
            events = self._held.pop(session_id, [])
            for event in events:
                self._enqueue_event(event)
            self._released.add(session_id)

    def publish_event(self, event: dict[str, Any]) -> None:
        payload = event.get("payload")
        session_id = payload.get("session_id") if isinstance(payload, dict) else None
        if not isinstance(session_id, str):
            raise ValueError("scanner event requires session_id")
        with self._session_lock:
            if session_id not in self._released:
                held = self._held.setdefault(session_id, [])
                if payload.get("event_kind") == "progress" and held and held[-1].get("payload", {}).get("event_kind") == "progress":
                    held[-1] = deepcopy(event)
                else:
                    held.append(deepcopy(event))
                return
        self._enqueue_event(deepcopy(event))

    def close(self) -> None:
        with self._lock:
            if self._closed:
                return
            self._closed = True
        self._flush_coalesced(block=True)
        self._queue.put(_STOP)
        self._thread.join(timeout=5)
        if self._thread.is_alive():
            raise RuntimeError("JSONL writer did not stop")

    def _enqueue_event(self, event: dict[str, Any]) -> None:
        payload = event["payload"]
        if payload.get("event_kind") != "progress":
            self._flush_coalesced(block=True)
            self._reliable_put(event)
            return
        try:
            self._queue.put_nowait(event)
        except Full:
            key = (payload["session_id"], payload["generation"])
            with self._lock:
                self._coalesced[key] = event
                self._coalesced.move_to_end(key)

    def _reliable_put(self, message: dict[str, Any]) -> None:
        with self._lock:
            if self._closed:
                raise RuntimeError("JSONL multiplexer is closed")
        self._queue.put(message)

    def _flush_coalesced(self, *, block: bool = False) -> None:
        while True:
            with self._lock:
                if not self._coalesced:
                    return
                key, event = next(iter(self._coalesced.items()))
            try:
                self._queue.put(event, block=block, timeout=1 if block else None)
            except Full:
                return
            with self._lock:
                if self._coalesced.get(key) is event:
                    self._coalesced.pop(key, None)

    def _run(self) -> None:
        while True:
            item = self._queue.get()
            try:
                if item is _STOP:
                    return
                self._stdout.write(json.dumps(item, ensure_ascii=True, separators=(",", ":")))
                self._stdout.write("\n")
                self._stdout.flush()
                self._flush_coalesced()
            finally:
                self._queue.task_done()

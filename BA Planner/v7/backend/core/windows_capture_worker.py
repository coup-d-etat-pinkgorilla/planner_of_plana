"""Private capture-only process. The parent never waits in a Win32 render call."""
from __future__ import annotations

import json
from pathlib import Path
from queue import Empty, Full, Queue
import struct
import subprocess
import sys
from threading import Event, Lock, Thread
from time import monotonic

from PIL import Image
from core.scanner_session import ScannerError


def _read(stream, size):
    data = stream.read(size)
    if len(data) != size:
        raise EOFError("capture worker stream closed")
    return data


class CaptureWorker:
    def __init__(self):
        self.process = None
        self._thread = None
        self._results = None
        self._lock = Lock()

    def _start(self):
        self.process = subprocess.Popen(
            [sys.executable, "-u", "-m", "core.windows_capture_worker"],
            cwd=str(Path(__file__).resolve().parents[1]),
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        self._results = Queue(maxsize=1)
        stream, results = self.process.stdout, self._results

        def receive():
            try:
                while True:
                    length = struct.unpack("<I", _read(stream, 4))[0]
                    if length > 65536:
                        raise ValueError("oversized capture header")
                    header = json.loads(_read(stream, length))
                    size = header.get("size")
                    raw = b""
                    if size is not None:
                        width, height = size
                        if not (isinstance(width, int) and isinstance(height, int)
                                and width > 0 and height > 0 and width * height <= 16_777_216):
                            raise ValueError("invalid capture dimensions")
                        raw = _read(stream, width * height * 3)
                    results.put_nowait((header, raw))
            except Exception as exc:
                try:
                    results.put_nowait(exc)
                except Full:
                    pass

        self._thread = Thread(target=receive, name="capture-worker-reader", daemon=True)
        self._thread.start()

    def capture(self, target, title_contains, cancel, deadline):
        if not self._lock.acquire(timeout=max(0, deadline - monotonic())):
            raise ScannerError("capture_timeout", "capture worker busy")
        try:
            if cancel.is_set() or monotonic() >= deadline:
                raise ScannerError("cancelled" if cancel.is_set() else "capture_timeout", "capture not started")
            if self.process is None or self.process.poll() is not None:
                self.close()
                self._start()
            self.process.stdin.write((json.dumps({"target": target, "title_contains": title_contains,
                                                "deadline": deadline}) + "\n").encode("utf-8"))
            self.process.stdin.flush()
            while True:
                if cancel.is_set() or monotonic() >= deadline:
                    self.close()
                    code = "cancelled" if cancel.is_set() else "capture_timeout"
                    raise ScannerError(code, "capture worker stopped", details={"trace": [{"worker_terminated": code}]})
                try:
                    response = self._results.get(timeout=min(0.02, max(0, deadline - monotonic())))
                except Empty:
                    continue
                if isinstance(response, Exception):
                    self.close()
                    raise ScannerError("capture_failed", "capture worker stream failed") from response
                header, raw = response
                if "error" in header:
                    raise ScannerError(header["error"]["code"], header["error"]["message"],
                                       details={"trace": header["trace"]})
                return Image.frombytes("RGB", tuple(header["size"]), raw), header["trace"]
        except (OSError, ValueError) as exc:
            self.close()
            raise ScannerError("capture_failed", "capture worker unavailable") from exc
        finally:
            self._lock.release()

    def close(self):
        process, self.process = self.process, None
        if process is not None:
            if process.poll() is None:
                process.kill()
            process.wait(timeout=1)
            if self._thread is not None:
                self._thread.join(timeout=1)
            process.stdin.close()
            process.stdout.close()
        self._thread = self._results = None


def main():
    from core.windows_scanner_adapter import WindowsCaptureInputAdapter

    adapter = WindowsCaptureInputAdapter(isolate_capture=False)
    for line in sys.stdin.buffer:
        frame = None
        try:
            request = json.loads(line)
            adapter.title_contains = request["title_contains"]
            frame = adapter._capture_direct(request["target"], Event(), request["deadline"])
            header = {"size": list(frame.size), "trace": adapter.last_capture_trace}
        except Exception as exc:
            header = {"error": {"code": getattr(exc, "code", "capture_failed"), "message": str(exc)},
                      "trace": adapter.last_capture_trace}
        try:
            encoded = json.dumps(header).encode("utf-8")
            sys.stdout.buffer.write(struct.pack("<I", len(encoded)))
            sys.stdout.buffer.write(encoded)
            if frame is not None:
                sys.stdout.buffer.write(frame.tobytes())
            sys.stdout.buffer.flush()
        finally:
            if frame is not None:
                frame.close()


if __name__ == "__main__":
    main()

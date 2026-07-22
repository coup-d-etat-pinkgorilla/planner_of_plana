from __future__ import annotations

import json
import sys
import traceback
from typing import TextIO

from core.protocol_v1 import PlanningProtocolV1


def serve(
    stdin: TextIO = sys.stdin,
    stdout: TextIO = sys.stdout,
    stderr: TextIO = sys.stderr,
    *,
    protocol: object | None = None,
) -> None:
    handler = protocol or PlanningProtocolV1(
        diagnostic=lambda message: print(message, file=stderr, end="", flush=True)
    )
    for raw_line in stdin:
        if not raw_line.strip():
            continue
        try:
            message = json.loads(raw_line)
        except (json.JSONDecodeError, UnicodeError):
            print("Ignoring malformed JSON protocol line", file=stderr, flush=True)
            continue
        try:
            response = handler.handle(message)  # type: ignore[attr-defined]
        except Exception:
            traceback.print_exc(file=stderr)
            continue
        if response is None:
            print("Ignoring untrusted protocol envelope", file=stderr, flush=True)
            continue
        stdout.write(json.dumps(response, ensure_ascii=True, separators=(",", ":")))
        stdout.write("\n")
        stdout.flush()

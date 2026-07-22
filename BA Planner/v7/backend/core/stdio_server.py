from __future__ import annotations

import json
import sys
import traceback
from typing import TextIO

from core.protocol_v1 import PlanningProtocolV1
from core.jsonl_multiplexer import JsonlMultiplexer


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
    output = JsonlMultiplexer(stdout)
    bind_event_sink = getattr(handler, "bind_event_sink", None)
    if callable(bind_event_sink):
        bind_event_sink(output.publish_event)
    try:
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
            output.publish_response(response)
    finally:
        close_handler = getattr(handler, "close", None)
        if callable(close_handler):
            close_handler()
        output.close()

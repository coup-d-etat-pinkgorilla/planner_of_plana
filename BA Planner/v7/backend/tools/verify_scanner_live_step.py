"""One explicitly selected, read-only scanner UI step with a local evidence receipt.

Inspect the last screenshot before each invocation. This is not an unattended scan.
Never supply growth, purchase, equipment-change or account-action coordinates.
"""
from __future__ import annotations

import argparse
from datetime import datetime
from hashlib import sha256
import json
from pathlib import Path
import sys
from threading import Event
from time import monotonic

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("capture", "left", "right", "click"))
    parser.add_argument("--target", required=True)
    parser.add_argument("--record", required=True, type=Path)
    parser.add_argument("--x", type=float)
    parser.add_argument("--y", type=float)
    args = parser.parse_args()
    adapter = WindowsCaptureInputAdapter()
    receipt = {"at": datetime.now().astimezone().isoformat(), "action": args.action,
               "target_id": args.target, "input": {}, "status": "failed"}
    started = monotonic()
    try:
        targets = [t for t in adapter() if t["target_id"] == args.target and t["status"] == "ready"]
        if len(targets) != 1:
            raise RuntimeError("Selected game window is unavailable")
        target = targets[0]
        receipt["before"] = adapter.diagnose(target)
        if args.action == "click":
            if args.x is None or args.y is None:
                raise ValueError("Click requires observed client ratios")
            adapter.click(target, args.x, args.y)
        elif args.action in ("left", "right"):
            adapter.press_key(target, args.action)
        receipt["input"] = adapter.last_input_trace
        if args.action != "capture":
            Event().wait(.65)
        frame = adapter.wait_stable(target, Event(), timeout=3)
        try:
            args.record.parent.mkdir(parents=True, exist_ok=True)
            path = args.record.with_suffix(".png")
            frame.save(path)
            receipt.update(size=list(frame.size), image_sha256=sha256(path.read_bytes()).hexdigest(),
                           capture=adapter.last_capture_trace, after=adapter.diagnose(target), status="captured")
        finally:
            frame.close()
    except Exception as exc:
        receipt.update(error={"code": getattr(exc, "code", "probe_failed"), "message": str(exc)},
                       capture=adapter.last_capture_trace, input=adapter.last_input_trace)
        raise
    finally:
        adapter.close()
        receipt["seconds"] = monotonic() - started
        args.record.parent.mkdir(parents=True, exist_ok=True)
        args.record.with_suffix(".json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        print(json.dumps(receipt, ensure_ascii=False))


if __name__ == "__main__":
    main()

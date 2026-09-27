"""Run the production inventory adapter against the live game and record C2 evidence.

No repository or account data is written: only the candidate the adapter returns, the
inputs it sent and the distinct frames it saw are saved under --output.

  --profile P             explicit inventory scan profile (the game page must already show it)
  --cancel-after N        set the cancel token after N captures (cancel run)
  --restore-probe         scroll twice, then call restore_first_page and compare with page 0
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from threading import Event

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.inventory_detail_recovery import InventoryDetailRecognizer, InventoryDetailRecovery
from core.inventory_navigation import InventoryNavigation
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import InventoryMatcherAdapter
from core.scanner_session import ScanBatchResult, ScannerError
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


class RecordingCapture:
    """Windows port wrapper that logs inputs and keeps each distinct frame once."""

    def __init__(self, native, output: Path, cancel: Event, cancel_after: int | None) -> None:
        self.native, self.output, self.cancel, self.cancel_after = native, output, cancel, cancel_after
        self.log: list[dict] = []
        self.captures = 0
        self.seen: dict[str, str] = {}

    def _record(self, frame):
        digest = hashlib.sha256(frame.tobytes()).hexdigest()
        if digest not in self.seen:
            self.seen[digest] = f"frame-{len(self.seen):02d}.png"
            frame.save(self.output / self.seen[digest])
        self.captures += 1
        self.log.append({"capture": self.seen[digest]})
        if self.cancel_after is not None and self.captures >= self.cancel_after:
            self.cancel.set()
        return frame

    def wait_stable(self, target, cancel, timeout=2.0):
        return self._record(self.native.wait_stable(target, cancel, timeout))

    def capture(self, target, **kwargs):
        return self._record(self.native.capture(target, **kwargs))

    def click(self, target, x, y):
        self.log.append({"input": "click", "x": round(x, 6), "y": round(y, 6),
                         "cleanup": bool(target.get("_scanner_cleanup", False))})
        self.native.click(target, x, y)

    def scroll(self, target, delta):
        self.log.append({"input": "scroll", "delta": delta})
        self.native.scroll(target, delta)

    def drag_scroll(self, target, start, end):
        self.log.append({"input": "drag_scroll", "start": list(start), "end": list(end)})
        self.native.drag_scroll(target, start, end)

    def press_key(self, target, key):
        self.log.append({"input": "key", "key": key})
        return self.native.press_key(target, key)


def summarize(result) -> dict:
    batch = result if isinstance(result, ScanBatchResult) else ScanBatchResult(result)
    rows = []
    for row in batch.candidates:
        for crop in row.pop("_answer_specimen", {}).get("slot_crops", {}).values():
            crop.close()
        rows.append(row)
    error = batch.error
    return {"outcome": batch.outcome, "coverage_complete": batch.coverage_complete,
            "error": None if error is None else {"code": error.code, "message": error.message, "details": error.details},
            "candidates": rows}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cancel-after", type=int)
    parser.add_argument("--restore-probe", action="store_true")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    native = WindowsCaptureInputAdapter()
    cancel = Event()
    capture = RecordingCapture(native, args.output, cancel, args.cancel_after)
    catalog = RecognitionAssetCatalog()
    detail = InventoryDetailRecognizer(catalog)
    navigation = InventoryNavigation(capture, catalog, detail)
    report: dict = {"profile": args.profile, "cancel_after": args.cancel_after}
    try:
        target = next((item for item in native() if item["status"] == "ready"), None)
        if target is None:
            raise ScannerError("target_not_ready", "no ready game window; no input sent")
        target = {**target, "inventory_scan_profile": args.profile}
        report["size"] = list(native.wait_stable(target, Event()).size)
        if args.restore_probe:
            first = capture.wait_stable(target, cancel)
            source = detail.classify(first)
            prepared = navigation.prepare(target, cancel, first)
            page0 = capture.wait_stable(target, cancel)
            moved = navigation.advance(target, cancel, page0, source)
            moved = navigation.advance(target, cancel, moved.frame, source)
            report["scrolled_similarity_to_page0"] = navigation.page_similarity(
                navigation.signatures(page0, source), navigation.signatures(moved.frame, source))
            navigation.restore_first_page(target, Event(), moved.frame)
            back = capture.wait_stable(target, Event())
            report["restored_similarity_to_page0"] = navigation.page_similarity(
                navigation.signatures(page0, source), navigation.signatures(back, source))
            report["prepared"] = prepared.profile_id
        else:
            adapter = InventoryMatcherAdapter(capture, catalog, detail_recovery=InventoryDetailRecovery(capture, detail),
                                              navigation=navigation)
            report["result"] = summarize(adapter(target, cancel, lambda *_args: None))
        report["navigation_trace"] = navigation.trace
    except ScannerError as exc:
        report["error"] = {"code": exc.code, "message": exc.message, "details": exc.details}
    finally:
        report["inputs_and_captures"] = capture.log
        report["frames"] = {name: digest for digest, name in capture.seen.items()}
        (args.output / "trace.json").write_text(json.dumps(report, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        navigation.close()
        detail.close()
        native.close()
    result = report.get("result", {})
    print(json.dumps({key: report.get(key) for key in ("profile", "error", "scrolled_similarity_to_page0",
                                                         "restored_similarity_to_page0")} | {
        "outcome": result.get("outcome"), "coverage_complete": result.get("coverage_complete"),
        "result_error": result.get("error"),
        "entries": [len(row["payload"]["entries"]) for row in result.get("candidates", [])],
        "frames": len(capture.seen), "captures": capture.captures}, ensure_ascii=False))


if __name__ == "__main__":
    main()

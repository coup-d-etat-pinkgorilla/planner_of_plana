"""Summarize F12 production-process traces without replaying game input."""
from __future__ import annotations

import argparse
from collections import Counter
import json
import math
from pathlib import Path


def percentile(values: list[int], fraction: float) -> int | None:
    if not values:
        return None
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]


def summarize_trace(path: Path) -> dict[str, object]:
    report = json.loads(path.read_text(encoding="utf-8-sig"))
    events = report.get("events", [])
    times = [row["received_ms"] for row in events if isinstance(row.get("received_ms"), int)]
    gaps = [right - left for left, right in zip(times, times[1:])]
    candidates = report.get("snapshot", {}).get("candidates", [])
    evidence = [item for candidate in candidates for item in candidate.get("evidence", [])]
    terminal_events = [row for row in events if row.get("event_kind") == "terminal"]
    error = terminal_events[-1].get("payload", {}).get("error") if terminal_events else None
    return {
        "file": path.name,
        "kind": report.get("kind"),
        "student_scan_mode": report.get("student_scan_mode"),
        "elapsed_ms": report.get("elapsed_ms"),
        "terminal": report.get("snapshot", {}).get("terminal"),
        "terminal_error": error,
        "event_count": len(events),
        "candidate_count": len(candidates),
        "candidate_ids": [candidate.get("payload", {}).get("student_id") for candidate in candidates
                          if candidate.get("payload", {}).get("student_id")],
        "inventory_entry_count": sum(len(candidate.get("payload", {}).get("entries", [])) for candidate in candidates),
        "review_required_count": sum(bool(candidate.get("review_required")) for candidate in candidates),
        "evidence_status_counts": dict(sorted(Counter(item.get("status", "missing") for item in evidence).items())),
        "evidence_source_counts": dict(sorted(Counter(item.get("source", "missing") for item in evidence).items())),
        "event_gap_ms": {
            "p50": percentile(gaps, .50),
            "p95": percentile(gaps, .95),
            "max": max(gaps) if gaps else None,
        },
        "mutations": report.get("mutations"),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace-directory", type=Path, required=True)
    parser.add_argument("--resource-samples", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    traces = [summarize_trace(path) for path in sorted(args.trace_directory.glob("f12-process-*.json"))]
    samples = json.loads(args.resource_samples.read_text(encoding="utf-8-sig"))
    result = {
        "schema_version": 1,
        "evidence_partition": "new_f12_native_process_summary",
        "traces": traces,
        "resources": {
            "sample_count": len(samples),
            "working_set_bytes": {
                "first": samples[0]["working_set"], "last": samples[-1]["working_set"],
                "max": max(row["working_set"] for row in samples),
            },
            "private_memory_bytes": {
                "first": samples[0]["private_memory"], "last": samples[-1]["private_memory"],
                "max": max(row["private_memory"] for row in samples),
            },
            "handles": {
                "first": samples[0]["handles"], "last": samples[-1]["handles"],
                "max": max(row["handles"] for row in samples),
            },
        },
        "safety": {
            "review_calls": 0, "revalidation_calls": 0, "commit_calls": 0,
            "persistent_learning": 0, "profile_writes": 0, "game_consumable_actions": 0,
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"trace_count": len(traces), "terminals": Counter(row["terminal"] for row in traces)} , default=dict))


if __name__ == "__main__":
    main()

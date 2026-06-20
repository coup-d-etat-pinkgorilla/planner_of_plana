"""Summarize scanner [perf] lines from a scan debug log."""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.config import APP_DIR


PERF_RE = re.compile(r"\[perf\]\s+(?P<label>\S+)\s+elapsed=(?P<elapsed>[0-9.]+)s(?P<rest>.*)")
TOPK_CONFIG_RE = re.compile(r"student_texture_topk_config\b.*\bmethod=(?P<method>\S+)\s+k=(?P<k>\d+)")
TOPK_DECISION_RE = re.compile(r"texture_topk_(?P<decision>accept|fallback):\s+method=(?P<method>\S+)\s+k=(?P<k>\d+)")


def _latest_scan_log() -> Path:
    logs_dir = APP_DIR / "logs"
    candidates = sorted(logs_dir.glob("scan_*.log"), key=lambda p: p.stat().st_mtime)
    if not candidates:
        raise SystemExit(f"scan log not found: {logs_dir}")
    return candidates[-1]


def _field(rest: str, key: str) -> str | None:
    match = re.search(rf"(?:^|\s){re.escape(key)}=([^\s]+)", rest)
    return match.group(1) if match else None


def summarize(path: Path) -> None:
    groups: dict[str, list[float]] = defaultdict(list)
    by_student: dict[str, list[float]] = defaultdict(list)
    captures = {"ok": 0, "fail": 0}
    topk_configs: set[tuple[str, str]] = set()
    topk_decisions: dict[tuple[str, str, str], int] = defaultdict(int)
    basic_card = defaultdict(int)
    level_calibration = {"learned": 0, "rejected": 0}

    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            for field in ("level", "star"):
                if f"[basic_{field}] success" in line:
                    basic_card[(field, "success")] += 1
                elif f"[basic_{field}] fallback" in line:
                    basic_card[(field, "fallback")] += 1
            if "[basic_level_calibration] learned" in line:
                level_calibration["learned"] += 1
            elif "[basic_level_calibration] rejected" in line:
                level_calibration["rejected"] += 1
            config_match = TOPK_CONFIG_RE.search(line)
            if config_match:
                topk_configs.add((config_match.group("method"), config_match.group("k")))
            decision_match = TOPK_DECISION_RE.search(line)
            if decision_match:
                topk_decisions[
                    (
                        decision_match.group("method"),
                        decision_match.group("k"),
                        decision_match.group("decision"),
                    )
                ] += 1
            match = PERF_RE.search(line)
            if not match:
                continue
            label = match.group("label")
            elapsed = float(match.group("elapsed"))
            rest = match.group("rest")
            groups[label].append(elapsed)
            student = _field(rest, "student_name") or _field(rest, "student_id")
            if label == "student.total" and student:
                by_student[student].append(elapsed)
            if label == "capture":
                if "success=true" in rest:
                    captures["ok"] += 1
                elif "success=false" in rest:
                    captures["fail"] += 1

    print(f"Log: {path}")
    print()
    print("Step summary")
    print("count  total(s)   avg(s)   max(s)  label")
    for label, values in sorted(groups.items(), key=lambda item: sum(item[1]), reverse=True):
        total = sum(values)
        avg = total / max(1, len(values))
        print(f"{len(values):5d}  {total:8.2f}  {avg:7.3f}  {max(values):7.3f}  {label}")

    print()
    print(f"Capture: ok={captures['ok']} fail={captures['fail']}")

    if basic_card:
        print()
        print("Basic student card")
        print("field     success  fallback")
        for field in ("level", "star"):
            print(
                f"{field:9s} {basic_card[(field, 'success')]:7d} "
                f"{basic_card[(field, 'fallback')]:9d}"
            )
        if any(level_calibration.values()):
            print(
                "level calibration: "
                f"learned={level_calibration['learned']} "
                f"rejected={level_calibration['rejected']}"
            )

    if topk_configs or topk_decisions:
        print()
        print("Student texture top-K")
        if topk_configs:
            print(
                "configs: "
                + ", ".join(
                    f"{method}/k={k}" for method, k in sorted(topk_configs)
                )
            )
        keys = sorted({(method, k) for method, k, _decision in topk_decisions})
        if keys:
            print("method      k   accept  fallback  accept_rate")
            for method, k in keys:
                accept = topk_decisions.get((method, k, "accept"), 0)
                fallback = topk_decisions.get((method, k, "fallback"), 0)
                total = accept + fallback
                rate = accept / total if total else 0.0
                print(f"{method:10s} {k:>3s} {accept:7d} {fallback:9d} {rate:10.1%}")

    if by_student:
        slow = sorted(
            ((sum(values), student) for student, values in by_student.items()),
            reverse=True,
        )[:10]
        print()
        print("Slowest students")
        print("total(s)  student")
        for total, student in slow:
            print(f"{total:8.2f}  {student}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", nargs="?", type=Path, help="scan_*.log path. Defaults to latest APP_DIR/logs scan log.")
    args = parser.parse_args()
    summarize(args.log or _latest_scan_log())


if __name__ == "__main__":
    main()

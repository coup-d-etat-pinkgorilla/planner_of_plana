"""Compare student texture top-K experiment logs."""

from __future__ import annotations

import argparse
import re
import statistics
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.config import APP_DIR


PERF_RE = re.compile(r"\[perf\]\s+(?P<label>\S+)\s+elapsed=(?P<elapsed>[0-9.]+)s")
TOPK_CONFIG_RE = re.compile(
    r"student_texture_topk_config\b.*experiment=(?P<experiment>'[^']*'|\S+)\s+method=(?P<method>\S+)\s+k=(?P<k>\d+)"
)
TOPK_DECISION_RE = re.compile(
    r"texture_topk_(?P<decision>accept|fallback):\s+method=(?P<method>\S+)\s+k=(?P<k>\d+)"
)
TOPK_SHADOW_RE = re.compile(
    r"texture_topk_shadow:.*\bmatched=(?P<matched>true|false)\b"
)


@dataclass
class LogMetrics:
    path: Path
    experiment: str = "unknown"
    method: str = "unknown"
    k: str = "?"
    identify_values: list[float] = field(default_factory=list)
    total_values: list[float] = field(default_factory=list)
    accepts: int = 0
    fallbacks: int = 0
    shadow_matches: int = 0
    shadow_mismatches: int = 0

    @property
    def key(self) -> tuple[str, str, str]:
        return self.experiment, self.method, self.k

    @property
    def identify_avg(self) -> float:
        return statistics.fmean(self.identify_values) if self.identify_values else 0.0

    @property
    def identify_total(self) -> float:
        return sum(self.identify_values)

    @property
    def total_total(self) -> float:
        return sum(self.total_values)

    @property
    def accept_rate(self) -> float:
        total = self.accepts + self.fallbacks
        return self.accepts / total if total else 0.0


def _clean_experiment(raw: str) -> str:
    return raw.strip().strip("'")


def parse_log(path: Path) -> LogMetrics:
    metrics = LogMetrics(path=path)
    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            config = TOPK_CONFIG_RE.search(line)
            if config:
                metrics.experiment = _clean_experiment(config.group("experiment"))
                metrics.method = config.group("method")
                metrics.k = config.group("k")
                continue

            decision = TOPK_DECISION_RE.search(line)
            if decision:
                if decision.group("decision") == "accept":
                    metrics.accepts += 1
                else:
                    metrics.fallbacks += 1
                continue

            shadow = TOPK_SHADOW_RE.search(line)
            if shadow:
                if shadow.group("matched") == "true":
                    metrics.shadow_matches += 1
                else:
                    metrics.shadow_mismatches += 1
                continue

            perf = PERF_RE.search(line)
            if not perf:
                continue
            label = perf.group("label")
            elapsed = float(perf.group("elapsed"))
            if label == "student.identify":
                metrics.identify_values.append(elapsed)
            elif label == "student.total":
                metrics.total_values.append(elapsed)
    return metrics


def _default_logs(limit: int | None) -> list[Path]:
    logs_dir = APP_DIR / "logs"
    paths = sorted(logs_dir.glob("scan_*.log"), key=lambda p: p.stat().st_mtime)
    if limit is not None:
        paths = paths[-limit:]
    return paths


def compare(paths: list[Path], *, min_students: int) -> None:
    parsed = [parse_log(path) for path in paths]
    parsed = [item for item in parsed if len(item.identify_values) >= min_students]
    if not parsed:
        raise SystemExit(f"no comparable scan logs found with min_students={min_students}")

    groups: dict[tuple[str, str, str], list[LogMetrics]] = defaultdict(list)
    for item in parsed:
        groups[item.key].append(item)

    print("Top-K experiment comparison")
    print(f"logs={len(parsed)} min_students={min_students}")
    print()
    print(
        "experiment     method       k runs students ident_avg_med ident_avg_mean "
        "accept_rate shadow_ok shadow_bad total_mean"
    )
    for key, items in sorted(
        groups.items(),
        key=lambda pair: statistics.median(item.identify_avg for item in pair[1]),
    ):
        experiment, method, k = key
        identify_avgs = [item.identify_avg for item in items]
        total_times = [item.total_total for item in items if item.total_values]
        accepts = sum(item.accepts for item in items)
        fallbacks = sum(item.fallbacks for item in items)
        decision_total = accepts + fallbacks
        accept_rate = accepts / decision_total if decision_total else 0.0
        students = sum(len(item.identify_values) for item in items)
        shadow_matches = sum(item.shadow_matches for item in items)
        shadow_mismatches = sum(item.shadow_mismatches for item in items)
        total_mean = statistics.fmean(total_times) if total_times else 0.0
        print(
            f"{experiment:14s} {method:10s} {k:>4s} "
            f"{len(items):4d} {students:8d} "
            f"{statistics.median(identify_avgs):13.3f} "
            f"{statistics.fmean(identify_avgs):14.3f} "
            f"{accept_rate:11.1%} "
            f"{shadow_matches:9d} {shadow_mismatches:10d} "
            f"{total_mean:10.1f}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logs", nargs="*", type=Path, help="scan_*.log files. Defaults to APP_DIR/logs.")
    parser.add_argument("--limit", type=int, default=80, help="latest log count to read when logs are omitted")
    parser.add_argument("--min-students", type=int, default=100, help="ignore partial logs below this identify count")
    args = parser.parse_args()
    compare(args.logs or _default_logs(args.limit), min_students=args.min_students)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

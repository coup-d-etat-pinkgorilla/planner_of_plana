"""Run or print scanner commands for student texture top-K experiments."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class TopKPreset:
    name: str
    method: str
    k: int
    note: str
    shadow: bool = False


PRESETS: tuple[TopKPreset, ...] = (
    TopKPreset("baseline", "fusion", 0, "top-K disabled; exact full comparison"),
    TopKPreset("fusion10", "fusion", 10, "thumb + color + hash, very aggressive"),
    TopKPreset(
        "fusion10_verify",
        "fusion",
        10,
        "fusion10 with authoritative full-pool shadow validation",
        shadow=True,
    ),
    TopKPreset("fusion15", "fusion", 15, "thumb + color + hash, aggressive"),
    TopKPreset("fusion20", "fusion", 20, "thumb + color + hash, aggressive"),
    TopKPreset("fusion25", "fusion", 25, "thumb + color + hash, near default low"),
    TopKPreset("fusion30", "fusion", 30, "thumb + color + hash, default candidate"),
    TopKPreset("fusion40", "fusion", 40, "thumb + color + hash, default high"),
    TopKPreset("fusion50", "fusion", 50, "thumb + color + hash, conservative"),
    TopKPreset("fusion70", "fusion", 70, "thumb + color + hash, very conservative"),
    TopKPreset("fusion100", "fusion", 100, "thumb + color + hash, broad"),
    TopKPreset("hybrid10", "hybrid", 10, "thumb + color, very aggressive"),
    TopKPreset("hybrid15", "hybrid", 15, "thumb + color, aggressive"),
    TopKPreset("hybrid20", "hybrid", 20, "thumb + color, aggressive"),
    TopKPreset("hybrid25", "hybrid", 25, "thumb + color, near default low"),
    TopKPreset("hybrid30", "hybrid", 30, "thumb + color, current-style candidate"),
    TopKPreset("hybrid40", "hybrid", 40, "thumb + color, default high"),
    TopKPreset("hybrid50", "hybrid", 50, "thumb + color, conservative"),
    TopKPreset("hybrid70", "hybrid", 70, "thumb + color, very conservative"),
    TopKPreset("hybrid100", "hybrid", 100, "thumb + color, broad"),
    TopKPreset("thumb20", "thumb", 20, "thumbnail-only aggressive"),
    TopKPreset("thumb30", "thumb", 30, "thumbnail-only sanity check"),
    TopKPreset("thumb50", "thumb", 50, "thumbnail-only conservative"),
    TopKPreset("thumb80", "thumb", 80, "thumbnail-only broad"),
    TopKPreset("hist30", "hist", 30, "color histogram-only focused"),
    TopKPreset("hist50", "hist", 50, "color histogram-only sanity check"),
    TopKPreset("hist80", "hist", 80, "color histogram-only broad"),
    TopKPreset("hist120", "hist", 120, "color histogram-only very broad"),
    TopKPreset("hash50", "hash", 50, "average-hash-only focused"),
    TopKPreset("hash80", "hash", 80, "average-hash-only broad candidate"),
    TopKPreset("hash120", "hash", 120, "average-hash-only broad"),
    TopKPreset("hash160", "hash", 160, "average-hash-only very broad"),
)

RECOMMENDED_ORDER = (
    "baseline",
    "fusion30",
    "hybrid30",
    "fusion20",
    "fusion50",
    "hybrid20",
    "hybrid50",
    "thumb30",
    "hist50",
    "hash80",
)

PRESET_GROUPS: dict[str, tuple[str, ...]] = {
    "quick": (
        "baseline",
        "fusion30",
        "hybrid30",
        "fusion50",
        "hybrid50",
    ),
    "expanded": (
        "baseline",
        "fusion15",
        "fusion20",
        "fusion25",
        "fusion30",
        "fusion40",
        "fusion50",
        "fusion70",
        "hybrid15",
        "hybrid20",
        "hybrid25",
        "hybrid30",
        "hybrid40",
        "hybrid50",
        "hybrid70",
        "thumb30",
        "hist50",
        "hash80",
    ),
    "fine_fusion": (
        "fusion10",
        "fusion15",
        "fusion20",
        "fusion25",
        "fusion30",
        "fusion40",
        "fusion50",
        "fusion70",
        "fusion100",
    ),
    "fine_hybrid": (
        "hybrid10",
        "hybrid15",
        "hybrid20",
        "hybrid25",
        "hybrid30",
        "hybrid40",
        "hybrid50",
        "hybrid70",
        "hybrid100",
    ),
    "single_feature": (
        "thumb20",
        "thumb30",
        "thumb50",
        "thumb80",
        "hist30",
        "hist50",
        "hist80",
        "hist120",
        "hash50",
        "hash80",
        "hash120",
        "hash160",
    ),
    "fusion10_validation8": (
        "fusion10_verify",
        "fusion10_verify",
        "fusion10_verify",
        "fusion10_verify",
        "fusion10_verify",
        "fusion10",
        "fusion10",
        "fusion10",
    ),
    "all": tuple(preset.name for preset in PRESETS),
}


def _preset_map() -> dict[str, TopKPreset]:
    return {preset.name: preset for preset in PRESETS}


def _scanner_command(mode: str, exe: str | None) -> list[str]:
    if exe:
        command = [exe]
    else:
        command = [sys.executable, str(ROOT / "main.py")]
    command.extend(["--scanner", "--use-saved-target", "--suppress-overlay"])
    if mode:
        command.extend(["--auto-scan", mode])
    return command


def _env_for_preset(preset: TopKPreset) -> dict[str, str]:
    env = os.environ.copy()
    env["BA_STUDENT_TOPK_EXPERIMENT"] = preset.name
    env["BA_STUDENT_TOPK_METHOD"] = preset.method
    env["BA_STUDENT_TOPK"] = str(preset.k)
    env["BA_STUDENT_TOPK_SHADOW"] = "1" if preset.shadow else "0"
    return env


def _format_command(command: list[str], preset: TopKPreset) -> str:
    assignments = (
        f"$env:BA_STUDENT_TOPK_EXPERIMENT='{preset.name}'; "
        f"$env:BA_STUDENT_TOPK_METHOD='{preset.method}'; "
        f"$env:BA_STUDENT_TOPK='{preset.k}'; "
        f"$env:BA_STUDENT_TOPK_SHADOW='{'1' if preset.shadow else '0'}'; "
    )
    quoted = " ".join(f'"{part}"' if " " in part else part for part in command)
    return assignments + quoted


def list_presets(group: str | None = None) -> None:
    if group:
        names = PRESET_GROUPS[group]
    else:
        names = tuple(preset.name for preset in PRESETS)
    presets = _preset_map()
    print("Recommended order:")
    print("  " + " -> ".join(RECOMMENDED_ORDER))
    print()
    print("Groups:")
    for group_name, group_presets in PRESET_GROUPS.items():
        print(f"  {group_name:14s} {len(group_presets):2d} presets")
    print()
    print("name              method     k shadow note")
    for name in names:
        preset = presets[name]
        print(
            f"{preset.name:17s} {preset.method:8s} {preset.k:3d} "
            f"{str(preset.shadow):6s} {preset.note}"
        )


def resolve_preset(name: str, *, method: str | None, k: int | None) -> TopKPreset:
    presets = _preset_map()
    if name == "custom":
        if not method or k is None:
            raise SystemExit("custom preset requires --method and --k")
        return TopKPreset("custom", method, k, "custom")
    if name not in presets:
        raise SystemExit(f"unknown preset: {name}")
    preset = presets[name]
    if method is not None or k is not None:
        return TopKPreset(
            name,
            method or preset.method,
            preset.k if k is None else k,
            preset.note,
            preset.shadow,
        )
    return preset


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    list_parser = sub.add_parser("list", help="show experiment presets")
    list_parser.add_argument("--group", choices=tuple(PRESET_GROUPS), help="show one preset group")

    commands_parser = sub.add_parser("commands", help="print scanner commands for a preset group")
    commands_parser.add_argument("--group", default="expanded", choices=tuple(PRESET_GROUPS))
    commands_parser.add_argument("--mode", default="students", choices=("students", "all", "student_current"))
    commands_parser.add_argument("--exe", help="optional BA Planner exe path for packaged builds")

    for command_name in ("command", "run"):
        p = sub.add_parser(command_name, help=f"{command_name} one scanner experiment")
        p.add_argument("preset", choices=tuple(_preset_map()) + ("custom",))
        p.add_argument("--mode", default="students", choices=("students", "all", "student_current"))
        p.add_argument("--exe", help="optional BA Planner exe path for packaged builds")
        p.add_argument("--method", choices=("fusion", "hybrid", "thumb", "hist", "hash"))
        p.add_argument("--k", type=int, help="override top-K; 0 disables top-K")

    args = parser.parse_args()

    if args.command == "list":
        list_presets(args.group)
        return 0

    if args.command == "commands":
        presets = _preset_map()
        command = _scanner_command(args.mode, args.exe)
        for index, name in enumerate(PRESET_GROUPS[args.group], start=1):
            preset = presets[name]
            print(f"# {index:02d} {preset.name}: {preset.note}")
            print(_format_command(command, preset))
        return 0

    preset = resolve_preset(args.preset, method=args.method, k=args.k)
    command = _scanner_command(args.mode, args.exe)
    if args.command == "command":
        print(_format_command(command, preset))
        return 0

    env = _env_for_preset(preset)
    print(
        f"running preset={preset.name} method={preset.method} k={preset.k} "
        f"shadow={preset.shadow} mode={args.mode}"
    )
    print(_format_command(command, preset))
    return subprocess.run(command, cwd=str(ROOT), env=env, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())

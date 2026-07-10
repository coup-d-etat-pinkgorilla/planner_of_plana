from __future__ import annotations

import argparse
import contextlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.capture import find_target_hwnd, get_all_windows, get_window_rect, set_target_window
from core.config import BASE_DIR, load_config, load_regions
from core.inventory_profiles import get_inventory_profile, normalize_inventory_profile_ids
from core.scanner import (
    EQUIPMENT_INVENTORY_DRAG,
    ITEM_INVENTORY_DRAG,
    Scanner,
)
from tools.replay_inventory_scroll_debug import (
    export_gray_band_layout_studio_projects,
    export_studio_projects,
    replay_scroll_folder,
)


DEFAULT_OUTPUT_DIR = BASE_DIR / "debug" / "item_equip_scroll_debugger"
ITEM_PROFILE_IDS = (
    "activity_reports",
    "tech_notes",
    "tactical_bd",
    "ooparts",
    "presents",
    "student_elephs",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Capture item/equipment inventory scroll behavior without reading grid "
            "items, then export Template Alignment Studio projects."
        )
    )
    parser.add_argument(
        "--target",
        choices=("item", "equipment", "both"),
        default="both",
        help="inventory area to capture",
    )
    parser.add_argument(
        "--item-profile",
        action="append",
        default=None,
        help=(
            "item scan profile/filter to capture separately; repeatable. "
            "Use all for the unfiltered item scan."
        ),
    )
    parser.add_argument(
        "--all-item-profiles",
        action="store_true",
        help="capture every supported filtered item profile into separate folders",
    )
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument(
        "--current-screen",
        action="store_true",
        help="do not navigate from the menu; use the currently open inventory screen",
    )
    parser.add_argument(
        "--stay",
        action="store_true",
        help="leave the game on the last captured inventory screen instead of returning to lobby",
    )
    parser.add_argument(
        "--no-studio-export",
        action="store_true",
        help="skip Template Alignment Studio JSON export",
    )
    parser.add_argument(
        "--no-gray-band-layout-export",
        action="store_true",
        help="skip gray-band-layout Template Alignment Studio export",
    )
    parser.add_argument(
        "--focus-anchor-before-scroll",
        action="store_true",
        help=(
            "before each scroll capture, click inventory slot 1, move the OS cursor "
            "away from the grid, then capture after a short settle wait"
        ),
    )
    parser.add_argument("--hwnd", type=int, default=None)
    parser.add_argument("--title-contains", default="Blue Archive")
    return parser.parse_args()


def _safe_token(value: object) -> str:
    text = str(value or "").strip()
    cleaned = "".join(ch if ch.isalnum() or ch in "_.-" else "_" for ch in text)
    return cleaned.strip("_") or "none"


def _load_saved_target() -> tuple[int | None, str]:
    config = load_config()
    try:
        hwnd = int(config.get("target_hwnd") or 0)
    except (TypeError, ValueError):
        hwnd = 0
    title = str(config.get("target_title") or "")
    if hwnd:
        set_target_window(hwnd, title)
        return hwnd, title
    return None, ""


def _select_target(args: argparse.Namespace) -> tuple[int | None, str]:
    if args.hwnd:
        set_target_window(args.hwnd, f"manual:{args.hwnd}")
        return args.hwnd, f"manual:{args.hwnd}"
    saved_hwnd, saved_title = _load_saved_target()
    if find_target_hwnd() is not None:
        return saved_hwnd, saved_title
    needle = (args.title_contains or "").strip().lower()
    if needle:
        for window in get_all_windows():
            title = str(window.get("title") or "")
            if needle in title.lower():
                hwnd = int(window["hwnd"])
                set_target_window(hwnd, title)
                return hwnd, title
    return saved_hwnd, saved_title


def _resolve_output_dir(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def _replace_dir(path: Path, root: Path) -> None:
    resolved = path.resolve()
    resolved_root = root.resolve()
    if resolved != resolved_root and resolved_root not in resolved.parents:
        raise ValueError(f"refusing to replace directory outside output root: {resolved}")
    if resolved.exists():
        shutil.rmtree(resolved)
    resolved.mkdir(parents=True, exist_ok=True)


def _item_profiles(args: argparse.Namespace) -> tuple[str | None, ...]:
    if args.all_item_profiles:
        return ITEM_PROFILE_IDS
    raw = args.item_profile
    if not raw:
        return (None,)
    normalized = normalize_inventory_profile_ids(raw)
    if not normalized or normalized == ("all",):
        return (None,)
    item_profiles: list[str] = []
    for profile_id in normalized:
        profile = get_inventory_profile(profile_id)
        if profile is not None and profile.source == "item":
            item_profiles.append(profile_id)
    return tuple(item_profiles) or (None,)


def _export_studio(capture_dir: Path, section: str, target_dir: Path) -> list[str]:
    rows = replay_scroll_folder(capture_dir, section)
    written = export_studio_projects(capture_dir, section, rows, target_dir)
    return [str(path) for path in written]


def _export_gray_band_layout_studio(capture_dir: Path, section: str, target_dir: Path) -> list[str]:
    rows = replay_scroll_folder(capture_dir, section)
    written = export_gray_band_layout_studio_projects(capture_dir, section, rows, target_dir)
    return [str(path) for path in written]


def _write_target_index(target_dir: Path, payload: dict) -> None:
    target_dir.mkdir(parents=True, exist_ok=True)
    (target_dir / "index.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def _capture_item_profile(
    scanner: Scanner,
    output_root: Path,
    profile_id: str | None,
    *,
    export_studio: bool,
    export_gray_band_layout: bool,
    ensure_sort_rule: bool,
    focus_anchor_before_scroll: bool,
) -> dict:
    label = _safe_token(profile_id or "all")
    target_dir = output_root / "item" / label
    _replace_dir(target_dir, output_root)
    capture_dir = target_dir / "captures"
    studio_dir = target_dir / "studio_projects"
    gray_band_studio_dir = target_dir / "gray_band_layout_studio_projects"

    scanner._forced_inventory_profile_id = profile_id
    if not scanner._prepare_item_inventory(profile_id, ensure_sort_rule=ensure_sort_rule):
        payload = {
            "ok": False,
            "target": "item",
            "profile_id": profile_id,
            "reason": "prepare_failed",
            "target_dir": str(target_dir),
        }
        _write_target_index(target_dir, payload)
        return payload

    summary = scanner.capture_inventory_scroll_debug(
        "item",
        "item",
        ITEM_INVENTORY_DRAG,
        ITEM_INVENTORY_DRAG.delta_px,
        capture_dir,
        focus_anchor_before_scroll=focus_anchor_before_scroll,
    )
    studio_files = [] if not export_studio else _export_studio(capture_dir, "item", studio_dir)
    gray_band_studio_files = (
        []
        if not export_gray_band_layout
        else _export_gray_band_layout_studio(capture_dir, "item", gray_band_studio_dir)
    )
    payload = {
        "ok": bool(summary.get("ok")),
        "target": "item",
        "profile_id": profile_id,
        "target_dir": str(target_dir),
        "captures_dir": str(capture_dir),
        "studio_dir": str(studio_dir) if export_studio else None,
        "studio_files": studio_files,
        "gray_band_layout_studio_dir": str(gray_band_studio_dir) if export_gray_band_layout else None,
        "gray_band_layout_studio_files": gray_band_studio_files,
        "capture_summary": summary,
    }
    _write_target_index(target_dir, payload)
    return payload


def _capture_equipment(
    scanner: Scanner,
    output_root: Path,
    *,
    export_studio: bool,
    export_gray_band_layout: bool,
    focus_anchor_before_scroll: bool,
) -> dict:
    target_dir = output_root / "equipment"
    _replace_dir(target_dir, output_root)
    capture_dir = target_dir / "captures"
    studio_dir = target_dir / "studio_projects"
    gray_band_studio_dir = target_dir / "gray_band_layout_studio_projects"

    scanner._forced_inventory_profile_id = "equipment"
    if not scanner._prepare_equipment_inventory():
        payload = {
            "ok": False,
            "target": "equipment",
            "profile_id": "equipment",
            "reason": "prepare_failed",
            "target_dir": str(target_dir),
        }
        _write_target_index(target_dir, payload)
        return payload

    summary = scanner.capture_inventory_scroll_debug(
        "equipment",
        "equipment",
        EQUIPMENT_INVENTORY_DRAG,
        EQUIPMENT_INVENTORY_DRAG.delta_px,
        capture_dir,
        focus_anchor_before_scroll=focus_anchor_before_scroll,
    )
    studio_files = [] if not export_studio else _export_studio(capture_dir, "equipment", studio_dir)
    gray_band_studio_files = (
        []
        if not export_gray_band_layout
        else _export_gray_band_layout_studio(capture_dir, "equipment", gray_band_studio_dir)
    )
    payload = {
        "ok": bool(summary.get("ok")),
        "target": "equipment",
        "profile_id": "equipment",
        "target_dir": str(target_dir),
        "captures_dir": str(capture_dir),
        "studio_dir": str(studio_dir) if export_studio else None,
        "studio_files": studio_files,
        "gray_band_layout_studio_dir": str(gray_band_studio_dir) if export_gray_band_layout else None,
        "gray_band_layout_studio_files": gray_band_studio_files,
        "capture_summary": summary,
    }
    _write_target_index(target_dir, payload)
    return payload


def main() -> int:
    args = parse_args()
    saved_hwnd, saved_title = _select_target(args)
    hwnd = find_target_hwnd()
    rect = get_window_rect()
    if hwnd is None or rect is None:
        if saved_hwnd:
            print(f"saved target unavailable: {saved_title or '-'} hwnd={saved_hwnd}", file=sys.stderr)
        else:
            print("no saved target. Open main.py and select the game window first.", file=sys.stderr)
        return 2

    item_profiles = _item_profiles(args)
    if args.current_screen and args.target == "both":
        print("--current-screen requires --target item or --target equipment", file=sys.stderr)
        return 2
    if args.current_screen and args.target == "item" and len(item_profiles) > 1:
        print("--current-screen can capture only one item profile at a time", file=sys.stderr)
        return 2

    output_root = _resolve_output_dir(args.output_dir)
    output_root.mkdir(parents=True, exist_ok=True)
    scanner = Scanner(load_regions(), on_progress=print)
    previous_profile = scanner._forced_inventory_profile_id
    results: list[dict] = []
    in_menu = False

    print(f"target={saved_title or '-'} hwnd={hwnd}")
    print(f"output={output_root}")
    try:
        if not args.current_screen:
            if not scanner._open_menu():
                print("failed to open menu", file=sys.stderr)
                return 1
            in_menu = True

        if args.target in {"item", "both"}:
            for index, profile_id in enumerate(item_profiles):
                if not args.current_screen:
                    if not in_menu:
                        if not scanner._exit_inventory_to_menu():
                            print("failed to return to menu before next item profile", file=sys.stderr)
                            return 1
                        in_menu = True
                    if not scanner._go_to("item_entry_button", "items"):
                        print("failed to open item inventory", file=sys.stderr)
                        return 1
                    if not scanner._wait(0.5):
                        return 1
                    in_menu = False

                print(f"capture item profile={profile_id or 'all'}")
                results.append(
                    _capture_item_profile(
                        scanner,
                        output_root,
                        profile_id,
                        export_studio=not args.no_studio_export,
                        export_gray_band_layout=(not args.no_studio_export and not args.no_gray_band_layout_export),
                        ensure_sort_rule=True,
                        focus_anchor_before_scroll=args.focus_anchor_before_scroll,
                    )
                )

                more_items = index + 1 < len(item_profiles)
                equipment_after = args.target == "both"
                if not args.current_screen and (more_items or equipment_after):
                    if not scanner._exit_inventory_to_menu():
                        print("failed to return to menu after item capture", file=sys.stderr)
                        return 1
                    in_menu = True

        if args.target in {"equipment", "both"}:
            if not args.current_screen:
                if not in_menu:
                    if not scanner._exit_inventory_to_menu():
                        print("failed to return to menu before equipment capture", file=sys.stderr)
                        return 1
                    in_menu = True
                if not scanner._go_to("equipment_entry_button", "equipment"):
                    print("failed to open equipment inventory", file=sys.stderr)
                    return 1
                if not scanner._wait(0.5):
                    return 1
                in_menu = False

            print("capture equipment")
            results.append(
                _capture_equipment(
                    scanner,
                    output_root,
                    export_studio=not args.no_studio_export,
                    export_gray_band_layout=(not args.no_studio_export and not args.no_gray_band_layout_export),
                    focus_anchor_before_scroll=args.focus_anchor_before_scroll,
                )
            )

    finally:
        scanner._forced_inventory_profile_id = previous_profile
        if not args.current_screen and not args.stay:
            with contextlib.suppress(Exception):
                scanner._return_inventory_to_lobby()

    run_index = {
        "target": args.target,
        "item_profiles": [profile or "all" for profile in item_profiles],
        "output_root": str(output_root),
        "focus_anchor_before_scroll": bool(args.focus_anchor_before_scroll),
        "gray_band_layout_export": bool(not args.no_studio_export and not args.no_gray_band_layout_export),
        "results": results,
    }
    (output_root / "index.json").write_text(
        json.dumps(run_index, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"wrote index={output_root / 'index.json'}")
    return 0 if results and all(row.get("ok") for row in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())

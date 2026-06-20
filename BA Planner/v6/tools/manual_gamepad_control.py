from __future__ import annotations

import argparse
import msvcrt
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.gamepad_input import GamepadButton, GamepadUnavailable, VirtualXboxController


ARROW_KEYS = {
    b"H": GamepadButton.DPAD_UP,
    b"P": GamepadButton.DPAD_DOWN,
    b"K": GamepadButton.DPAD_LEFT,
    b"M": GamepadButton.DPAD_RIGHT,
}

CHAR_KEYS = {
    "w": GamepadButton.DPAD_UP,
    "s": GamepadButton.DPAD_DOWN,
    "a": GamepadButton.DPAD_LEFT,
    "d": GamepadButton.DPAD_RIGHT,
    " ": GamepadButton.A,
    "\r": GamepadButton.A,
    "j": GamepadButton.A,
    "k": GamepadButton.B,
    "u": GamepadButton.LEFT_THUMB,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Keep a virtual Xbox controller alive and map keyboard keys to inputs."
    )
    parser.add_argument("--hold", type=float, default=0.14, help="button hold seconds")
    parser.add_argument("--settle", type=float, default=0.08, help="delay after each input")
    parser.add_argument(
        "--ready-delay",
        type=float,
        default=2.0,
        help="seconds to keep the controller alive before accepting input",
    )
    return parser.parse_args()


def read_key() -> GamepadButton | str | None:
    raw = msvcrt.getch()
    if raw in (b"\x00", b"\xe0"):
        return ARROW_KEYS.get(msvcrt.getch())
    if raw in (b"\x03", b"\x1b"):
        return "quit"
    try:
        char = raw.decode("utf-8").lower()
    except UnicodeDecodeError:
        return None
    if char == "q":
        return "quit"
    return CHAR_KEYS.get(char)


def main() -> int:
    args = parse_args()
    try:
        with VirtualXboxController() as controller:
            controller.release_all_buttons()
            print("Virtual Xbox controller is connected.")
            print(f"Waiting {args.ready_delay:.1f}s so the game can detect it...")
            time.sleep(max(0.0, args.ready_delay))
            print("Controls: arrows/WASD=dpad, Space/Enter/J=A, K=B, U=L3, Q/Esc=quit")
            while True:
                key = read_key()
                if key == "quit":
                    break
                if key is None:
                    continue
                print(f"pulse {key.value}")
                controller.pulse_button(
                    key,
                    duration=max(0.0, args.hold),
                    settle=max(0.0, args.settle),
                )
    except GamepadUnavailable as exc:
        print(str(exc), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

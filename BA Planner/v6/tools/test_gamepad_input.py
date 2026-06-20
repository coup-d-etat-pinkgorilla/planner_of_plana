from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.gamepad_input import GamepadButton, GamepadUnavailable, VirtualXboxController


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Pulse virtual Xbox controller inputs.")
    subparsers = parser.add_subparsers(dest="command")

    stick = subparsers.add_parser("stick", help="pulse the left stick")
    stick.add_argument("--x", type=float, default=0.0, help="left stick X, -1.0 to 1.0")
    stick.add_argument("--y", type=float, default=-1.0, help="left stick Y, -1.0 to 1.0")
    stick.add_argument("--duration", type=float, default=0.35, help="seconds to hold")
    stick.add_argument("--settle", type=float, default=0.10, help="seconds to wait after centering")
    stick.add_argument("--repeat", type=int, default=1, help="number of pulses")
    stick.add_argument("--gap", type=float, default=0.25, help="seconds between pulses")

    button = subparsers.add_parser("button", help="pulse a gamepad button")
    button.add_argument(
        "button",
        choices=[item.value for item in GamepadButton],
        help="button to pulse",
    )
    button.add_argument("--duration", type=float, default=0.08, help="seconds to hold")
    button.add_argument("--settle", type=float, default=0.12, help="seconds to wait after release")
    button.add_argument("--repeat", type=int, default=1, help="number of pulses")
    button.add_argument("--gap", type=float, default=0.20, help="seconds between pulses")

    parser.set_defaults(command="button", button=GamepadButton.DPAD_DOWN.value)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        with VirtualXboxController() as controller:
            repeat = max(1, int(args.repeat))
            for idx in range(repeat):
                if args.command == "stick":
                    print(
                        f"stick {idx + 1}/{repeat}: "
                        f"x={args.x:.3f} y={args.y:.3f} duration={args.duration:.2f}s"
                    )
                    controller.pulse_left_stick(
                        args.x,
                        args.y,
                        duration=args.duration,
                        settle=args.settle,
                    )
                else:
                    print(
                        f"button {idx + 1}/{repeat}: "
                        f"{args.button} duration={args.duration:.2f}s"
                    )
                    controller.pulse_button(
                        args.button,
                        duration=args.duration,
                        settle=args.settle,
                    )
                if idx + 1 < repeat:
                    time.sleep(max(0.0, args.gap))
    except GamepadUnavailable as exc:
        print(str(exc), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


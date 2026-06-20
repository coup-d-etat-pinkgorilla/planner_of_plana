from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.test_gamepad_input import main as gamepad_main


if __name__ == "__main__":
    sys.argv.insert(1, "stick")
    raise SystemExit(gamepad_main())


from __future__ import annotations

import sys

from core.stdio_server import serve


def main() -> None:
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    serve()


if __name__ == "__main__":
    main()

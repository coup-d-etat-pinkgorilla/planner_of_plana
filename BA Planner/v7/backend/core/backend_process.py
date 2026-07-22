from __future__ import annotations

import sys
from core.application_protocol_v1 import ApplicationProtocolV1
from core.runtime_paths import resolve_repository_root
from core.stdio_server import serve


def main() -> None:
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    serve(protocol=ApplicationProtocolV1(storage_root=resolve_repository_root()))


if __name__ == "__main__":
    main()

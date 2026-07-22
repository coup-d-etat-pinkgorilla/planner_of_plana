from __future__ import annotations

import sys
from core.application_protocol_v1 import ApplicationProtocolV1
from core.runtime_paths import resolve_repository_root
from core.scanner_runtime import build_scanner_service
from core.stdio_server import serve


def main() -> None:
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    storage_root = resolve_repository_root()
    serve(protocol=ApplicationProtocolV1(
        storage_root=storage_root,
        scanner_service=build_scanner_service(storage_root),
    ))


if __name__ == "__main__":
    main()

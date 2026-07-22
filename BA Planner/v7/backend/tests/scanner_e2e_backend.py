from __future__ import annotations

import sys
from pathlib import Path

from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository
from core.runtime_paths import resolve_repository_root
from core.scanner_session import ScannerSessionService
from core.stdio_server import serve


def _student_matcher(_target, _cancel, progress):
    progress(1, 1, "scanner_e2e_fixture")
    return [{
        "candidate_id": "scanner-e2e-candidate",
        "payload": {
            "version": 1,
            "student_id": "airi",
            "values": {"level": 90},
            "provenance": {"level": "scanner-e2e-fixture"},
        },
        "evidence": [{
            "field": "level",
            "status": "ok",
            "source": "scanner-e2e-fixture",
            "confidence": 1.0,
        }],
    }]


def main() -> None:
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    storage_root = resolve_repository_root()
    repository = JsonRepository(storage_root)
    service = ScannerSessionService(
        target_provider=lambda: [{
            "target_id": "scanner-e2e-target",
            "title": "Scanner E2E Fixture",
            "status": "ready",
            "foreground": False,
        }],
        student_matcher=_student_matcher,
        inventory_matcher=lambda *_args: [],
        repository=repository,
        asset_status=lambda: {
            "ready": True,
            "manifest_version": 1,
            "asset_count": 16,
            "missing": [],
            "corrupt": [],
        },
    )
    serve(protocol=ApplicationProtocolV1(
        storage_root=Path(storage_root),
        scanner_service=service,
    ))


if __name__ == "__main__":
    main()

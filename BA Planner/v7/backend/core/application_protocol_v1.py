from __future__ import annotations

from pathlib import Path
from typing import Any

from core.protocol_v1 import PlanningProtocolV1
from core.repository_protocol_v1 import METHODS, RepositoryProtocolV1
from core.repository_store import JsonRepository
from core.scanner_protocol_v1 import METHODS as SCANNER_METHODS, ScannerProtocolV1
from core.scanner_session import EventSink, ScannerSessionService


class ApplicationProtocolV1:
    def __init__(
        self, *, storage_root: Path, planning: PlanningProtocolV1 | None = None,
        scanner_service: ScannerSessionService | None = None,
    ) -> None:
        self.planning = planning or PlanningProtocolV1()
        self.repository = RepositoryProtocolV1(JsonRepository(storage_root))
        self.scanner_service = scanner_service
        self.scanner = ScannerProtocolV1(scanner_service) if scanner_service is not None else None

    def bind_event_sink(self, event_sink: EventSink) -> None:
        if self.scanner_service is not None:
            self.scanner_service.set_event_sink(event_sink)

    def close(self) -> None:
        if self.scanner_service is not None:
            self.scanner_service.close()

    def handle(self, message: object) -> dict[str, Any] | None:
        if isinstance(message, dict) and message.get("method") in SCANNER_METHODS:
            trusted = PlanningProtocolV1._trusted_request(message)
            if trusted is None:
                return None
            if self.scanner is None:
                return ScannerProtocolV1._error(
                    trusted["id"], trusted["method"], "scanner_unavailable",
                    "scanner runtime is not available",
                )
            return self.scanner.handle(trusted)
        if isinstance(message, dict) and message.get("method") in METHODS:
            trusted = PlanningProtocolV1._trusted_request(message)
            return None if trusted is None else self.repository.handle(trusted)
        return self.planning.handle(message)

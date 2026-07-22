from __future__ import annotations

from pathlib import Path
from typing import Any

from core.protocol_v1 import PlanningProtocolV1
from core.repository_protocol_v1 import METHODS, RepositoryProtocolV1
from core.repository_store import JsonRepository


class ApplicationProtocolV1:
    def __init__(self, *, storage_root: Path, planning: PlanningProtocolV1 | None = None) -> None:
        self.planning = planning or PlanningProtocolV1()
        self.repository = RepositoryProtocolV1(JsonRepository(storage_root))

    def handle(self, message: object) -> dict[str, Any] | None:
        if isinstance(message, dict) and message.get("method") in METHODS:
            trusted = PlanningProtocolV1._trusted_request(message)
            return None if trusted is None else self.repository.handle(trusted)
        return self.planning.handle(message)

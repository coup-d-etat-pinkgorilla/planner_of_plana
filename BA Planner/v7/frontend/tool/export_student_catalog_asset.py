"""Export the runtime student catalog, including KR availability and forms, for mock."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"
OUTPUT = ROOT / "frontend" / "assets" / "student_catalog.json"
sys.path.insert(0, str(BACKEND))

from core.protocol_v1 import PlanningProtocolV1  # noqa: E402


def main() -> None:
    response = PlanningProtocolV1().handle(
        {
            "protocol": 1,
            "id": "export-student-catalog",
            "type": "request",
            "method": "planning.student.catalog",
            "payload": {},
        }
    )
    if response is None or "error" in response["payload"]:
        raise RuntimeError(f"Student catalog export failed: {response}")
    students = response["payload"]["students"]
    OUTPUT.write_text(
        json.dumps(students, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"exported {len(students)} students to {OUTPUT}")


if __name__ == "__main__":
    main()

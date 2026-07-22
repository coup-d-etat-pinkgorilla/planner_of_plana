from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

from core.protocol_v1 import PlanningProtocolV1


class StudentCatalogTests(unittest.TestCase):
    def test_catalog_is_stable_minimal_and_has_fallbacks(self) -> None:
        source = {
            "z": {"display_name": "긴 이름" * 20, "search_tags": ["tag"]},
            "missing": {},
            "a": {"display_name": "가나다", "school": "Abydos"},
        }
        handler = PlanningProtocolV1(student_ids=lambda: ["z", "missing", "a"], student_lookup=source.get)
        response = handler.handle({"protocol":1,"id":"catalog","type":"request","method":"planning.student.catalog","payload":{}})
        self.assertEqual(["missing", "a", "z"], [item["student_id"] for item in response["payload"]["students"]])
        fallback = response["payload"]["students"][0]
        self.assertEqual("missing", fallback["display_name"])
        self.assertEqual("missing.png", fallback["template_name"])
        self.assertNotIn("raw_skill_material", fallback)

    def test_catalog_rejects_payload_and_real_process_serves_list(self) -> None:
        handler = PlanningProtocolV1()
        invalid = handler.handle({"protocol":1,"id":"bad","type":"request","method":"planning.student.catalog","payload":{"page":1}})
        self.assertEqual("invalid_payload", invalid["payload"]["error"]["code"])
        request = json.dumps({"protocol":1,"id":"real","type":"request","method":"planning.student.catalog","payload":{}})
        process = subprocess.run([sys.executable, "-m", "core.backend_process"], input=request + "\n", text=True, capture_output=True, cwd=Path(__file__).parents[1], timeout=15)
        self.assertEqual(0, process.returncode, process.stderr)
        response = json.loads(process.stdout.splitlines()[0])
        self.assertGreater(len(response["payload"]["students"]), 100)
        self.assertEqual("display_name_then_id", response["payload"]["sort"])


if __name__ == "__main__":
    unittest.main()

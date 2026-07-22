from __future__ import annotations

import io
import json
import subprocess
import sys
import unittest
from dataclasses import asdict
from pathlib import Path

from core.planning_calc import PlanCostSummary
from core.protocol_v1 import PlanningProtocolV1
from core.stdio_server import serve


def request(
    request_id: str, method: str, payload: dict[str, object], *, protocol: int = 1
) -> dict[str, object]:
    return {
        "protocol": protocol,
        "id": request_id,
        "type": "request",
        "method": method,
        "payload": payload,
    }


class PlanningProtocolV1Tests(unittest.TestCase):
    def test_student_lookup_and_consecutive_requests_preserve_ids(self) -> None:
        handler = PlanningProtocolV1(
            student_lookup=lambda student_id: {
                "student_id": "stale-metadata-key",
                "display_name": student_id.title(),
                "template_name": f"{student_id}.png",
                "group": student_id,
                "variant": None,
            }
        )
        first = handler.handle(
            request("one", "planning.student.get", {"student_id": "ayane"})
        )
        second = handler.handle(
            request("two", "planning.student.get", {"student_id": "nonexistent"})
        )
        self.assertEqual(first["id"], "one")
        self.assertEqual(first["payload"]["student"]["student_id"], "ayane")
        self.assertEqual(second["id"], "two")

    def test_unknown_method_and_invalid_payload_are_structured(self) -> None:
        handler = PlanningProtocolV1()
        unknown = handler.handle(request("u", "future.method", {}))
        invalid = handler.handle(
            request("i", "planning.student.get", {"student_id": "", "extra": 1})
        )
        self.assertEqual(unknown["payload"]["error"]["code"], "unknown_method")
        self.assertEqual(invalid["payload"]["error"]["code"], "invalid_payload")
        self.assertEqual(unknown["method"], "future.method")

    def test_version_mismatch_and_untrusted_envelope_have_no_response(self) -> None:
        handler = PlanningProtocolV1()
        self.assertIsNone(
            handler.handle(request("old", "planning.student.get", {}, protocol=2))
        )
        self.assertIsNone(handler.handle({"protocol": 1, "id": "partial"}))

    def test_plan_validation_is_canonical(self) -> None:
        response = PlanningProtocolV1().handle(
            request(
                "plan",
                "planning.plan.validate",
                {
                    "plan": {
                        "version": 1,
                        "future": True,
                        "goals": [
                            {
                                "student_id": "ayane",
                                "target_level": 10,
                                "future_target": 20,
                            }
                        ],
                    }
                },
            )
        )
        plan = response["payload"]["plan"]
        self.assertNotIn("future", plan)
        self.assertNotIn("future_target", plan["goals"][0])

    def test_calculation_and_internal_failure(self) -> None:
        diagnostics: list[str] = []
        success = PlanningProtocolV1(
            calculator=lambda _records, _plan: PlanCostSummary(credits=7)
        ).handle(
            request(
                "calc",
                "planning.plan.calculate",
                {
                    "current_students": [{"student_id": "ayane", "level": 1}],
                    "plan": {"version": 1, "goals": []},
                },
            )
        )
        failure = PlanningProtocolV1(
            calculator=lambda _records, _plan: (_ for _ in ()).throw(RuntimeError("boom")),
            diagnostic=diagnostics.append,
        ).handle(
            request(
                "fail",
                "planning.plan.calculate",
                {"current_students": [], "plan": {"version": 1, "goals": []}},
            )
        )
        self.assertEqual(success["payload"]["totals"], asdict(PlanCostSummary(credits=7)))
        self.assertEqual(failure["payload"]["error"]["code"], "calculation_failed")
        self.assertIn("RuntimeError: boom", diagnostics[0])

    def test_inventory_catalog_and_shortages_are_typed_and_correlated(self) -> None:
        handler = PlanningProtocolV1(
            inventory_catalog=lambda: [{
                "resource_key": "item", "item_id": "item", "display_name": "Item",
                "category": "material", "profile_id": "materials", "order_index": 0,
                "zero_fill_allowed": True,
            }],
            shortage_deriver=lambda _records, _plan, _entries: {"rows": [], "warnings": []},
        )
        catalog = handler.handle(request("catalog", "planning.inventory.catalog", {}))
        shortage = handler.handle(request("shortage", "planning.plan.shortages", {
            "current_students": [], "plan": {"version": 1, "goals": []},
            "inventory": {"version": 1, "entries": [{"key": "item", "quantity": "0"}]},
        }))
        self.assertEqual(catalog["id"], "catalog")
        self.assertEqual(catalog["payload"]["sort"], "profile_order")
        self.assertEqual(shortage["id"], "shortage")
        self.assertEqual(shortage["payload"], {"rows": [], "warnings": []})

    def test_inventory_payload_and_internal_failures_are_structured(self) -> None:
        invalid = PlanningProtocolV1().handle(request(
            "bad", "planning.plan.shortages",
            {"current_students": [], "plan": {"version": 1, "goals": []},
             "inventory": {"version": 1, "entries": [{"key": "x", "quantity": "-1"}]}},
        ))
        diagnostics: list[str] = []
        failed = PlanningProtocolV1(
            inventory_catalog=lambda: (_ for _ in ()).throw(RuntimeError("catalog boom")),
            diagnostic=diagnostics.append,
        ).handle(request("failed", "planning.inventory.catalog", {}))
        self.assertEqual(invalid["payload"]["error"]["code"], "invalid_payload")
        self.assertEqual(failed["payload"]["error"]["code"], "inventory_catalog_failed")
        self.assertIn("catalog boom", diagnostics[0])


class StdioServerTests(unittest.TestCase):
    def test_malformed_json_is_diagnostic_and_next_line_is_processed(self) -> None:
        valid = request("ok", "planning.student.get", {"student_id": "missing"})
        stdin = io.StringIO("{bad json\n" + json.dumps(valid) + "\n")
        stdout = io.StringIO()
        stderr = io.StringIO()
        serve(stdin, stdout, stderr, protocol=PlanningProtocolV1(student_lookup=lambda _id: None))
        messages = [json.loads(line) for line in stdout.getvalue().splitlines()]
        self.assertEqual(len(messages), 1)
        self.assertEqual(messages[0]["id"], "ok")
        self.assertIn("malformed JSON", stderr.getvalue())

    def test_eof_exits_without_protocol_noise(self) -> None:
        stdout = io.StringIO()
        serve(io.StringIO(""), stdout, io.StringIO())
        self.assertEqual(stdout.getvalue(), "")

    def test_real_module_process_round_trip(self) -> None:
        backend = Path(__file__).parents[1]
        process = subprocess.Popen(
            [sys.executable, "-m", "core.backend_process"],
            cwd=backend,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
        )
        message = request("subprocess", "planning.student.get", {"student_id": "ayane"})
        stdout, stderr = process.communicate(json.dumps(message) + "\n", timeout=10)
        self.assertEqual(process.returncode, 0, stderr)
        response = json.loads(stdout)
        self.assertEqual(response["id"], "subprocess")
        self.assertEqual(response["payload"]["student"]["student_id"], "ayane")


if __name__ == "__main__":
    unittest.main()

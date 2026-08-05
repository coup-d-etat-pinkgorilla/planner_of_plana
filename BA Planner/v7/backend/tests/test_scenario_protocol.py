from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from core.application_protocol_v1 import ApplicationProtocolV1

from tests.test_scenario_store import document


class ScenarioProtocolTests(unittest.TestCase):
    def test_application_protocol_dispatches_scenario_crud(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            application = ApplicationProtocolV1(storage_root=Path(temporary))

            def request(identifier: str, method: str, payload: dict) -> dict:
                return {"protocol": 1, "id": identifier, "type": "request", "method": method, "payload": payload}

            created_profile = application.handle(request(
                "profile", "repository.profile.create",
                {"display_name": "Main", "idempotency_key": "profile"},
            ))
            profile_id = created_profile["payload"]["profile"]["profile_id"]
            created = application.handle(request(
                "create", "repository.scenario.create",
                {
                    "profile_id": profile_id,
                    "expected_revision": 0,
                    "idempotency_key": "scenario-create",
                    "name": "후보",
                    "description": "",
                    "base_profile_revision": 0,
                    "document": document("후보"),
                },
            ))
            self.assertEqual(created["payload"]["revision"], 1)
            scenario_id = created["payload"]["scenario_id"]
            listed = application.handle(request(
                "list", "repository.scenario.list", {"profile_id": profile_id},
            ))
            self.assertEqual(listed["payload"]["scenarios"][0]["scenario_id"], scenario_id)
            loaded = application.handle(request(
                "get", "repository.scenario.get",
                {"profile_id": profile_id, "scenario_id": scenario_id},
            ))
            self.assertEqual(loaded["payload"]["scenario"]["document"]["kind"], "scenario")


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import json
import itertools
from pathlib import Path
import tempfile
import unittest

from core.repository_protocol_v1 import RepositoryProtocolV1
from core.repository_store import JsonRepository


PROFILE_KEY = "profile_deadbeef"


def _write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")


class V6MigrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        root = Path(self.temporary.name)
        self.v6_root = root / "v6"
        ids = itertools.count(1)
        self.repository = JsonRepository(root / "repository", id_factory=lambda: f"{next(ids):032x}")
        self.repository.create_profile("Main", "main")
        self.repository.create_profile("Main (v6 가져오기)", "existing-suffix")
        _write_json(
            self.v6_root / "config.json",
            {
                "profiles": [{
                    "key": PROFILE_KEY,
                    "name": "Main",
                    "account_portrait_student_id": "ayane",
                }],
            },
        )
        current = self.v6_root / "profiles" / PROFILE_KEY / "data" / "current"
        _write_json(
            current / "students.json",
            {
                "ayane": {
                    "student_id": "ayane",
                    "display_name": "must not cross the bucket boundary",
                    "level": 1,
                    "student_star": 1,
                    "bond_rank": 1,
                },
            },
        )
        _write_json(
            current / "inventory.json",
            {
                "credit": {
                    "item_id": "credit",
                    "name": "Credit",
                    "quantity": 12,
                    "index": 0,
                },
            },
        )
        _write_json(
            current / "growth_plan.json",
            {"version": 1, "goals": [{"student_id": "ayane", "target_level": 10}]},
        )
        self.source_before = {
            path.relative_to(self.v6_root): path.read_bytes()
            for path in self.v6_root.rglob("*")
            if path.is_file()
        }

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_preview_and_import_copy_account_without_writing_v6(self) -> None:
        protocol = RepositoryProtocolV1(self.repository, v6_root=self.v6_root)
        envelope = {
            "protocol": 1,
            "type": "request",
            "id": "preview",
            "method": "repository.migration.preview",
            "payload": {},
        }
        preview = protocol.handle(envelope)
        self.assertEqual(preview["payload"]["accounts"][0]["student_count"], 1)
        self.assertEqual(preview["payload"]["accounts"][0]["goal_count"], 1)

        imported = protocol.handle({
            **envelope,
            "id": "import",
            "method": "repository.migration.import",
            "payload": {"source_profile_key": PROFILE_KEY},
        })["payload"]
        self.assertEqual(imported["profile"]["display_name"], "Main (v6 가져오기 2)")
        self.assertTrue(imported["profile"]["selected"])
        self.assertEqual((imported["student_count"], imported["inventory_count"], imported["goal_count"]), (1, 1, 1))

        state = self.repository.get_state(imported["profile"]["profile_id"])
        self.assertEqual(state["students"][0]["values"], {"level": 1, "bond_rank": 1, "student_star": 1})
        self.assertEqual(state["inventory"]["entries"][0]["quantity"], "12")
        self.assertEqual(state["goals"]["goals"][0]["target_level"], 10)
        self.assertEqual(
            self.source_before,
            {
                path.relative_to(self.v6_root): path.read_bytes()
                for path in self.v6_root.rglob("*")
                if path.is_file()
            },
        )

    def test_invalid_source_is_a_structured_protocol_error(self) -> None:
        protocol = RepositoryProtocolV1(self.repository, v6_root=self.v6_root / "missing")
        response = protocol.handle({
            "protocol": 1,
            "type": "request",
            "id": "preview",
            "method": "repository.migration.preview",
            "payload": {},
        })
        self.assertEqual(response["payload"]["error"]["code"], "migration_source_invalid")


if __name__ == "__main__":
    unittest.main()

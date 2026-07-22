from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from core.inventory_catalog import BY_KEY
from core.repository_dto import InventorySnapshot, RepositoryDTOError


ROOT = Path(__file__).parents[2]


class InventoryProtocolTests(unittest.TestCase):
    def test_repository_inventory_rejects_duplicate_canonical_identity(self) -> None:
        with self.assertRaises(RepositoryDTOError):
            InventorySnapshot.from_dict({"version":1,"entries":[
                {"key":"legacy-a","item_id":"same","quantity":"1"},
                {"key":"legacy-b","item_id":"same","quantity":"2"},
            ]})

    def test_v6_representative_parity_fixture_matches_catalog(self) -> None:
        fixture = json.loads((ROOT / "contracts/fixtures/inventory_catalog_v6_parity.json").read_text(encoding="utf-8"))
        self.assertEqual(fixture["version"], 1)
        for expected in fixture["representative_rows"]:
            with self.subTest(key=expected["resource_key"]):
                row = BY_KEY[expected["resource_key"]].to_dict()
                for key, value in expected.items():
                    self.assertEqual(row[key], value)

    def test_new_method_schemas_accept_canonical_messages_and_reject_malformed(self) -> None:
        schemas = {
            path.name: json.loads(path.read_text(encoding="utf-8"))
            for path in (ROOT / "contracts").glob("*.schema.json")
        }
        registry = Registry().with_resources([
            (schema["$id"], Resource.from_contents(schema)) for schema in schemas.values()
        ])
        catalog = Draft202012Validator(schemas["planning-inventory-catalog-v1.schema.json"], registry=registry)
        shortages = Draft202012Validator(schemas["planning-plan-shortages-v1.schema.json"], registry=registry)
        envelope = {"protocol":1,"id":"test","type":"request"}
        self.assertTrue(catalog.is_valid({**envelope,"method":"planning.inventory.catalog","payload":{}}))
        self.assertFalse(catalog.is_valid({**envelope,"method":"planning.inventory.catalog","payload":{"page":1}}))
        valid = {**envelope,"method":"planning.plan.shortages","payload":{
            "current_students":[],"plan":{"version":1,"goals":[]},
            "inventory":{"version":1,"entries":[{"key":"x","quantity":"0"}]},
        }}
        self.assertTrue(shortages.is_valid(valid))
        valid["payload"]["inventory"]["entries"][0]["quantity"] = "-1"
        self.assertFalse(shortages.is_valid(valid))

    def test_real_stdio_process_serves_catalog_and_shortages(self) -> None:
        requests = [
            {"protocol":1,"id":"catalog","type":"request","method":"planning.inventory.catalog","payload":{}},
            {"protocol":1,"id":"shortages","type":"request","method":"planning.plan.shortages","payload":{
                "current_students":[{"student_id":"ayane","level":1}],
                "plan":{"version":1,"goals":[{"student_id":"ayane","target_level":10}]},
                "inventory":{"version":1,"entries":[{"key":"Item_Icon_ExpItem_0","item_id":"Item_Icon_ExpItem_0","quantity":"0"}]}}},
        ]
        process = subprocess.run([sys.executable,"-m","core.backend_process"],cwd=ROOT/"backend",
            input="\n".join(json.dumps(item) for item in requests)+"\n",capture_output=True,text=True,encoding="utf-8",timeout=15)
        self.assertEqual(process.returncode,0,process.stderr)
        responses=[json.loads(line) for line in process.stdout.splitlines()]
        self.assertEqual([item["id"] for item in responses],["catalog","shortages"])
        self.assertGreater(len(responses[0]["payload"]["items"]),100)
        rows={row["resource_key"]:row for row in responses[1]["payload"]["rows"]}
        self.assertEqual(rows["Item_Icon_ExpItem_0"]["owned"],0)
        self.assertEqual(rows["Item_Icon_ExpItem_0"]["shortage"],1)
        self.assertEqual(rows["Item_Icon_ExpItem_0"]["affected_student_ids"],["ayane"])
        self.assertIsNone(rows["Item_Icon_ExpItem_1"]["owned"])
        self.assertIsNone(rows["Item_Icon_ExpItem_1"]["shortage"])


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import unittest

from core.state_export import EXPORT_PREFIX, decode_state_export, encode_state_export


class StateExportTests(unittest.TestCase):
    def test_export_round_trips_students_inventory_and_resources(self) -> None:
        token = encode_state_export(
            students=[
                {
                    "student_id": "shiroko",
                    "display_name": "Shiroko",
                    "level": 90,
                    "student_star": 5,
                    "equip1": "T9",
                }
            ],
            inventory={
                "Equipment_Icon_Hat_Tier9_Piece": {
                    "item_id": "Equipment_Icon_Hat_Tier9_Piece",
                    "name": "Hat T9 Blueprint",
                    "quantity": 42,
                }
            },
            resources={"credit": 123456},
            profile_name="Default",
            app_version="test",
            generated_at="2026-07-02T00:00:00+00:00",
        )

        self.assertTrue(token.startswith(EXPORT_PREFIX))
        payload = decode_state_export(token)
        self.assertEqual(payload["summary"]["student_count"], 1)
        self.assertEqual(payload["summary"]["inventory_count"], 1)
        self.assertEqual(payload["summary"]["resource_count"], 1)
        self.assertEqual(payload["students"][0]["student_id"], "shiroko")
        self.assertEqual(payload["inventory"]["Equipment_Icon_Hat_Tier9_Piece"]["quantity"], 42)
        self.assertEqual(payload["resources"]["credit"], 123456)


if __name__ == "__main__":
    unittest.main()

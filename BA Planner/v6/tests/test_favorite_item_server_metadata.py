from __future__ import annotations

import unittest
from unittest.mock import patch

from core import student_meta
from tools.schaledb_sync import scalar_values
from tools.student_meta_tool import build_metadata_detail_rows, build_metadata_table_rows


class FavoriteItemServerMetadataTests(unittest.TestCase):
    def test_prefers_server_value_and_keeps_legacy_fallback(self) -> None:
        students = {
            "server_split": {
                "has_favorite_item": "no",
                "has_favorite_item_jp": "yes",
                "has_favorite_item_kr": "no",
            },
            "legacy": {"has_favorite_item": "yes"},
        }
        with patch.object(student_meta, "STUDENTS", students):
            self.assertTrue(student_meta.favorite_item_enabled("server_split", server="jp"))
            self.assertFalse(student_meta.favorite_item_enabled("server_split", server="kr"))
            self.assertFalse(student_meta.favorite_item_enabled("server_split"))
            self.assertTrue(student_meta.favorite_item_enabled("legacy", server="jp"))
            self.assertTrue(student_meta.favorite_item_enabled("legacy", server="kr"))

    def test_rejects_unknown_server(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported server"):
            student_meta.has_favorite_item("shiroko", server="global")

    def test_schaledb_sync_maps_jp_and_kr_gear_release_flags(self) -> None:
        student = {
            "Gear": {"Released": [True, False, False]},
            "Equipment": [],
            "Skills": {},
        }
        values = scalar_values("test_student", student, {})
        self.assertEqual(values["has_favorite_item_jp"], "yes")
        self.assertEqual(values["has_favorite_item_kr"], "no")

    def test_metadata_debug_rows_show_resolved_server_values(self) -> None:
        students = {
            "test_student": {
                "display_name": "Test",
                "template_name": "test_student.png",
                "group": "Test",
                "variant": None,
                "has_favorite_item": "no",
                "has_favorite_item_jp": "yes",
                "has_favorite_item_kr": "no",
            }
        }
        with patch.object(student_meta, "STUDENTS", students):
            row = build_metadata_table_rows(students)[0]
            details = {
                field: value
                for field, _label, value in build_metadata_detail_rows("test_student", students)
            }
        self.assertEqual(row["favorite_item_jp"], "yes")
        self.assertEqual(row["favorite_item_kr"], "no")
        self.assertEqual(details["has_favorite_item_jp"], "yes")
        self.assertEqual(details["has_favorite_item_kr"], "no")


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from jsonschema import Draft202012Validator

from core import student_meta, student_meta_data
from core.canonical_metadata import (
    CanonicalMetadataCatalog,
    CanonicalMetadataError,
    load_catalog,
    write_catalog,
)
from core.runtime_paths import PACKAGED_METADATA_CATALOG_PATH
from core.schaledb_metadata_adapter import adapt_student, local_id_for_path, path_for_local_id
from core.schaledb_provider import SchaleDBProvider


class CanonicalMetadataTests(unittest.TestCase):
    def test_packaged_catalog_preserves_legacy_runtime_parity(self) -> None:
        catalog = load_catalog(PACKAGED_METADATA_CATALOG_PATH)
        self.assertEqual(student_meta_data.STUDENTS, catalog.legacy_students())
        self.assertEqual(student_meta_data.MULTI_FORM_STUDENTS, catalog.forms)
        self.assertEqual(student_meta_data.JP_ONLY_STUDENT_IDS, catalog.jp_only_student_ids)
        self.assertEqual(student_meta_data.FAVORITE_ITEM_STUDENT_IDS, catalog.favorite_item_student_ids)
        self.assertEqual(student_meta_data.FAVORITE_ITEM_MAX_TIER, catalog.favorite_item_max_tier)
        self.assertEqual(student_meta_data.STUDENTS, student_meta.STUDENTS)

    def test_provider_fields_are_not_part_of_canonical_student_records(self) -> None:
        catalog = load_catalog(PACKAGED_METADATA_CATALOG_PATH)
        self.assertTrue(catalog.provider_student_ids["schaledb"])
        for record in catalog.students.values():
            self.assertNotIn("schaledb_id", record)
            self.assertNotIn("favor_item_tags", record)
            self.assertNotIn("favor_item_unique_tags", record)

    def test_packaged_catalog_matches_its_json_schema(self) -> None:
        schema_path = PACKAGED_METADATA_CATALOG_PATH.with_name("catalog.schema.json")
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        payload = json.loads(PACKAGED_METADATA_CATALOG_PATH.read_text(encoding="utf-8"))
        Draft202012Validator(schema).validate(payload)

    def test_catalog_round_trip_keeps_provider_data_separate(self) -> None:
        catalog = CanonicalMetadataCatalog.from_legacy(
            students={
                "sample": {
                    "display_name": "샘플",
                    "template_name": "sample.png",
                    "group": "샘플",
                    "variant": None,
                    "schaledb_id": 100,
                    "favor_item_tags": ["general"],
                    "favor_item_unique_tags": ["unique"],
                }
            },
            forms={},
            jp_only_student_ids=set(),
            favorite_item_student_ids=set(),
            favorite_item_max_tier="T2",
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "catalog.json"
            write_catalog(catalog, path)
            payload = json.loads(path.read_text(encoding="utf-8"))
            restored = load_catalog(path)
        self.assertNotIn("schaledb_id", payload["students"]["sample"])
        self.assertEqual(100, payload["provider_refs"]["schaledb"]["student_ids"]["sample"])
        self.assertEqual(catalog.legacy_students(), restored.legacy_students())

    def test_catalog_rejects_provider_fields_in_student_record(self) -> None:
        with self.assertRaisesRegex(CanonicalMetadataError, "provider-owned"):
            CanonicalMetadataCatalog.from_payload({
                "version": 1,
                "students": {
                    "sample": {
                        "display_name": "Sample",
                        "template_name": "sample.png",
                        "group": "Sample",
                        "schaledb_id": 100,
                    }
                },
                "forms": {},
                "server_availability": {"jp_only_student_ids": []},
                "favorite_items": {"student_ids": [], "max_tier": "T2"},
                "provider_refs": {},
                "gift_affinities": {},
            })

    def test_developer_tool_writer_updates_canonical_catalog(self) -> None:
        from tools import developer_tools

        catalog = CanonicalMetadataCatalog.from_legacy(
            students={
                "sample": {
                    "display_name": "Old",
                    "template_name": "sample.png",
                    "group": "Sample",
                    "schaledb_id": 100,
                }
            },
            forms={"sample": ({"label": "1", "template_name": "sample.png"},)},
            jp_only_student_ids=set(),
            favorite_item_student_ids=set(),
            favorite_item_max_tier="T2",
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "catalog.json"
            write_catalog(catalog, path)
            old_path = developer_tools.CANONICAL_METADATA_PATH
            try:
                developer_tools.CANONICAL_METADATA_PATH = path
                developer_tools._write_students_and_jp_only(
                    {
                        "sample": {
                            "display_name": "New",
                            "template_name": "sample.png",
                            "group": "Sample",
                            "schaledb_id": 101,
                        }
                    },
                    {"sample"},
                )
            finally:
                developer_tools.CANONICAL_METADATA_PATH = old_path
            restored = load_catalog(path)
        self.assertEqual("New", restored.students["sample"]["display_name"])
        self.assertEqual(101, restored.provider_student_ids["schaledb"]["sample"])
        self.assertEqual(frozenset({"sample"}), restored.jp_only_student_ids)
        self.assertEqual(1, len(restored.forms["sample"]))


class SchaleDBBoundaryTests(unittest.TestCase):
    def test_provider_only_fetches_raw_documents(self) -> None:
        calls: list[str] = []

        def fetcher(url: str) -> dict[str, object]:
            calls.append(url)
            return {"url": url}

        students, items = SchaleDBProvider(fetcher).snapshot()
        self.assertIn("students.min.json", str(students["url"]))
        self.assertIn("items.min.json", str(items["url"]))
        self.assertEqual(2, len(calls))

    def test_adapter_allowlists_minimal_student_fields(self) -> None:
        adapted = adapt_student({
            "Id": 100,
            "FavorItemTags": ["aV"],
            "FavorItemUniqueTags": ["Bf"],
            "FavorStatType": ["DefensePower"],
            "FavorStatValue": [[1, 2, 3]],
        })
        self.assertEqual(
            {"schaledb_id", "favor_item_tags", "favor_item_unique_tags"},
            set(adapted),
        )

    def test_adapter_owns_slug_mapping(self) -> None:
        rules = {"hoshino_battle": ("hoshino_battle_tank", "hoshino_battle_dealer")}
        self.assertEqual("hoshino_battle_tank", path_for_local_id("hoshino_battle", rules))
        self.assertEqual(
            "hoshino_battle",
            local_id_for_path("hoshino_battle_dealer", ["hoshino_battle"], rules),
        )


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from tools import developer_tools


class DeveloperToolsTests(unittest.TestCase):
    def test_replace_assignment_preserves_surrounding_source(self) -> None:
        source = "before = 1\nVALUE: dict[str, int] = {\n    'old': 1,\n}\nafter = 2\n"
        result = developer_tools._replace_assignment(source, "VALUE", "VALUE: dict[str, int] = {'new': 2}")
        self.assertEqual(
            "before = 1\nVALUE: dict[str, int] = {'new': 2}\nafter = 2\n",
            result,
        )

    def test_metadata_list_uses_v7_generated_catalog(self) -> None:
        response = developer_tools.dispatch(
            {"version": 1, "method": "metadata.list", "params": {"query": "hoshino"}}
        )
        ids = {row["student_id"] for row in response["result"]["students"]}
        self.assertIn("hoshino", ids)
        self.assertGreater(response["result"]["total"], 200)

    def test_metadata_forms_get_and_save_normalize_multi_form_overrides(self) -> None:
        module = SimpleNamespace(
            STUDENTS={"hoshino": {"display_name": "호시노"}},
            MULTI_FORM_STUDENTS={
                "existing": ({"label": "1", "template_name": "existing.png"},),
            },
        )
        with patch.object(developer_tools, "_metadata_module", return_value=module):
            empty = developer_tools.metadata_forms_get({"student_id": "hoshino"})
        self.assertEqual({"student_id": "hoshino", "forms": [], "form_count": 0}, empty)

        with (
            patch.object(developer_tools, "_metadata_module", return_value=module),
            patch.object(developer_tools, "_write_multi_forms") as write_forms,
        ):
            result = developer_tools.metadata_forms_save(
                {
                    "student_id": "hoshino",
                    "forms": [
                        {"template_name": "hoshino.png", "role": "tanker"},
                        {"label": "탑승", "template_name": "hoshino_1.png", "role": "dealer"},
                    ],
                }
            )

        written = write_forms.call_args.args[0]
        self.assertIn("existing", written)
        self.assertEqual("1", written["hoshino"][0]["label"])
        self.assertEqual("탑승", written["hoshino"][1]["label"])
        self.assertEqual(2, result["form_count"])

    def test_metadata_forms_reject_unknown_fields(self) -> None:
        module = SimpleNamespace(STUDENTS={"hoshino": {}}, MULTI_FORM_STUDENTS={})
        with patch.object(developer_tools, "_metadata_module", return_value=module):
            with self.assertRaisesRegex(ValueError, "unknown fields"):
                developer_tools.metadata_forms_save(
                    {
                        "student_id": "hoshino",
                        "forms": [{"template_name": "hoshino.png", "not_a_field": True}],
                    }
                )

    def test_metadata_debug_filters_servers_and_reports_assets_and_details(self) -> None:
        module = SimpleNamespace(
            STUDENTS={
                "hoshino": {
                    "display_name": "호시노",
                    "template_name": "hoshino.png",
                    "group": "호시노",
                    "school": "Abydos",
                    "has_favorite_item": "yes",
                },
                "shun": {
                    "display_name": "슌",
                    "template_name": "shun.png",
                    "group": "슌",
                    "school": "Shanhaijing",
                },
            },
            JP_ONLY_STUDENT_IDS=frozenset({"shun"}),
            MULTI_FORM_STUDENTS={
                "hoshino": (
                    {"label": "1", "template_name": "hoshino.png"},
                    {"label": "2", "template_name": "hoshino_1.png"},
                )
            },
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            portrait = root / "frontend" / "assets" / "student_portraits" / "hoshino.png"
            eleph = root / "frontend" / "assets" / "student_elephs" / "Item_Icon_SecretStone_hoshino.png"
            matches = root / "backend" / "assets" / "recognition" / "v1" / "templates" / "students"
            portrait.parent.mkdir(parents=True)
            eleph.parent.mkdir(parents=True)
            matches.mkdir(parents=True)
            portrait.write_bytes(b"portrait")
            eleph.write_bytes(b"eleph")
            (matches / "hoshino.png").write_bytes(b"match")
            (matches / "hoshino_1.png").write_bytes(b"match")
            with (
                patch.object(developer_tools, "_metadata_module", return_value=module),
                patch.object(developer_tools, "V7_DIR", root),
                patch.object(developer_tools, "BACKEND_DIR", root / "backend"),
            ):
                listing = developer_tools.metadata_debug_list({"server": "kr", "query": "Abydos"})
                detail = developer_tools.metadata_debug_get({"student_id": "hoshino"})

        self.assertEqual({"all": 2, "kr": 1, "jp": 1}, listing["counts"])
        self.assertEqual(1, listing["visible_count"])
        row = listing["rows"][0]
        self.assertEqual("KR", row["server"])
        self.assertTrue(row["portrait"])
        self.assertTrue(row["eleph"])
        self.assertEqual((2, 2), (row["match_found"], row["match_total"]))
        self.assertEqual(2, detail["form_count"])
        fields = {field["name"]: field["value"] for field in detail["fields"]}
        self.assertEqual("yes", fields["has_favorite_item_jp"])
        self.assertEqual("yes", fields["has_favorite_item_kr"])

    def test_metadata_server_set_only_rewrites_jp_membership_and_reports_kr_asset_warnings(self) -> None:
        module = SimpleNamespace(
            STUDENTS={
                "hoshino": {"display_name": "호시노", "template_name": "hoshino.png"},
                "shun": {"display_name": "슌", "template_name": "shun.png"},
            },
            JP_ONLY_STUDENT_IDS=frozenset({"hoshino", "shun"}),
            MULTI_FORM_STUDENTS={},
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with (
                patch.object(developer_tools, "_metadata_module", return_value=module),
                patch.object(developer_tools, "V7_DIR", root),
                patch.object(developer_tools, "BACKEND_DIR", root / "backend"),
                patch.object(developer_tools, "_write_metadata_assignment") as write_assignment,
            ):
                result = developer_tools.metadata_server_set(
                    {"student_id": "hoshino", "server": "kr"}
                )

        name, rendered = write_assignment.call_args.args
        self.assertEqual("JP_ONLY_STUDENT_IDS", name)
        self.assertNotIn("hoshino", rendered)
        self.assertIn("shun", rendered)
        self.assertEqual("JP", result["previous_server"])
        self.assertEqual("KR", result["server"])
        self.assertTrue(result["changed"])
        self.assertEqual(2, len(result["warnings"]))

    def test_metadata_merge_paths_save_normalizes_sources_and_rejects_duplicate_slug(self) -> None:
        module = SimpleNamespace(
            STUDENTS={
                "hoshino_battle": {
                    "display_name": "호시노(전투)",
                    "template_name": "hoshino_battle.png",
                },
                "other": {"display_name": "다른 학생"},
            }
        )
        initial = {"other": ("already_used", "other_form")}
        with (
            patch.object(developer_tools, "_metadata_module", return_value=module),
            patch.object(developer_tools, "_get_schale_merge_paths", return_value=dict(initial)),
            patch.object(developer_tools, "_write_schale_merge_paths") as write_paths,
        ):
            result = developer_tools.metadata_merge_paths_save(
                {
                    "student_id": "hoshino_battle",
                    "paths": [
                        "https://schaledb.com/student/hoshino_battle_tank",
                        "hoshino_battle_dealer",
                        "hoshino_battle_tank",
                    ],
                }
            )

        written = write_paths.call_args.args[0]
        self.assertEqual(
            ("hoshino_battle_tank", "hoshino_battle_dealer"),
            written["hoshino_battle"],
        )
        self.assertEqual(2, result["path_count"])

        with (
            patch.object(developer_tools, "_metadata_module", return_value=module),
            patch.object(developer_tools, "_get_schale_merge_paths", return_value=dict(initial)),
        ):
            with self.assertRaisesRegex(ValueError, "already used"):
                developer_tools.metadata_merge_paths_save(
                    {
                        "student_id": "hoshino_battle",
                        "paths": ["already_used", "new_form"],
                    }
                )

    def test_secondary_merge_path_reverse_matches_same_local_student(self) -> None:
        rules = {
            "hoshino_battle": ("hoshino_battle_tank", "hoshino_battle_dealer")
        }
        with patch.object(developer_tools, "_get_schale_merge_paths", return_value=rules):
            self.assertEqual(
                "hoshino_battle_tank",
                developer_tools._schale_path_for_local_id("hoshino_battle"),
            )
            self.assertEqual(
                "hoshino_battle",
                developer_tools._local_id_for_schale_path(
                    "hoshino_battle_dealer",
                    {"hoshino_battle": {}},
                ),
            )

    def test_metadata_merge_paths_list_and_delete(self) -> None:
        module = SimpleNamespace(
            STUDENTS={
                "hoshino_battle": {
                    "display_name": "호시노(전투)",
                    "template_name": "hoshino_battle.png",
                }
            }
        )
        rules = {
            "hoshino_battle": ("hoshino_battle_tank", "hoshino_battle_dealer")
        }
        with (
            patch.object(developer_tools, "_metadata_module", return_value=module),
            patch.object(developer_tools, "_get_schale_merge_paths", return_value=dict(rules)),
        ):
            listing = developer_tools.metadata_merge_paths_list({})
        self.assertEqual("hoshino_battle.png", listing["rows"][0]["template_name"])

        with (
            patch.object(developer_tools, "_get_schale_merge_paths", return_value=dict(rules)),
            patch.object(developer_tools, "_write_schale_merge_paths") as write_paths,
        ):
            deleted = developer_tools.metadata_merge_paths_delete(
                {"student_id": "hoshino_battle"}
            )
        self.assertTrue(deleted["deleted"])
        write_paths.assert_called_once_with({})

    def test_metadata_item_analysis_keeps_unknown_zero_and_shortage_distinct(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inventory_path = root / "profile.json"
            plan_path = root / "plan-delta.json"
            inventory_path.write_text(
                json.dumps(
                    {
                        "inventory": {
                            "version": 1,
                            "entries": [
                                {
                                    "key": "Equipment_Icon_Badge_Tier1",
                                    "item_id": "Equipment_Icon_Badge_Tier1",
                                    "quantity": "5",
                                },
                                {"key": "Item_Icon_ExpItem_0", "quantity": "0"},
                                {"key": "Item_Icon_ExpItem_1", "quantity": None},
                                {"key": "not-in-catalog", "quantity": "3"},
                            ],
                        }
                    }
                ),
                encoding="utf-8",
            )
            plan_path.write_text(
                json.dumps(
                    {
                        "Equipment_Icon_Badge_Tier1": {"delta": -7},
                        "Item_Icon_ExpItem_0": 0,
                    }
                ),
                encoding="utf-8",
            )
            result = developer_tools.metadata_items_analyze(
                {
                    "inventory_path": str(inventory_path),
                    "plan_path": str(plan_path),
                }
            )

        rows = {row["resource_key"]: row for row in result["rows"]}
        self.assertEqual("negative", rows["Equipment_Icon_Badge_Tier1"]["status"])
        self.assertEqual(-2, rows["Equipment_Icon_Badge_Tier1"]["adjusted_qty"])
        self.assertEqual("zero", rows["Item_Icon_ExpItem_0"]["status"])
        self.assertEqual("unknown", rows["Item_Icon_ExpItem_1"]["status"])
        self.assertEqual("missing_catalog", rows["not-in-catalog"]["category"])
        self.assertEqual(4, result["summary"]["snapshot_count"])
        self.assertEqual(3, result["summary"]["known_count"])
        self.assertEqual(1, result["summary"]["unknown_count"])
        self.assertEqual(1, result["summary"]["negative_count"])
        self.assertNotIn("current_sum", result["summary"])
        self.assertNotIn("adjusted_sum", result["summary"])

    def test_metadata_item_analysis_reads_selected_repository_by_default(self) -> None:
        snapshot = {
            "version": 1,
            "entries": [{"key": "Item_Icon_ExpItem_0", "quantity": "12"}],
        }
        with patch.object(
            developer_tools,
            "_selected_repository_inventory",
            return_value=(snapshot, "v7 선택 계정 · 테스트", "profile.json"),
        ):
            result = developer_tools.metadata_items_analyze({})

        self.assertEqual("v7 선택 계정 · 테스트", result["source_label"])
        self.assertEqual(12, result["rows"][0]["current_qty"])
        self.assertEqual("positive", result["rows"][0]["status"])

    def test_schaledb_preview_keeps_only_minimal_bond_fields(self) -> None:
        module = SimpleNamespace(
            STUDENTS={
                "hoshino": {
                    "display_name": "호시노",
                    "template_name": "hoshino.png",
                    "favor_item_tags": ["old"],
                }
            },
            JP_ONLY_STUDENT_IDS=frozenset(),
        )
        schale_students = {
            "100": {
                "Id": 100,
                "PathName": "hoshino",
                "FavorItemTags": ["aV"],
                "FavorItemUniqueTags": ["Bf", "de"],
                "FavorStatType": ["DefensePower"],
            }
        }
        schale_items = {
            "5000": {
                "Id": 5000,
                "Category": "Favor",
                "Tags": ["aV"],
                "ExpValue": 20,
                "Name": "Gift",
                "Icon": "Item_Icon_Favor_0",
                "Quality": 3,
            },
            "5001": {
                "Id": 5001,
                "Category": "Favor",
                "Tags": ["Bf", "BC"],
                "ExpValue": 20,
                "Name": "Special Gift",
                "Icon": "Item_Icon_Favor_1",
            },
            "1": {"Id": 1, "Category": "Material", "Tags": [], "ExpValue": 0},
        }
        with (
            patch.object(developer_tools, "_metadata_module", return_value=module),
            patch.object(
                developer_tools,
                "_fetch_schaledb_json",
                side_effect=[schale_students, schale_items],
            ),
        ):
            result = developer_tools.metadata_schaledb_preview({})

        self.assertEqual(1, result["student_count"])
        self.assertEqual(2, result["gift_count"])
        self.assertEqual(
            {
                "schaledb_id": 100,
                "favor_item_tags": ["aV"],
                "favor_item_unique_tags": ["Bf", "de"],
            },
            result["students"][0]["incoming"],
        )
        self.assertEqual(
            {"id", "category", "tags", "exp_value", "name", "icon_asset"},
            set(result["gifts"][0]),
        )
        student = result["students"][0]
        self.assertEqual("Special Gift", student["special_gifts"][0]["name"])
        self.assertEqual(2, student["special_gifts"][0]["match_count"])
        self.assertEqual(3, student["special_gifts"][0]["multiplier"])
        self.assertEqual(60, student["special_gifts"][0]["points"])
        self.assertEqual("Gift", student["preferred_gifts"][0]["name"])
        self.assertEqual(40, student["preferred_gifts"][0]["points"])
        self.assertNotIn("FavorStatType", json.dumps(result))

    def test_schaledb_apply_updates_students_and_gifts_together(self) -> None:
        module = SimpleNamespace(
            STUDENTS={"hoshino": {"display_name": "호시노"}},
            JP_ONLY_STUDENT_IDS=frozenset({"jp_student"}),
        )
        snapshot = {
            "students": [
                {
                    "student_id": "hoshino",
                    "changed_fields": ["schaledb_id"],
                    "incoming": {
                        "schaledb_id": 100,
                        "favor_item_tags": ["aV"],
                        "favor_item_unique_tags": ["Bf"],
                    },
                }
            ],
            "gifts": [{"id": 5000, "category": "Favor", "tags": ["aV"], "exp_value": 20}],
            "missing_student_ids": [],
        }
        with (
            patch.object(developer_tools, "_minimal_schale_snapshot", return_value=snapshot),
            patch.object(developer_tools, "_metadata_module", return_value=module),
            patch.object(developer_tools, "_write_students_and_jp_only") as write_students,
            patch.object(developer_tools, "_write_gift_metadata") as write_gifts,
        ):
            result = developer_tools.metadata_schaledb_apply({})

        written_students, written_jp = write_students.call_args.args
        self.assertEqual(100, written_students["hoshino"]["schaledb_id"])
        self.assertEqual({"jp_student"}, written_jp)
        write_gifts.assert_called_once_with(snapshot["gifts"])
        self.assertEqual({"updated_students": 1, "gift_count": 1, "missing_student_ids": []}, result)

    def test_single_schaledb_preview_parses_url_and_keeps_minimal_fields(self) -> None:
        module = SimpleNamespace(
            STUDENTS={
                "hoshino": {
                    "display_name": "호시노",
                    "template_name": "hoshino.png",
                    "schaledb_id": 1,
                }
            },
            JP_ONLY_STUDENT_IDS=frozenset(),
        )
        schale_students = {
            "100": {
                "Id": 100,
                "PathName": "hoshino",
                "FavorItemTags": ["aV"],
                "FavorItemUniqueTags": ["Bf"],
                "FavorStatType": ["DefensePower"],
            }
        }
        schale_items = {
            "5000": {
                "Id": 5000,
                "Category": "Favor",
                "Tags": ["Bf", "BC"],
                "ExpValue": 20,
                "Name": "Special Gift",
                "Icon": "Item_Icon_Favor_0",
            }
        }
        with (
            patch.object(developer_tools, "_metadata_module", return_value=module),
            patch.object(
                developer_tools,
                "_fetch_schaledb_json",
                side_effect=[schale_students, schale_items],
            ),
        ):
            result = developer_tools.metadata_schaledb_single_preview(
                {"source": "https://schaledb.com/student/hoshino"}
            )

        self.assertEqual("hoshino", result["source_slug"])
        self.assertEqual("hoshino", result["student_id"])
        self.assertTrue(result["exists"])
        self.assertEqual(
            {"schaledb_id", "favor_item_tags", "favor_item_unique_tags"},
            set(result["incoming"]),
        )
        self.assertEqual(60, result["special_gifts"][0]["points"])
        self.assertNotIn("FavorStatType", json.dumps(result))

    def test_single_schaledb_apply_updates_only_existing_student_and_gifts(self) -> None:
        snapshot = {
            "student_id": "hoshino",
            "exists": True,
            "incoming": {
                "schaledb_id": 100,
                "favor_item_tags": ["aV"],
                "favor_item_unique_tags": ["Bf"],
            },
            "changed_fields": ["schaledb_id"],
            "gifts": [{"id": 5000, "category": "Favor", "tags": ["aV"], "exp_value": 20}],
        }
        module = SimpleNamespace(
            STUDENTS={"hoshino": {"display_name": "호시노", "unrelated": "keep"}},
            JP_ONLY_STUDENT_IDS=frozenset(),
        )
        with (
            patch.object(developer_tools, "_single_schale_snapshot", return_value=snapshot),
            patch.object(developer_tools, "_metadata_module", return_value=module),
            patch.object(developer_tools, "_write_students_and_jp_only") as write_students,
            patch.object(developer_tools, "_write_gift_metadata") as write_gifts,
        ):
            result = developer_tools.metadata_schaledb_single_apply({})

        written_students, _jp = write_students.call_args.args
        self.assertEqual("keep", written_students["hoshino"]["unrelated"])
        self.assertEqual(100, written_students["hoshino"]["schaledb_id"])
        write_gifts.assert_called_once_with(snapshot["gifts"])
        self.assertEqual(["schaledb_id"], result["updated_fields"])

    def test_template_preview_uses_ratio_crop(self) -> None:
        from PIL import Image

        with tempfile.TemporaryDirectory() as directory:
            image_path = Path(directory) / "source.png"
            Image.new("RGB", (200, 100), "navy").save(image_path)
            with patch.object(
                developer_tools,
                "_student_region",
                return_value=({"x1": 0.1, "y1": 0.2, "x2": 0.8, "y2": 0.9}, Path(directory)),
            ):
                result = developer_tools.template_preview({"image_path": str(image_path)})
            self.assertEqual([20, 20, 160, 90], result["crop"])
            self.assertTrue(Path(result["preview_path"]).is_file())

    def test_student_manifest_entry_is_replaced_with_current_integrity(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image_path = root / "templates" / "students" / "sample.png"
            image_path.parent.mkdir(parents=True)
            image_path.write_bytes(b"new-png")
            (root / "manifest.json").write_text(
                json.dumps(
                    {
                        "version": 1,
                        "assets": [
                            {
                                "path": "old.png",
                                "scan_kind": "student",
                                "purpose": "student-template",
                                "student_id": "sample",
                            },
                            {"path": "keep.png", "scan_kind": "inventory", "purpose": "inventory-template"},
                        ],
                    }
                ),
                encoding="utf-8",
            )
            developer_tools._update_student_manifest(root, "sample", image_path)
            manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
            matching = [entry for entry in manifest["assets"] if entry.get("student_id") == "sample"]
            self.assertEqual(1, len(matching))
            self.assertEqual(len(b"new-png"), matching[0]["bytes"])
            self.assertEqual(hashlib.sha256(b"new-png").hexdigest(), matching[0]["sha256"])


if __name__ == "__main__":
    unittest.main()

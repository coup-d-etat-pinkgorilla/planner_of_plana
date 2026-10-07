from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

from core import student_meta
from core.protocol_v1 import PlanningProtocolV1


class StudentCatalogTests(unittest.TestCase):
    def test_catalog_is_stable_minimal_and_has_fallbacks(self) -> None:
        source = {
            "z": {"display_name": "긴 이름" * 20, "search_tags": ["tag"]},
            "missing": {},
            "a": {"display_name": "가나다", "school": "Abydos"},
        }
        handler = PlanningProtocolV1(
            student_ids=lambda: ["z", "missing", "a"],
            student_lookup=source.get,
            student_jp_only=lambda student_id: student_id == "z",
        )
        response = handler.handle({"protocol":1,"id":"catalog","type":"request","method":"planning.student.catalog","payload":{}})
        self.assertEqual(["missing", "a", "z"], [item["student_id"] for item in response["payload"]["students"]])
        fallback = response["payload"]["students"][0]
        self.assertEqual("missing", fallback["display_name"])
        self.assertEqual("missing.png", fallback["template_name"])
        self.assertFalse(fallback["jp_only"])
        self.assertTrue(response["payload"]["students"][-1]["jp_only"])
        self.assertNotIn("raw_skill_material", fallback)

    def test_catalog_lists_forms_only_for_multi_form_students(self) -> None:
        # FB-5: students with two or more forms get a form list; others keep the old shape.
        source = {
            "multi": {"display_name": "다중"},
            "single": {"display_name": "단일"},
            "none": {"display_name": "없음"},
        }
        forms = {
            "multi": (
                {"label": "1", "template_name": "multi.png", "attack_type": "Mystic"},
                {"label": "2", "template_name": "multi_1.png"},
                {"label": "", "template_name": ""},
            ),
            "single": ({"label": "1", "template_name": "single.png"},),
        }
        handler = PlanningProtocolV1(
            student_ids=lambda: ["multi", "single", "none"],
            student_lookup=source.get,
            student_jp_only=lambda _student_id: False,
            student_forms=lambda student_id: forms.get(student_id, ()),
        )
        response = handler.handle({"protocol":1,"id":"forms","type":"request","method":"planning.student.catalog","payload":{}})
        students = {item["student_id"]: item for item in response["payload"]["students"]}
        self.assertEqual(
            [
                {"form_id": "multi", "label": "1", "template_name": "multi.png"},
                {"form_id": "multi#2", "label": "2", "template_name": "multi_1.png"},
                {"form_id": "multi#3", "label": "3", "template_name": None},
            ],
            students["multi"]["forms"],
        )
        self.assertNotIn("forms", students["single"])
        self.assertNotIn("forms", students["none"])
        # Existing fields keep their order; forms is appended last.
        self.assertEqual("kr_search_tags", list(students["single"])[-1])
        self.assertEqual(["kr_search_tags", "forms"], list(students["multi"])[-2:])

    def test_catalog_forms_follow_canonical_multi_form_metadata(self) -> None:
        response = PlanningProtocolV1().handle({"protocol":1,"id":"real-forms","type":"request","method":"planning.student.catalog","payload":{}})
        students = {item["student_id"]: item for item in response["payload"]["students"]}
        multi = {student_id for student_id, item in students.items() if "forms" in item}
        self.assertEqual(
            {student_id for student_id, forms in student_meta.MULTI_FORM_STUDENTS.items() if len(forms) > 1},
            multi,
        )
        self.assertIn("hoshino_battle", multi)
        self.assertEqual(
            ["hoshino_battle", "hoshino_battle#2"],
            [form["form_id"] for form in students["hoshino_battle"]["forms"]],
        )
        self.assertEqual(
            [str(form.get("template_name")) for form in student_meta.MULTI_FORM_STUDENTS["hoshino_battle"]],
            [form["template_name"] for form in students["hoshino_battle"]["forms"]],
        )
        for student_id in multi:
            self.assertEqual(
                student_meta.format_form_ref(student_id, 2),
                students[student_id]["forms"][1]["form_id"],
            )

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
        by_id = {item["student_id"]: item for item in response["payload"]["students"]}
        self.assertEqual(2, len(by_id["hoshino_battle"]["forms"]))


if __name__ == "__main__":
    unittest.main()

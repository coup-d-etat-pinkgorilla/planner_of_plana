"""Export the backend student metadata catalog for the Flutter mock runtime."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"
OUTPUT = ROOT / "frontend" / "assets" / "student_catalog.json"
sys.path.insert(0, str(BACKEND))

from core.student_meta import all_ids, get, is_jp_only  # noqa: E402


def _text(value: object, fallback: str) -> str:
    return value if isinstance(value, str) and value else fallback


def main() -> None:
    students: list[dict[str, object]] = []
    for student_id in all_ids():
        metadata = get(student_id) or {}
        students.append(
            {
                "student_id": student_id,
                "display_name": _text(metadata.get("display_name"), student_id),
                "template_name": _text(
                    metadata.get("template_name"), f"{student_id}.png"
                ),
                "group": _text(metadata.get("group"), student_id),
                "variant": metadata.get("variant")
                if isinstance(metadata.get("variant"), str)
                else None,
                "school": metadata.get("school")
                if isinstance(metadata.get("school"), str)
                else None,
                "rarity": metadata.get("rarity")
                if isinstance(metadata.get("rarity"), str)
                else None,
                "attack_type": metadata.get("attack_type")
                if isinstance(metadata.get("attack_type"), str)
                else None,
                "defense_type": metadata.get("defense_type")
                if isinstance(metadata.get("defense_type"), str)
                else None,
                "combat_class": metadata.get("combat_class")
                if isinstance(metadata.get("combat_class"), str)
                else None,
                "role": metadata.get("role")
                if isinstance(metadata.get("role"), str)
                else None,
                "position": metadata.get("position")
                if isinstance(metadata.get("position"), str)
                else None,
                "equipment_slot_1": metadata.get("equipment_slot_1")
                if isinstance(metadata.get("equipment_slot_1"), str)
                else None,
                "equipment_slot_2": metadata.get("equipment_slot_2")
                if isinstance(metadata.get("equipment_slot_2"), str)
                else None,
                "equipment_slot_3": metadata.get("equipment_slot_3")
                if isinstance(metadata.get("equipment_slot_3"), str)
                else None,
                "jp_only": is_jp_only(student_id),
                "search_tags": [
                    str(item)
                    for item in metadata.get("search_tags", [])
                    if str(item).strip()
                ],
                "kr_search_tags": [
                    str(item)
                    for item in metadata.get("kr_search_tags", [])
                    if str(item).strip()
                ],
            }
        )
    students.sort(
        key=lambda item: (str(item["display_name"]).casefold(), item["student_id"])
    )
    OUTPUT.write_text(
        json.dumps(students, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"exported {len(students)} students to {OUTPUT}")


if __name__ == "__main__":
    main()

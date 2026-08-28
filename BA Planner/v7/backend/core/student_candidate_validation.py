from __future__ import annotations

from dataclasses import asdict
from typing import Any, Mapping

from core.student_stats import calculate_student_stats
from core.student_stats_catalog import load_student_stat_catalog, student_stat_record
from core.student_stats_types import (
    EquipmentLevelV1, PotentialLevelsV1, RelationshipLevelsV1, StudentStatBuildV1,
    UniqueWeaponLevelV1,
)


STAT_FIELDS = {
    "MaxHP": "combat_hp", "AttackPower": "combat_atk",
    "DefensePower": "combat_def", "HealPower": "combat_heal",
}


class StudentCandidateValidator:
    """Produces non-mutating S4 calculation evidence for a scanned student."""

    def __init__(self, repository) -> None:
        self.repository = repository
        self.catalog = load_student_stat_catalog()

    @staticmethod
    def _tier(value: object) -> int | None:
        if not isinstance(value, str) or not value.startswith("T") or not value[1:].isdigit():
            return None
        return int(value[1:])

    def __call__(
        self,
        payload: Mapping[str, Any],
        profile_id: str | None,
        relationship_ranks: Mapping[int, int] | None = None,
    ) -> dict[str, Any]:
        values = payload.get("values") if isinstance(payload, Mapping) else None
        student_id = payload.get("student_id") if isinstance(payload, Mapping) else None
        details: dict[str, Any] = {
            "calculation_version": 1,
            "calculation_scope": "basic_info_primary_stats_with_alternate_relationships",
            "expected": None, "observed": {}, "delta": {}, "dependencies": [],
            "suggestion": None, "contributions": {}, "relationship_contributions": [],
        }
        if not isinstance(values, Mapping) or not isinstance(student_id, str):
            return self._evidence("partial", details, "candidate payload is incomplete")
        try:
            student = student_stat_record(student_id, catalog=self.catalog)
        except (KeyError, ValueError) as exc:
            details["dependencies"].append({"kind": "student_static_data", "key": student_id})
            return self._evidence("partial", details, str(exc))

        rank = values.get("bond_rank")
        level = values.get("level")
        star = values.get("student_star")
        for key, value in (("bond_rank", rank), ("level", level), ("student_star", star)):
            if not isinstance(value, int) or isinstance(value, bool):
                details["dependencies"].append({"kind": "candidate_field", "key": key})
        passive_skill_level = values.get("skill2")
        equipment: list[EquipmentLevelV1 | None] = []
        for slot in range(1, 4):
            tier = self._tier(values.get(f"equip{slot}"))
            equip_level = values.get(f"equip{slot}_level")
            if tier is None or not isinstance(equip_level, int):
                details["dependencies"].append({"kind": "candidate_field", "key": f"equip{slot}"})
                equipment.append(None)
            else:
                equipment.append(EquipmentLevelV1(tier, equip_level))
        if details["dependencies"]:
            return self._evidence("partial", details, "required scan fields are missing")

        alternate_ranks: dict[int, int | None] = {}
        owned_ids: set[int] = set()
        alternate_student_ids: dict[int, str] = {}
        existing_values: Mapping[str, Any] = {}
        if profile_id:
            for existing in self.repository.get_state(profile_id).get("students", []):
                try:
                    record = student_stat_record(existing["student_id"], catalog=self.catalog)
                except (KeyError, TypeError, ValueError):
                    continue
                owned_ids.add(record.schaledb_id)
                if existing.get("student_id") == student_id:
                    candidate_existing = existing.get("values")
                    if isinstance(candidate_existing, Mapping):
                        existing_values = candidate_existing
                if record.schaledb_id in student.relationship.alternate_ids:
                    alternate_ranks[record.schaledb_id] = existing.get("values", {}).get("bond_rank")
                    alternate_student_ids[record.schaledb_id] = str(existing.get("student_id") or "")
        for override_id, override_rank in (relationship_ranks or {}).items():
            if (
                isinstance(override_id, int)
                and override_id in student.relationship.alternate_ids
                and isinstance(override_rank, int)
                and not isinstance(override_rank, bool)
                and 1 <= override_rank <= 100
            ):
                alternate_ranks[override_id] = override_rank
                owned_ids.add(override_id)
        for alternate_id in student.relationship.alternate_ids:
            alternate_ranks.setdefault(alternate_id, None)
        unowned = frozenset(set(student.relationship.alternate_ids) - owned_ids) if profile_id else frozenset()

        weapon = None
        if values.get("weapon_state") == "weapon_equipped":
            if isinstance(values.get("weapon_star"), int) and isinstance(values.get("weapon_level"), int):
                weapon = UniqueWeaponLevelV1(values["weapon_star"], values["weapon_level"])
        build = StudentStatBuildV1(
            level=level, star=star, equipment=tuple(equipment),
            relationship=RelationshipLevelsV1(rank, alternate_ranks, unowned),
            weapon=weapon, favorite_gear_tier=self._tier(values.get("equip4")) or 0,
            potential=PotentialLevelsV1(
                max_hp=values.get("stat_hp")
                if isinstance(values.get("stat_hp"), int)
                else existing_values.get("stat_hp") or 0,
                attack=values.get("stat_atk")
                if isinstance(values.get("stat_atk"), int)
                else existing_values.get("stat_atk") or 0,
                heal=values.get("stat_heal")
                if isinstance(values.get("stat_heal"), int)
                else existing_values.get("stat_heal") or 0,
            ),
            passive_skill_level=passive_skill_level if star >= 2 else None,
        )
        try:
            # The four values shown on Basic Info exclude passive-skill buffs.
            result = calculate_student_stats(
                student,
                build,
                self.catalog,
                include_skill_buffs=False,
            )
        except ValueError as exc:
            details["suggestion"] = {"action": "review_candidate", "reason": str(exc)}
            return self._evidence("suspicious", details, str(exc))
        details["dependencies"].extend(asdict(item) for item in result.missing_dependencies)
        details["contributions"] = {
            name: asdict(modifier) for name, modifier in result.contributions.items()
        }
        relationship_rows = [{
            "kind": "current",
            "student_id": student_id,
            "schaledb_id": student.schaledb_id,
            "rank": rank,
            "owned": True,
            "applied": rank is not None,
            "modifier": asdict(result.contributions.get(
                f"relationship_current_{student.schaledb_id}"
            )) if f"relationship_current_{student.schaledb_id}" in result.contributions else None,
        }]
        for alternate_id in student.relationship.alternate_ids:
            contribution_key = f"relationship_alternate_{alternate_id}"
            relationship_rows.append({
                "kind": "alternate",
                "student_id": alternate_student_ids.get(alternate_id),
                "schaledb_id": alternate_id,
                "rank": alternate_ranks.get(alternate_id),
                "owned": alternate_id in owned_ids,
                "applied": contribution_key in result.contributions,
                "modifier": asdict(result.contributions[contribution_key])
                if contribution_key in result.contributions else None,
            })
        details["relationship_contributions"] = relationship_rows
        details["observed"] = {
            stat: values[field] for stat, field in STAT_FIELDS.items()
            if isinstance(values.get(field), int)
        }
        if result.values is None:
            details["expected"] = result.partial_values
            details["suggestion"] = {"action": "provide_alternate_relationship_ranks"}
            return self._evidence("dependency_missing", details, "alternate relationship rank is missing")
        details["expected"] = result.values
        details["delta"] = {
            stat: details["observed"][stat] - expected
            for stat, expected in result.values.items() if stat in details["observed"]
        }
        if len(details["observed"]) != len(STAT_FIELDS):
            return self._evidence("partial", details, "observed combat stats are incomplete")
        if any(details["delta"].values()):
            details["suggestion"] = {"action": "review_candidate", "reason": "calculated stats differ"}
            return self._evidence("suspicious", details, "calculated stats differ from the screen")
        return self._evidence("verified", details, "calculated stats match the screen")

    @staticmethod
    def _evidence(status: str, details: dict[str, Any], note: str) -> dict[str, Any]:
        details["validation_status"] = status
        return {
            "field": "student_stat_validation", "status": status,
            "source": "student_stats_v1", "confidence": 1.0 if status == "verified" else 0.0,
            "note": note, "details": details,
        }

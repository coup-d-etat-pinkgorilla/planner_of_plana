from __future__ import annotations

from dataclasses import asdict
from typing import Any, Mapping

from core.student_stats import calculate_student_stats
from core.student_stats_catalog import load_student_stat_catalog, student_stat_record
from core.student_stats_types import (
    EquipmentAbsentV1, EquipmentLevelV1, PotentialLevelsV1, RelationshipLevelsV1,
    StudentStatBuildV1, UniqueWeaponLevelV1,
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
        provenance = payload.get("provenance", {})
        if isinstance(provenance, Mapping) and provenance.get("student_star") == "panel_value_conflict":
            details["dependencies"].append({"kind": "candidate_field", "key": "student_star"})
            return self._evidence("partial", details, "student star observations conflict; review required")
        for key, value in (("bond_rank", rank), ("level", level), ("student_star", star)):
            if not isinstance(value, int) or isinstance(value, bool):
                details["dependencies"].append({"kind": "candidate_field", "key": key})
        passive_skill_level = values.get("skill2")
        if isinstance(provenance, Mapping) and provenance.get("skill2") == "panel_value_conflict":
            details["dependencies"].append({"kind":"candidate_field","key":"skill2"})
            return self._evidence("partial",details,"passive skill observations conflict; review required")
        equipment: list[EquipmentLevelV1 | EquipmentAbsentV1 | None] = []
        for slot in range(1, 4):
            equipment_value = values.get(f"equip{slot}")
            tier = self._tier(equipment_value)
            equip_level = values.get(f"equip{slot}_level")
            if equipment_value in {"empty", "locked", "level_locked"}:
                equipment.append(EquipmentAbsentV1())
            elif tier is None or not isinstance(equip_level, int):
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
        weapon_state = values.get("weapon_state")
        weapon_dependencies: list[str] = []
        if star >= 5:
            if weapon_state == "weapon_equipped":
                for field in ("weapon_star", "weapon_level"):
                    value = values.get(field)
                    if not isinstance(value, int) or isinstance(value, bool):
                        weapon_dependencies.append(field)
                if not weapon_dependencies:
                    weapon = UniqueWeaponLevelV1(values["weapon_star"], values["weapon_level"])
            elif weapon_state not in {
                "no_weapon_system", "weapon_locked", "weapon_unlocked",
                "weapon_unlocked_not_equipped",
            }:
                weapon_dependencies.append("weapon_state")
        if weapon_dependencies:
            details["dependencies"].extend(
                {"kind": "candidate_field", "key": field}
                for field in weapon_dependencies
            )
            details["suggestion"] = {"action": "provide_weapon_values"}
            return self._evidence(
                "dependency_missing",
                details,
                "exclusive weapon state or values are missing",
            )
        potential_values: dict[str, int] = {}
        missing_potential_fields: list[str] = []
        potential_is_unlocked = level >= 90 and star >= 5
        potential_sources = {}
        provenance = payload.get("provenance", {})
        if not isinstance(provenance, Mapping):
            provenance = {}
        for field in ("stat_hp", "stat_atk", "stat_heal"):
            candidate_value = values.get(field)
            existing_value = existing_values.get(field)
            conflicted = provenance.get(field) == "panel_value_conflict"
            if not potential_is_unlocked:
                potential_values[field] = 0
                potential_sources[field] = "potential_gate"
            elif type(candidate_value) is int and 0 <= candidate_value <= 25 and not conflicted:
                potential_values[field] = candidate_value
                potential_sources[field] = provenance.get(field, "candidate_value")
            elif type(existing_value) is int and 0 <= existing_value <= 25:
                potential_values[field] = existing_value
                potential_sources[field] = "profile_fallback"
                missing_potential_fields.append(field)
            else:
                potential_values[field] = 0
                potential_sources[field] = "unresolved"
                missing_potential_fields.append(field)
        details["potential_inputs"] = {
            field: {"value": potential_values[field] if potential_sources[field] != "unresolved" else None,
                    "source": potential_sources[field], "fresh": field not in missing_potential_fields}
            for field in potential_values
        }
        build = StudentStatBuildV1(
            level=level, star=star, equipment=tuple(equipment),
            relationship=RelationshipLevelsV1(rank, alternate_ranks, unowned),
            weapon=weapon, favorite_gear_tier=self._tier(values.get("equip4")) or 0,
            potential=PotentialLevelsV1(
                max_hp=potential_values["stat_hp"],
                attack=potential_values["stat_atk"],
                heal=potential_values["stat_heal"],
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
        details["dependencies"].extend(
            {"kind": "candidate_field", "key": field}
            for field in missing_potential_fields
        )
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
        if missing_potential_fields:
            details["suggestion"] = {"action": "provide_potential_levels"}
            return self._evidence(
                "dependency_missing",
                details,
                "ability release levels are missing",
            )
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

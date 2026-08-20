"""Create or reuse a persistent v7 profile for repeatable UI testing.

The tool imports one v6 account through the production read-only migration
boundary, gives the independent v7 copy a stable name, and adds eight
idempotent scenario records. It never modifies the v6 source.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from core.repository_store import JsonRepository, RepositoryError
from core.runtime_paths import resolve_repository_root, resolve_v6_root
from core.scenario_store import ScenarioStore


DEFAULT_PROFILE_NAME = "거모이는존재한다 (v7 UI 테스트)"
DEFAULT_PROFILE_KEY = "profile_dd633a06"


def _max_targets() -> dict[str, int]:
    return {
        "level": 90,
        "bond_rank": 100,
        "student_star": 5,
        "weapon_level": 60,
        "weapon_star": 4,
        "ex_skill": 5,
        "skill1": 10,
        "skill2": 10,
        "skill3": 10,
        "equip1_tier": 10,
        "equip2_tier": 10,
        "equip3_tier": 10,
        "equip1_level": 70,
        "equip2_level": 70,
        "equip3_level": 70,
        "equip4_tier": 0,
        "stat_hp": 25,
        "stat_atk": 25,
        "stat_heal": 25,
    }


def _document(name: str, phase_students: list[list[str]]) -> dict[str, Any]:
    phases: list[dict[str, Any]] = []
    for phase_index, student_ids in enumerate(phase_students, start=1):
        phases.append({
            "phase_id": f"ui-seed-phase-{phase_index}",
            "name": f"우선순위 {phase_index}",
            "stages": [
                {
                    "stage_id": f"ui-seed-{phase_index}-{stage_index}-{student_id}",
                    "student_id": student_id,
                    "name": "최대 육성",
                    "targets": _max_targets(),
                }
                for stage_index, student_id in enumerate(student_ids, start=1)
            ],
        })
    return {
        "version": 1,
        "document_id": f"ui-seed-{name}",
        "name": name,
        "kind": "scenario",
        "phases": phases,
    }


def scenario_specs() -> list[tuple[str, str, dict[str, Any]]]:
    goals = [
        "rio_battle",
        "himari_battle",
        "kurumi",
        "otogi",
        "eimi_battle",
        "toki_battle",
        "yuzu_battle",
        "toki",
        "shun_swimsuit",
    ]
    definitions = [
        ("01 단기 집중 - 리오", "한 학생 카드와 단일 페이즈 계산을 확인하는 최소 시나리오", [[goals[0]]]),
        ("02 지원진 집중", "복수 학생 초상화와 지원진 자원 합계를 확인하는 시나리오", [[goals[1], goals[2]]]),
        ("03 방어선 강화", "탱커 계열 두 학생을 함께 육성하는 비교용 시나리오", [[goals[3], goals[4]]]),
        ("04 공격대 핵심", "공격대 학생 두 명의 고비용 성장과 부족 자원을 확인하는 시나리오", [[goals[5], goals[6]]]),
        ("05 기존 전력 보강 - 토키", "이미 성장한 학생의 남은 장비·능력치 비용을 확인하는 시나리오", [[goals[7]]]),
        ("06 전체 목표 일괄", "v6에서 가져온 9개 목표를 한 페이즈에 배치한 스트레스 시나리오", [goals]),
        ("07 3단계 우선순위", "9개 목표를 세 페이즈로 나눠 병목 페이즈와 누적 소비를 확인하는 시나리오", [goals[:3], goals[3:6], goals[6:]]),
        ("08 실전 혼합 편성", "보유·미보유와 역할이 섞인 네 학생의 목록 요약을 확인하는 시나리오", [[goals[0], goals[1]], [goals[5], goals[8]]]),
    ]
    return [(name, description, _document(name, phases)) for name, description, phases in definitions]


def seed(
    storage_root: Path,
    v6_root: Path,
    *,
    profile_key: str = DEFAULT_PROFILE_KEY,
    profile_name: str = DEFAULT_PROFILE_NAME,
) -> dict[str, Any]:
    repository = JsonRepository(storage_root)
    catalog = repository.list_profiles()
    existing = next(
        (item for item in catalog["profiles"] if item["display_name"].casefold() == profile_name.casefold()),
        None,
    )
    created = existing is None
    if existing is None:
        imported = repository.import_v6_profile(str(v6_root), profile_key)
        profile = imported["profile"]
        repository.rename_profile(
            profile["profile_id"], profile_name, profile["revision"], "ui-test-profile-rename-v1",
        )
        profile_id = profile["profile_id"]
    else:
        profile_id = existing["profile_id"]

    catalog = repository.list_profiles()
    current = next(item for item in catalog["profiles"] if item["profile_id"] == profile_id)
    if catalog["selected_profile_id"] != profile_id:
        repository.select_profile(
            profile_id,
            current["revision"],
            f"ui-test-profile-select-v2-r{current['revision']}",
        )

    state = repository.get_state(profile_id)
    if len(state["students"]) < 200 or len(state["inventory"]["entries"]) < 500:
        raise RepositoryError(
            "migration_source_invalid",
            "the UI test profile does not contain the expected imported v6 data",
        )

    store = ScenarioStore(
        storage_root,
        profile_revision=lambda value: repository.get_state(value)["revision"],
        profile_state=repository.get_state,
    )
    existing_names = {item["name"] for item in store.list(profile_id)["scenarios"]}
    added: list[str] = []
    for index, (name, description, document) in enumerate(scenario_specs(), start=1):
        if name in existing_names:
            continue
        collection = store.list(profile_id)
        store.create(
            profile_id,
            collection["revision"],
            f"ui-test-scenario-v1-{index}",
            name,
            description,
            state["revision"],
            document,
        )
        added.append(name)

    final = store.list(profile_id)
    seeded_names = {name for name, _description, _document_value in scenario_specs()}
    return {
        "profile_id": profile_id,
        "profile_name": profile_name,
        "created": created,
        "student_count": len(state["students"]),
        "inventory_count": len(state["inventory"]["entries"]),
        "goal_count": len(state["goals"]["goals"]),
        "scenario_count": len([item for item in final["scenarios"] if item["name"] in seeded_names]),
        "added_scenarios": added,
        "selected": repository.list_profiles()["selected_profile_id"] == profile_id,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--storage-root", type=Path, default=resolve_repository_root())
    parser.add_argument("--v6-root", type=Path, default=resolve_v6_root())
    parser.add_argument("--profile-key", default=DEFAULT_PROFILE_KEY)
    parser.add_argument("--profile-name", default=DEFAULT_PROFILE_NAME)
    args = parser.parse_args()
    result = seed(
        args.storage_root,
        args.v6_root,
        profile_key=args.profile_key,
        profile_name=args.profile_name,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

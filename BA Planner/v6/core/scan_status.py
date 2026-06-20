"""
Plana-style status events for the student scanning workflow.
"""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any


class _SafeFields(dict):
    def __missing__(self, key: str) -> str:
        return "{" + key + "}"


PLANA_MESSAGES: dict[str, tuple[str, str, str]] = {
    "session.start": ("primary", "session", "학생부를 가져오는 중입니다. 잠시만 기다려 주십시오, 선생님."),
    "session.student_menu.enter": ("primary", "session", "학생 명부로 이동합니다."),
    "session.student_menu.enter_failed": ("error", "session", "오류. 학생 명부를 열지 못했습니다."),
    "session.first_student.enter": ("primary", "session", "첫 번째 학생의 기록 카드를 확인합니다."),
    "session.first_student.enter_failed": ("error", "session", "오류. 첫 번째 학생의 정보창이 확인되지 않았습니다. 스캔할 첫 번째 학생의 기본 정보 화면을 띄운 뒤 다시 시작해 주십시오."),
    "student.identify.start": ("primary", "identify", "{index}번째 학생의 신원을 확인합니다."),
    "student.identify.retry": ("warning", "identify", "오류. 학생의 사진이 잘 판별되지 않는 것 같습니다. 다시 진행합니다."),
    "student.identify.success": ("result", "identify", "확인했습니다. {student_name} 학생입니다."),
    "student.identify.failed": ("error", "identify", "오류. 학생의 신원을 확정할 수 없습니다. 연속 정리를 중단합니다."),
    "student.scan.start": ("primary", "student", "{student_name} 학생의 학생부를 정리합니다."),
    "student.scan.saved_max_skip": ("skip", "student", "판단 완료. {student_name} 학생은 기존 기록상 정리가 완료되어 있습니다."),
    "student.scan.commit": ("result", "student", "확인했습니다. {student_name} 학생의 기록을 반영했습니다."),
    "student.scan.partial_commit": ("warning", "student", "확인 필요. 일부 항목이 불명확하지만, 가능한 기록을 먼저 반영했습니다."),
    "student.scan.failed": ("error", "student", "오류. 필수 기록이 부족합니다. 이 학생의 기록은 반영하지 않겠습니다."),
    "student.loop.duplicate": ("warning", "student", "확인 필요. 같은 학생 기록이 다시 보입니다. 다음 서류로 넘기겠습니다."),
    "student.loop.seen_before": ("primary", "student", "이미 정리한 학생 기록입니다. 명부의 끝으로 판단합니다."),
    "student.loop.complete": ("result", "student", "학생부 정리를 완료했습니다. 총 {total}명입니다."),
    "navigation.next.arrow": ("detail", "navigation", "다음 학생 기록으로 넘깁니다."),
    "navigation.next.no_change": ("warning", "navigation", "확인 필요. 서류가 넘어가지 않았습니다. 다른 방법으로 넘기겠습니다."),
    "navigation.next.button_fallback": ("detail", "navigation", "화면의 이동 버튼으로 다음 기록을 요청합니다."),
    "level.start": ("primary", "level", "{student_name} 학생의 레벨 기록을 확인합니다."),
    "level.saved_max_skip": ("skip", "level", "판단 완료. 기존 기록에서 최고 레벨을 확인했습니다."),
    "level.read.ok": ("result", "level", "레벨 기록 확인. Lv.{level}입니다."),
    "level.read.failed": ("warning", "level", "확인 필요. 레벨 숫자를 확정하지 못했습니다."),
    "weapon_state.start": ("primary", "weapon_state", "{student_name} 학생의 전용무기 항목을 확인합니다."),
    "weapon_state.saved_max_skip": ("skip", "weapon_state", "판단 완료. 기존 기록에서 전용무기 정리 완료 상태를 확인했습니다."),
    "weapon_state.no_system": ("result", "weapon_state", "확인했습니다. 전용무기 항목은 아직 열려 있지 않습니다."),
    "weapon_state.unlocked_not_equipped": ("result", "weapon_state", "확인했습니다. 전용무기는 해금되어 있으나 장착 기록이 없습니다."),
    "weapon_state.equipped": ("result", "weapon_state", "확인했습니다. 전용무기 장착 기록이 있습니다."),
    "weapon_state.uncertain": ("warning", "weapon_state", "확인 필요. 전용무기 항목의 표시가 애매합니다. 추가 확인이 필요합니다."),
    "star.start": ("primary", "star", "{student_name} 학생의 성급 기록을 확인합니다."),
    "star.infer_from_weapon": ("skip", "star", "판단 완료. 전용무기 기록이 있으므로 5성으로 처리합니다."),
    "star.read.ok": ("result", "star", "성급 기록 확인. {star}성입니다."),
    "star.read.uncertain": ("warning", "star", "확인 필요. 별의 개수가 명확하지 않습니다. 기록을 주의 표시합니다."),
    "skills.start": ("primary", "skills", "{student_name} 학생의 스킬 기록을 정리합니다."),
    "skills.saved_max_skip": ("skip", "skills", "판단 완료. 기존 기록에서 스킬 성장이 완료되어 있습니다."),
    "skills.skill3.skip_star_locked": ("skip", "skills", "판단 완료. 서브 스킬은 {star}성 상태에서 아직 해금되지 않습니다."),
    "skills.summary": ("result", "skills", "스킬 기록 정리 완료. EX {ex}, 기본 {s1}, 강화 {s2}, 서브 {s3}입니다."),
    "weapon.start": ("primary", "weapon", "{student_name} 학생의 전용무기 상세 기록을 확인합니다."),
    "weapon.skip_star_locked": ("skip", "weapon", "판단 완료. {star}성 상태에서는 전용무기 상세 기록이 열리지 않습니다."),
    "weapon.skip_no_system": ("skip", "weapon", "판단 완료. 전용무기 항목이 없어 상세 확인을 생략합니다."),
    "weapon.skip_not_equipped": ("skip", "weapon", "판단 완료. 전용무기가 미장착 상태라 상세 수치를 기록하지 않습니다."),
    "weapon.skip_state_uncertain": ("warning", "weapon", "확인 필요. 전용무기 장착 표시가 불안정해 상세 확인을 생략합니다."),
    "weapon.basic_fast_success": ("result", "weapon", "기본 화면에서 전용무기를 확인했습니다. {star}성 Lv.{level}입니다."),
    "weapon.basic_fast_fallback": ("detail", "weapon", "기본 화면 판정이 불명확해 전용무기 상세 서류를 확인합니다."),
    "weapon.summary": ("result", "weapon", "전용무기 기록 정리 완료. {star}성 Lv.{level}입니다."),
    "equipment.start": ("primary", "equipment", "{student_name} 학생의 장비 기록을 정리합니다."),
    "equipment.saved_max_skip": ("skip", "equipment", "판단 완료. 기존 기록에서 장비 정리 완료 상태를 확인했습니다."),
    "equipment.favorite_saved_max_skip": ("skip", "equipment", "판단 완료. 기존 기록에서 애장품 정리 완료 상태를 확인했습니다."),
    "equipment.button.active": ("detail", "equipment", "장비 성장 서류가 열람 가능한 상태입니다."),
    "equipment.button.inactive": ("detail", "equipment", "장비 성장 서류가 비활성 상태입니다. 잠금 여부를 추가 확인합니다."),
    "equip1.empty": ("result", "equipment", "장비1 기록 확인. 미장착 상태입니다."),
    "equip1.tier.ok": ("result", "equipment", "장비1 티어 기록 확인. {tier}입니다."),
    "equip1.level.ok": ("result", "equipment", "장비1 레벨 기록 확인. Lv.{level}입니다."),
    "equip2.skip_level_locked_from_level": ("skip", "equipment", "판단 완료. 장비2는 Lv.{level} 상태에서 아직 해금되지 않습니다."),
    "equip2.button_off_empty": ("result", "equipment", "장비2 기록 확인. 장비 성장 서류가 비활성 상태이므로 미장착으로 처리합니다."),
    "equip2.slot_flag.empty": ("result", "equipment", "장비2 기록 확인. 미장착 상태입니다."),
    "equip2.slot_flag.level_locked": ("result", "equipment", "장비2 기록 확인. Lv.10 제한으로 잠겨 있습니다."),
    "equip2.tier.ok": ("result", "equipment", "장비2 티어 기록 확인. {tier}입니다."),
    "equip2.level.ok": ("result", "equipment", "장비2 레벨 기록 확인. Lv.{level}입니다."),
    "equip3.skip_level_locked_from_level": ("skip", "equipment", "판단 완료. 장비3은 Lv.{level} 상태에서 아직 해금되지 않습니다."),
    "equip3.button_off_empty": ("result", "equipment", "장비3 기록 확인. 장비 성장 서류가 비활성 상태이므로 미장착으로 처리합니다."),
    "equip3.slot_flag.empty": ("result", "equipment", "장비3 기록 확인. 미장착 상태입니다."),
    "equip3.slot_flag.level_locked": ("result", "equipment", "장비3 기록 확인. Lv.20 제한으로 잠겨 있습니다."),
    "equip3.tier.ok": ("result", "equipment", "장비3 티어 기록 확인. {tier}입니다."),
    "equip3.level.ok": ("result", "equipment", "장비3 레벨 기록 확인. Lv.{level}입니다."),
    "favorite.start": ("primary", "equipment", "{student_name} 학생의 애장품 기록을 확인합니다."),
    "favorite.unsupported": ("result", "equipment", "애장품 기록 확인. 이 학생에게는 해당 항목이 존재하지 않습니다."),
    "favorite.growth_off_dot_empty": ("result", "equipment", "애장품 기록 확인. 장착 가능한 물품이 있으나 아직 비어 있습니다."),
    "favorite.growth_on_needs_menu": ("detail", "equipment", "확인 필요. 노란 표시만으로는 애장품 상태를 확정할 수 없습니다. 상세 서류를 확인합니다."),
    "favorite.slot_flag.empty": ("result", "equipment", "애장품 기록 확인. 미장착 상태입니다."),
    "favorite.slot_flag.love_locked": ("result", "equipment", "애장품 기록 확인. 인연도 조건으로 잠겨 있습니다."),
    "favorite.slot_flag.null": ("result", "equipment", "애장품 기록 확인. 존재하지 않는 항목입니다."),
    "favorite.tier.t1": ("result", "equipment", "애장품 기록 확인. T1 장착 상태입니다."),
    "favorite.tier.t2": ("result", "equipment", "애장품 기록 확인. T2 장착 상태입니다."),
    "stats.start": ("primary", "stats", "{student_name} 학생의 능력 개방 기록을 확인합니다."),
    "stats.skip_condition": ("skip", "stats", "판단 완료. Lv.{level}, {star}성 상태에서는 능력 개방 기록을 확인하지 않습니다."),
    "stats.saved_max_skip": ("skip", "stats", "판단 완료. 기존 기록에서 능력 개방 정리 완료 상태를 확인했습니다."),
    "stats.summary": ("result", "stats", "능력 개방 기록 정리 완료. 체력 {hp}, 공격력 {atk}, 치유력 {heal}입니다."),
    "stop.requested": ("warning", "stop", "중지 요청 확인. 현재 서류를 정리한 뒤 멈추겠습니다."),
    "stop.spacebar": ("warning", "stop", "긴급 중지 신호를 확인했습니다. 작업을 중단합니다."),
    "progress.update": ("detail", "progress", "스캔 진행률을 갱신했습니다. {current}/{total}"),
    "capture.failed": ("warning", "capture", "오류. 현재 화면을 기록하지 못했습니다. 다시 확인합니다."),
    "scan.exception": ("error", "error", "오류. 학생부 정리 중 예외가 발생했습니다. {error}"),
    "summary.student.compact": ("result", "summary", "{student_name} 학생부 정리 완료. Lv.{level}, {star}성입니다."),
    "summary.student.uncertain": ("warning", "summary", "확인 필요. {student_name} 학생의 일부 기록이 불명확합니다: {fields}"),
    "summary.student.failed": ("warning", "summary", "확인 필요. {student_name} 학생의 미기록 항목이 있습니다: {fields}"),
    "summary.session.done_with_counts": ("result", "summary", "학생부 정리를 완료했습니다. 정리 {scanned}명, 생략 {skipped}명, 확인 필요 {warnings}건입니다."),
}

PLANA_EXPRESSIONS = frozenset(
    {"neutral", "working", "confirm", "thinking", "warning", "error"}
)

PLANA_EXPRESSION_BY_EVENT: dict[str, str] = {
    "session.start": "neutral",
    "student.identify.retry": "warning",
    "student.identify.failed": "error",
    "student.scan.partial_commit": "thinking",
    "student.scan.failed": "error",
    "student.loop.duplicate": "thinking",
    "student.loop.seen_before": "confirm",
    "navigation.next.no_change": "warning",
    "level.read.failed": "thinking",
    "weapon_state.uncertain": "thinking",
    "star.read.uncertain": "thinking",
    "favorite.growth_on_needs_menu": "thinking",
    "scan.exception": "error",
    "stop.requested": "warning",
    "stop.spacebar": "warning",
    "capture.failed": "warning",
    "summary.student.uncertain": "thinking",
    "summary.student.failed": "thinking",
    "summary.session.done_with_counts": "confirm",
}


def _expression_for_event(event_id: str, level: str) -> str:
    expression = PLANA_EXPRESSION_BY_EVENT.get(event_id)
    if expression:
        return expression
    if level == "error":
        return "error"
    if level == "warning":
        return "warning"
    if level in {"result", "skip"}:
        return "confirm"
    if level == "primary":
        return "working"
    return "working"


def make_status_event(
    event_id: str,
    *,
    level: str | None = None,
    message: str | None = None,
    phase: str | None = None,
    expression: str | None = None,
    technical: str | None = None,
    data: dict[str, Any] | None = None,
    **fields: Any,
) -> dict[str, Any]:
    default_level, default_phase, template = PLANA_MESSAGES.get(
        event_id,
        ("detail", "scan", message or event_id),
    )
    payload = dict(data or {})
    payload.update(fields)
    resolved_message = message or template.format_map(_SafeFields(payload))
    resolved_level = level or default_level
    resolved_expression = expression or _expression_for_event(event_id, resolved_level)
    if resolved_expression not in PLANA_EXPRESSIONS:
        resolved_expression = "neutral"
    event = {
        "ts": time.time(),
        "id": event_id,
        "level": resolved_level,
        "phase": phase or default_phase,
        "persona": "plana",
        "expression": resolved_expression,
        "message": resolved_message,
        "fields": payload,
    }
    if technical:
        event["technical"] = technical
    return event


def write_status_event(path: Path, event: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")


def reset_status_log(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("", encoding="utf-8")


def read_status_events(path: Path, offset: int = 0) -> tuple[list[dict[str, Any]], int]:
    if not path.exists():
        return [], 0
    events: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as fh:
        fh.seek(max(0, offset))
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                raw = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(raw, dict):
                events.append(raw)
        return events, fh.tell()

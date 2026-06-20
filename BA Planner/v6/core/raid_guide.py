from __future__ import annotations

import base64
import binascii
import json
import os
import re
import zlib
from dataclasses import asdict, dataclass, field, fields
from pathlib import Path
from typing import Any
from uuid import uuid4

RAID_GUIDE_DATA_VERSION = 1
RAID_GUIDE_SHARE_PREFIX = "BAPRG1:"

MODE_DECK_4_2 = "deck_4_2"
MODE_DECK_6_4 = "deck_6_4"
MODE_TOTAL_ASSAULT = "total_assault"
MODE_GRAND_ASSAULT = "grand_assault"
MODE_RESTRICTION_RELEASE = "restriction_release"

RAID_GUIDE_MODES = {
    MODE_DECK_4_2: "4:2",
    MODE_DECK_6_4: "6:4",
}

RAID_GUIDE_DIFFICULTIES = (
    "Normal",
    "Hard",
    "VeryHard",
    "Hardcore",
    "Extreme",
    "Insane",
    "Torment",
    "Lunatic",
)

RAID_BOSS_TIME_LIMIT_SECONDS = {
    "비나": 180,
    "KAITEN FX Mk.0": 180,
    "헤세드": 240,
    "시로&쿠로": 240,
    "예로니무스": 240,
    "페로로지라": 240,
    "호드": 240,
    "고즈": 240,
    "그레고리오": 240,
    "호버크래프트": 240,
    "쿠로카게": 240,
    "게부라": 240,
    "예소드": 270,
    "세트의 분노": 270,
    "호크마": 300,
    "티페레트": 300,
}

RAID_BOSS_DEFAULT_MODES = {
    "비나": MODE_DECK_4_2,
    "KAITEN FX Mk.0": MODE_DECK_4_2,
    "헤세드": MODE_DECK_4_2,
    "시로&쿠로": MODE_DECK_4_2,
    "예로니무스": MODE_DECK_4_2,
    "페로로지라": MODE_DECK_4_2,
    "호드": MODE_DECK_4_2,
    "고즈": MODE_DECK_4_2,
    "그레고리오": MODE_DECK_4_2,
    "호버크래프트": MODE_DECK_4_2,
    "쿠로카게": MODE_DECK_4_2,
    "게부라": MODE_DECK_4_2,
    "예소드": MODE_DECK_4_2,
    "세트의 분노": MODE_DECK_6_4,
    "호크마": MODE_DECK_6_4,
    "티페레트": MODE_DECK_6_4,
}

STRIKER_SLOT = "striker"
SUPPORT_SLOT = "support"

TIME_RE = re.compile(r"^\s*(?P<minute>\d+):(?P<second>\d{1,2})(?:\.(?P<fraction>\d{1,3}))?\s*$")
NUMBER_RE = re.compile(r"^\s*(?:약\s*)?(?P<number>\d+(?:\.\d+)?)\s*(?:코|cost)?\s*$", re.IGNORECASE)

TRIGGER_WORDS = (
    "AUTO",
    "auto",
    "즉시",
    "코감",
    "페이즈",
    "2페",
    "1페",
    "사망",
    "퇴각",
    "이동",
    "넘어",
)
NOTE_WORDS = (
    "전투종료",
    "전투 종료",
    "최종점수",
    "최종 점수",
    "점수",
)


@dataclass(slots=True)
class GuideDeckSlot:
    slot_type: str
    slot_index: int
    student_id: str = ""
    alias: str = ""
    is_borrowed: bool = False
    first_order: int = 0
    star_conditions: dict[str, int] = field(default_factory=dict)
    skill_conditions: dict[str, int] = field(default_factory=dict)
    equipment_conditions: dict[str, int] = field(default_factory=dict)
    stat_conditions: dict[str, int] = field(default_factory=dict)
    notes: str = ""


@dataclass(slots=True)
class TimelineStep:
    order: int
    cue_kind: str = "note"
    cue_text: str = ""
    time_ms: int | None = None
    precision: str = ""
    cost_value: float | None = None
    actor_slot: str = ""
    actor_student_id: str = ""
    action_type: str = "EX"
    target_slot: str = ""
    target_student_id: str = ""
    condition: str = ""
    note: str = ""
    damage_check: str = ""
    phase: str = ""
    card_hint: str = ""


@dataclass(slots=True)
class RaidGuide:
    id: str
    title: str = ""
    mode: str = MODE_DECK_4_2
    boss: str = ""
    difficulty: str = ""
    terrain: str = ""
    time_limit_seconds: int = 240
    notes: str = ""
    deck: list[GuideDeckSlot] = field(default_factory=list)
    timeline: list[TimelineStep] = field(default_factory=list)


@dataclass(slots=True)
class RaidGuideData:
    version: int = RAID_GUIDE_DATA_VERSION
    guides: list[RaidGuide] = field(default_factory=list)


def normalize_raid_guide_mode(mode: str) -> str:
    if mode in {MODE_RESTRICTION_RELEASE, MODE_DECK_6_4}:
        return MODE_DECK_6_4
    return MODE_DECK_4_2


def slot_counts_for_mode(mode: str) -> tuple[int, int]:
    if normalize_raid_guide_mode(mode) == MODE_DECK_6_4:
        return 6, 4
    return 4, 2


def default_deck_for_mode(mode: str) -> list[GuideDeckSlot]:
    striker_count, support_count = slot_counts_for_mode(mode)
    slots = [GuideDeckSlot(STRIKER_SLOT, index + 1) for index in range(striker_count)]
    slots.extend(GuideDeckSlot(SUPPORT_SLOT, index + 1) for index in range(support_count))
    return slots


def new_raid_guide(title: str = "", mode: str = MODE_DECK_4_2) -> RaidGuide:
    return RaidGuide(id=uuid4().hex, title=title, mode=mode, deck=default_deck_for_mode(mode))


def _valid_fields(dataclass_type: type) -> set[str]:
    return {item.name for item in fields(dataclass_type)}


def _sanitize_int_condition_map(
    value: Any,
    *,
    allowed_keys: set[str],
    minimum: int,
    maximum: int,
    keep_zero: bool = False,
) -> dict[str, int]:
    if not isinstance(value, dict):
        return {}
    result: dict[str, int] = {}
    for key, raw in value.items():
        key_text = str(key or "")
        if key_text not in allowed_keys:
            continue
        try:
            number = int(raw or 0)
        except (TypeError, ValueError):
            number = 0
        number = max(minimum, min(maximum, number))
        if number > 0 or keep_zero:
            result[key_text] = number
    return result


def sanitize_deck_slots(mode: str, slots: list[GuideDeckSlot] | list[dict[str, Any]] | None) -> list[GuideDeckSlot]:
    incoming: dict[tuple[str, int], GuideDeckSlot] = {}
    valid_fields = _valid_fields(GuideDeckSlot)
    for raw in slots or []:
        if isinstance(raw, GuideDeckSlot):
            slot = raw
        elif isinstance(raw, dict):
            filtered = {key: value for key, value in raw.items() if key in valid_fields}
            try:
                slot = GuideDeckSlot(**filtered)
            except TypeError:
                continue
        else:
            continue
        slot_type = STRIKER_SLOT if slot.slot_type == STRIKER_SLOT else SUPPORT_SLOT
        try:
            slot_index = int(slot.slot_index)
        except (TypeError, ValueError):
            continue
        try:
            first_order = max(0, int(getattr(slot, "first_order", 0) or 0))
        except (TypeError, ValueError):
            first_order = 0
        star_conditions = _sanitize_int_condition_map(
            getattr(slot, "star_conditions", {}) or {},
            allowed_keys={"star", "weapon_star", "weapon_level"},
            minimum=0,
            maximum=60,
        )
        if star_conditions.get("star", 0) > 5:
            star_conditions["star"] = 5
        if star_conditions.get("weapon_star", 0) > 4:
            star_conditions["weapon_star"] = 4
        if star_conditions.get("weapon_star", 0) > 0:
            star_conditions["star"] = max(5, star_conditions.get("star", 0))
        skill_conditions = _sanitize_int_condition_map(
            getattr(slot, "skill_conditions", {}) or {},
            allowed_keys={"ex", "basic", "enhanced", "sub"},
            minimum=0,
            maximum=10,
            keep_zero=True,
        )
        if skill_conditions.get("ex", 0) > 5:
            skill_conditions["ex"] = 5
        equipment_conditions = _sanitize_int_condition_map(
            getattr(slot, "equipment_conditions", {}) or {},
            allowed_keys={"equip1", "equip2", "equip3", "unique"},
            minimum=0,
            maximum=10,
        )
        if equipment_conditions.get("unique", 0) > 2:
            equipment_conditions["unique"] = 2
        incoming[(slot_type, slot_index)] = GuideDeckSlot(
            slot_type=slot_type,
            slot_index=slot_index,
            student_id=str(slot.student_id or "").strip(),
            alias=str(slot.alias or "").strip(),
            is_borrowed=bool(slot.is_borrowed),
            first_order=first_order,
            star_conditions=star_conditions,
            skill_conditions=skill_conditions,
            equipment_conditions=equipment_conditions,
            stat_conditions=_sanitize_int_condition_map(
                getattr(slot, "stat_conditions", {}) or {},
                allowed_keys={"hp", "atk", "heal"},
                minimum=0,
                maximum=25,
            ),
            notes=str(slot.notes or "").strip(),
        )

    result: list[GuideDeckSlot] = []
    for default_slot in default_deck_for_mode(mode):
        result.append(incoming.get((default_slot.slot_type, default_slot.slot_index), default_slot))
    return result


def parse_cue(value: object) -> tuple[str, int | None, str, float | None]:
    raw = str(value or "").strip()
    if not raw:
        return "note", None, "", None
    lines = [line.strip() for line in raw.splitlines() if line.strip()]
    if len(lines) > 1:
        primary_kind, primary_time_ms, primary_precision, primary_cost = parse_cue(lines[0])
        secondary_cost: float | None = primary_cost
        secondary_precision = primary_precision
        for line in lines[1:]:
            kind, _time_ms, precision, cost = parse_cue(line)
            if cost is not None:
                secondary_cost = cost
            if precision == "approx":
                secondary_precision = "approx"
        return primary_kind, primary_time_ms, secondary_precision, secondary_cost
    compact = raw.strip("()[] ")
    is_approx = "약" in raw or "~" in raw
    time_match = TIME_RE.match(compact)
    if time_match:
        minute = int(time_match.group("minute"))
        second = int(time_match.group("second"))
        fraction = time_match.group("fraction") or "0"
        milliseconds = int(fraction.ljust(3, "0")[:3])
        return "time", (minute * 60 + second) * 1000 + milliseconds, "approx" if is_approx else "exact", None

    number_match = NUMBER_RE.match(compact)
    if number_match:
        number = float(number_match.group("number"))
        if "." in compact and 0 <= number < 1 and "코" not in raw and "cost" not in raw.casefold() and not is_approx:
            return "time", int(round(number * 1000)), "exact", None
        return "cost", None, "approx" if is_approx else "", number

    if any(word in raw for word in NOTE_WORDS):
        return "note", None, "", None
    if any(word in raw for word in TRIGGER_WORDS):
        return "trigger", None, "", None
    return "trigger", None, "", None


def update_step_cue(step: TimelineStep, cue_text: str) -> TimelineStep:
    cue_kind, time_ms, precision, cost_value = parse_cue(cue_text)
    step.cue_text = str(cue_text or "").strip()
    step.cue_kind = cue_kind
    step.time_ms = time_ms
    step.precision = precision
    step.cost_value = cost_value
    return step


def _is_header_line(line: str) -> bool:
    normalized = re.sub(r"\s+", "", line)
    return any(token in normalized for token in ("타임라인", "사용코스트", "사용학생", "주의및참고사항"))


def _split_table_line(line: str) -> list[str]:
    if "\t" in line:
        return [cell.strip() for cell in line.split("\t")]
    cells = [cell.strip() for cell in re.split(r"\s{2,}", line)]
    return cells if len(cells) > 1 else [line.strip()]


def _looks_like_cue(line: str) -> bool:
    raw = str(line or "").strip()
    if not raw:
        return False
    cue_kind, _time_ms, _precision, _cost_value = parse_cue(raw)
    if cue_kind in {"time", "cost"}:
        return True
    return any(word in raw for word in TRIGGER_WORDS)


def parse_timeline_text(text: str, *, start_order: int = 1) -> list[TimelineStep]:
    lines = [line.strip() for line in str(text or "").replace("\r\n", "\n").replace("\r", "\n").split("\n")]
    lines = [line for line in lines if line]
    steps: list[TimelineStep] = []
    order = start_order
    index = 0
    while index < len(lines):
        line = lines[index]
        index += 1
        if _is_header_line(line):
            continue

        cells = _split_table_line(line)
        if len(cells) >= 2:
            cue_text = cells[0]
            actor = cells[1]
            note = " ".join(cell for cell in cells[2:] if cell)
            step = update_step_cue(TimelineStep(order=order), cue_text)
            step.actor_student_id = actor
            step.note = note
            steps.append(step)
            order += 1
            continue

        cue_text = line
        if _looks_like_cue(line):
            if index < len(lines) and lines[index].startswith("("):
                cue_text = f"{cue_text}\n{lines[index]}"
                index += 1
            actor = ""
            note = ""
            if index < len(lines) and not _looks_like_cue(lines[index]) and not _is_header_line(lines[index]):
                candidate = lines[index]
                if len(candidate) <= 40 and not any(word in candidate for word in NOTE_WORDS):
                    actor = candidate
                    index += 1
                else:
                    note = candidate
                    index += 1
            step = update_step_cue(TimelineStep(order=order), cue_text)
            step.actor_student_id = actor
            step.note = note
        else:
            step = TimelineStep(order=order, cue_kind="note", cue_text="", note=line)
        steps.append(step)
        order += 1
    return steps


def sanitize_timeline(steps: list[TimelineStep] | list[dict[str, Any]] | None) -> list[TimelineStep]:
    valid_fields = _valid_fields(TimelineStep)
    result: list[TimelineStep] = []
    for index, raw in enumerate(steps or [], start=1):
        if isinstance(raw, TimelineStep):
            step = raw
        elif isinstance(raw, dict):
            filtered = {key: value for key, value in raw.items() if key in valid_fields}
            try:
                step = TimelineStep(**filtered)
            except TypeError:
                continue
        else:
            continue
        step.order = index
        update_step_cue(step, step.cue_text)
        result.append(step)
    return result


def sanitize_guide(guide: RaidGuide | dict[str, Any]) -> RaidGuide:
    if isinstance(guide, RaidGuide):
        result = guide
    else:
        valid_fields = _valid_fields(RaidGuide)
        filtered = {key: value for key, value in guide.items() if key in valid_fields}
        filtered.setdefault("id", uuid4().hex)
        result = RaidGuide(**filtered)
    result.mode = normalize_raid_guide_mode(result.mode)
    result.title = str(result.title or "").strip()
    try:
        result.time_limit_seconds = max(0, int(result.time_limit_seconds or 0))
    except (TypeError, ValueError):
        result.time_limit_seconds = 240
    result.deck = sanitize_deck_slots(result.mode, result.deck)
    result.timeline = sanitize_timeline(result.timeline)
    return result


def load_raid_guides(path: Path) -> RaidGuideData:
    if not path.exists():
        return RaidGuideData()
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return RaidGuideData()
    guides = [sanitize_guide(raw) for raw in payload.get("guides", []) if isinstance(raw, dict)]
    return RaidGuideData(version=int(payload.get("version", RAID_GUIDE_DATA_VERSION)), guides=guides)


def save_raid_guides(path: Path, data: RaidGuideData) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "version": data.version,
        "guides": [asdict(sanitize_guide(guide)) for guide in data.guides],
    }
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, path)


def encode_raid_guide_share(guide: RaidGuide | dict[str, Any]) -> str:
    payload = {
        "kind": "raid_guide",
        "version": RAID_GUIDE_DATA_VERSION,
        "assets": "external",
        "guide": asdict(sanitize_guide(guide)),
    }
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    compressed = zlib.compress(raw, level=9)
    token = base64.urlsafe_b64encode(compressed).decode("ascii").rstrip("=")
    return RAID_GUIDE_SHARE_PREFIX + token


def decode_raid_guide_share(value: str, *, regenerate_id: bool = True) -> RaidGuide:
    raw_value = str(value or "").strip()
    if not raw_value:
        raise ValueError("empty raid guide share string")
    match = re.search(re.escape(RAID_GUIDE_SHARE_PREFIX) + r"\s*([A-Za-z0-9_-]+)", raw_value)
    raw_value = match.group(1) if match else "".join(raw_value.split())
    padding = "=" * (-len(raw_value) % 4)
    try:
        compressed = base64.urlsafe_b64decode((raw_value + padding).encode("ascii"))
        payload = json.loads(zlib.decompress(compressed).decode("utf-8"))
    except (binascii.Error, UnicodeEncodeError, UnicodeDecodeError, zlib.error, json.JSONDecodeError) as exc:
        raise ValueError("invalid raid guide share string") from exc
    if not isinstance(payload, dict) or payload.get("kind") != "raid_guide":
        raise ValueError("share string is not a raid guide")
    guide_payload = payload.get("guide")
    if not isinstance(guide_payload, dict):
        raise ValueError("share string does not contain a raid guide")
    if regenerate_id:
        guide_payload = dict(guide_payload)
        guide_payload["id"] = uuid4().hex
    return sanitize_guide(guide_payload)


def clone_guide(guide: RaidGuide) -> RaidGuide:
    payload = asdict(sanitize_guide(guide))
    payload["id"] = uuid4().hex
    payload["title"] = f"{payload.get('title') or '공략'} Copy"
    return sanitize_guide(payload)


def validate_guide(guide: RaidGuide, *, known_student_ids: set[str] | None = None) -> list[str]:
    guide = sanitize_guide(guide)
    warnings: list[str] = []
    striker_count, support_count = slot_counts_for_mode(guide.mode)
    if sum(1 for slot in guide.deck if slot.slot_type == STRIKER_SLOT) > striker_count:
        warnings.append("스트라이커 슬롯 수가 모드 제한을 넘었습니다.")
    if sum(1 for slot in guide.deck if slot.slot_type == SUPPORT_SLOT) > support_count:
        warnings.append("스페셜 슬롯 수가 모드 제한을 넘었습니다.")

    deck_ids = {slot.student_id for slot in guide.deck if slot.student_id}
    first_orders: dict[int, str] = {}
    for slot in guide.deck:
        if slot.first_order <= 0:
            continue
        label = f"{slot.slot_type}{slot.slot_index}"
        if slot.first_order in first_orders:
            warnings.append(f"첫 사용 순서 {slot.first_order}이(가) {first_orders[slot.first_order]}와 {label}에 중복 지정되어 있습니다.")
        else:
            first_orders[slot.first_order] = label
    previous_actor = ""
    for step in guide.timeline:
        actor_id = step.actor_student_id.strip()
        if actor_id and actor_id not in deck_ids:
            if known_student_ids is None or actor_id not in known_student_ids:
                warnings.append(f"{step.order}행: 덱에 없는 학생/이름 '{actor_id}'가 사용 학생으로 적혀 있습니다.")
            else:
                warnings.append(f"{step.order}행: '{actor_id}'는 학생 목록에는 있지만 현재 덱에 없습니다.")
        if step.time_ms is not None and guide.time_limit_seconds and step.time_ms > guide.time_limit_seconds * 1000:
            warnings.append(f"{step.order}행: 제한시간보다 뒤의 시점입니다.")
        if actor_id and actor_id == previous_actor:
            warnings.append(f"{step.order}행: 같은 학생을 연속 사용합니다. 의도한 연속 사용이면 카드 힌트에 적어두세요.")
        if actor_id:
            previous_actor = actor_id
    return warnings

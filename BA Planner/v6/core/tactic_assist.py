from __future__ import annotations

import random
from dataclasses import dataclass, field
from pathlib import Path
from time import monotonic
from typing import Protocol

from core.raid_guide import RaidGuide, TimelineStep, sanitize_guide, slot_counts_for_mode

CARD_MODEL_DETERMINISTIC = "deterministic"
CARD_MODEL_LEGACY_RANDOM = "legacy_random"
UNKNOWN_CARD_ID = "__unknown__"


@dataclass(slots=True)
class BattleReadout:
    cost: float | None = None
    remaining_ms: int | None = None
    confidence: float = 0.0
    source: str = ""
    message: str = ""


class BattleStateReader(Protocol):
    def read(self) -> BattleReadout:
        ...


class NullBattleStateReader:
    def read(self) -> BattleReadout:
        return BattleReadout(source="manual", message="battle templates are not configured")


@dataclass(slots=True)
class AssistAction:
    step: TimelineStep
    actor_label: str
    target_label: str = ""
    ready: bool = False
    blocked_reason: str = ""


@dataclass(slots=True)
class AssistSnapshot:
    title: str
    progress: str
    current: AssistAction | None
    hand_ids: list[str] = field(default_factory=list)
    upcoming: list[AssistAction] = field(default_factory=list)
    hand: list[str] = field(default_factory=list)
    used_ids: list[str] = field(default_factory=list)
    used: list[str] = field(default_factory=list)
    queue_ids: list[str] = field(default_factory=list)
    queue: list[str] = field(default_factory=list)
    cost: float | None = None
    remaining_ms: int | None = None
    status: str = ""
    retry_armed: bool = False
    completed: bool = False
    card_model: str = CARD_MODEL_DETERMINISTIC


def is_unknown_card(student_id: str) -> bool:
    return str(student_id or "") == UNKNOWN_CARD_ID


def format_time_ms(value: int | None) -> str:
    if value is None:
        return "--:--"
    value = max(0, int(value))
    minutes, remainder = divmod(value, 60_000)
    seconds = remainder // 1000
    return f"{minutes}:{seconds:02d}"


def _student_label(guide: RaidGuide, student_id: str) -> str:
    student_id = str(student_id or "").strip()
    if not student_id:
        return ""
    if is_unknown_card(student_id):
        return "Unknown"
    for slot in guide.deck:
        if slot.student_id == student_id:
            return slot.alias or student_id
    return student_id


def _deck_student_ids(guide: RaidGuide) -> list[str]:
    result: list[str] = []
    for slot in guide.deck:
        if slot.student_id and slot.student_id not in result:
            result.append(slot.student_id)
    return result


def _hand_size_for_guide(guide: RaidGuide) -> int:
    striker_count, support_count = slot_counts_for_mode(guide.mode)
    return 5 if striker_count >= 6 or support_count >= 4 else 3


def _first_hand(guide: RaidGuide, *, card_model: str = CARD_MODEL_DETERMINISTIC) -> list[str]:
    return _initial_card_state(guide, card_model=card_model)[0]


def _slot_priority(slot) -> tuple[int, int]:
    return (0 if str(slot.slot_type or "") == "striker" else 1, int(slot.slot_index or 0))


def _initial_card_state(
    guide: RaidGuide,
    *,
    card_model: str = CARD_MODEL_DETERMINISTIC,
) -> tuple[list[str], list[str]]:
    deck_ids = _deck_student_ids(guide)
    hand_size = _hand_size_for_guide(guide)
    ordered = [
        (slot.first_order, slot.student_id)
        for slot in guide.deck
        if int(getattr(slot, "first_order", 0) or 0) > 0 and slot.student_id
    ]
    if card_model == CARD_MODEL_LEGACY_RANDOM:
        selected_slots = [
            slot
            for slot in guide.deck
            if int(getattr(slot, "first_order", 0) or 0) > 0 and slot.student_id
        ]
        selected_slots.sort(key=_slot_priority)
        hand: list[str] = []
        for slot in selected_slots:
            if len(hand) >= hand_size:
                break
            if slot.student_id not in hand:
                hand.append(slot.student_id)
        while len(hand) < hand_size:
            hand.append(UNKNOWN_CARD_ID)
        return hand, [UNKNOWN_CARD_ID]

    ordered.sort(key=lambda item: item[0])
    ordered_ids = list(dict.fromkeys(student_id for _order, student_id in ordered))
    if ordered:
        result = ordered_ids[:hand_size]
        for student_id in deck_ids:
            if len(result) >= hand_size:
                break
            if student_id not in result:
                result.append(student_id)
        queue: list[str] = []
        for student_id in ordered_ids[hand_size:]:
            if student_id not in result and student_id not in queue:
                queue.append(student_id)
        for student_id in deck_ids:
            if student_id not in result and student_id not in queue:
                queue.append(student_id)
        return result, queue
    shuffled = list(deck_ids)
    random.shuffle(shuffled)
    return shuffled[:hand_size], shuffled[hand_size:]


class TacticAssistSession:
    def __init__(
        self,
        guide: RaidGuide,
        reader: BattleStateReader | None = None,
        *,
        card_model: str = CARD_MODEL_DETERMINISTIC,
    ) -> None:
        self.guide = sanitize_guide(guide)
        self.reader = reader or NullBattleStateReader()
        self.card_model = (
            CARD_MODEL_LEGACY_RANDOM
            if card_model == CARD_MODEL_LEGACY_RANDOM
            else CARD_MODEL_DETERMINISTIC
        )
        self.current_index = 0
        self.hand, self.draw_queue = _initial_card_state(self.guide, card_model=self.card_model)
        self.used: list[str] = []
        self.readout = BattleReadout()
        self.started_at = monotonic()
        self.last_advance_at = 0.0
        self.retry_sequence: list[int] = []
        self.status = "Ready"

    @property
    def completed(self) -> bool:
        return self.current_index >= len(self.guide.timeline)

    def reset(self, reason: str = "reset") -> None:
        self.current_index = 0
        self.hand, self.draw_queue = _initial_card_state(self.guide, card_model=self.card_model)
        self.used = []
        self.readout = BattleReadout()
        self.started_at = monotonic()
        self.last_advance_at = 0.0
        self.retry_sequence = []
        self.status = f"Reset: {reason}"

    def set_card_model(self, card_model: str) -> None:
        normalized = (
            CARD_MODEL_LEGACY_RANDOM
            if card_model == CARD_MODEL_LEGACY_RANDOM
            else CARD_MODEL_DETERMINISTIC
        )
        if normalized == self.card_model:
            return
        self.card_model = normalized
        self.reset("card model changed")

    def poll(self) -> AssistSnapshot:
        try:
            self.readout = self.reader.read()
        except Exception as exc:
            self.readout = BattleReadout(source="error", message=str(exc))
        if self.readout.message and self.readout.source != "manual":
            self.status = self.readout.message
        return self.snapshot()

    def advance_current(self, source: str = "manual") -> bool:
        action = self.current_action()
        if action is None:
            self.status = "Timeline complete"
            return False
        actor_id = action.step.actor_student_id
        if actor_id:
            self._use_student(actor_id)
        self.current_index += 1
        self.last_advance_at = monotonic()
        self.status = f"Advanced by {source}: {action.actor_label or 'marker'}"
        return True

    def skip_current(self) -> bool:
        if self.completed:
            return False
        self.current_index += 1
        self.status = "Skipped current step"
        return True

    def use_hand_slot(self, slot_index: int) -> bool:
        if slot_index < 0 or slot_index >= len(self.hand):
            self.status = f"Hand slot {slot_index + 1} is empty"
            return False
        student_id = self.hand[slot_index]
        if self.card_model == CARD_MODEL_LEGACY_RANDOM and is_unknown_card(student_id):
            expected_id = self.current_action().step.actor_student_id if self.current_action() is not None else ""
            if expected_id and expected_id not in self.hand:
                student_id = expected_id
                self.hand[slot_index] = expected_id
        label = _student_label(self.guide, student_id)
        expected = self.current_action()
        expected_id = expected.step.actor_student_id if expected is not None else ""
        self._use_student(student_id, slot_index=slot_index)
        if expected_id and expected_id == student_id:
            self.current_index += 1
            self.last_advance_at = monotonic()
            self.status = f"Hand {slot_index + 1} used: {label}"
            return True
        if expected_id:
            expected_label = _student_label(self.guide, expected_id)
            self.status = f"Hand {slot_index + 1} used: {label} (expected {expected_label})"
        else:
            self.status = f"Hand {slot_index + 1} used: {label}"
        return True

    def handle_key(self, key: int, *, escape_key: int, r_key: int, space_key: int) -> bool:
        expected = (escape_key, r_key, space_key)
        if key == expected[0]:
            self.retry_sequence = [key]
        elif self.retry_sequence == [expected[0]] and key == expected[1]:
            self.retry_sequence.append(key)
        elif self.retry_sequence == [expected[0], expected[1]] and key == expected[2]:
            self.reset("retry hotkey")
            return True
        else:
            self.retry_sequence = []
        return False

    def current_action(self) -> AssistAction | None:
        if self.completed:
            return None
        return self._action_for_step(self.guide.timeline[self.current_index])

    def snapshot(self) -> AssistSnapshot:
        current = self.current_action()
        upcoming_steps = self.guide.timeline[self.current_index + 1:self.current_index + 6]
        upcoming = [self._action_for_step(step) for step in upcoming_steps]
        title = self.guide.title or "Tactic Assist"
        return AssistSnapshot(
            title=title,
            progress=f"{min(self.current_index + 1, len(self.guide.timeline))}/{len(self.guide.timeline)}",
            current=current,
            hand_ids=list(self.hand),
            upcoming=upcoming,
            hand=[_student_label(self.guide, student_id) for student_id in self.hand],
            used_ids=list(self.used[-6:]),
            used=[_student_label(self.guide, student_id) for student_id in self.used[-6:]],
            queue_ids=list(self.draw_queue),
            queue=[_student_label(self.guide, student_id) for student_id in self.draw_queue],
            cost=self.readout.cost,
            remaining_ms=self.readout.remaining_ms,
            status=self.status,
            retry_armed=bool(self.retry_sequence),
            completed=self.completed,
            card_model=self.card_model,
        )

    def _use_student(self, student_id: str, *, slot_index: int | None = None) -> int | None:
        if slot_index is None:
            try:
                slot_index = self.hand.index(student_id)
            except ValueError:
                if self.card_model == CARD_MODEL_LEGACY_RANDOM and not is_unknown_card(student_id):
                    try:
                        slot_index = self.hand.index(UNKNOWN_CARD_ID)
                        self.hand[slot_index] = student_id
                    except ValueError:
                        slot_index = None
        self.used.append(student_id)
        if self.card_model == CARD_MODEL_DETERMINISTIC:
            self.draw_queue.append(student_id)
        if slot_index is None:
            return None
        if self.card_model == CARD_MODEL_LEGACY_RANDOM:
            replacement = UNKNOWN_CARD_ID
        else:
            replacement = self.draw_queue.pop(0) if self.draw_queue else student_id
        self.hand[slot_index] = replacement
        return slot_index

    def _action_for_step(self, step: TimelineStep) -> AssistAction:
        actor = _student_label(self.guide, step.actor_student_id)
        target = _student_label(self.guide, step.target_student_id)
        ready = self._step_ready(step)
        reason = "" if ready else self._blocked_reason(step)
        return AssistAction(step=step, actor_label=actor, target_label=target, ready=ready, blocked_reason=reason)

    def _step_ready(self, step: TimelineStep) -> bool:
        if step.cost_value is not None and self.readout.cost is not None:
            return self.readout.cost + 0.01 >= float(step.cost_value)
        if step.time_ms is not None and self.readout.remaining_ms is not None:
            return self.readout.remaining_ms <= step.time_ms
        return True

    def _blocked_reason(self, step: TimelineStep) -> str:
        if step.cost_value is not None and self.readout.cost is not None:
            return f"Need {step.cost_value:g} cost"
        if step.time_ms is not None and self.readout.remaining_ms is not None:
            return f"Wait until {format_time_ms(step.time_ms)}"
        return ""


class TemplateBattleStateReader:
    def __init__(self, template_root: Path | None = None) -> None:
        self.template_root = template_root

    def read(self) -> BattleReadout:
        return BattleReadout(
            source="template",
            message="cost/time template matching regions are not configured yet",
        )

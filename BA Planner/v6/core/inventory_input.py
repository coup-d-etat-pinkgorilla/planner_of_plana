"""
Inventory-grid input backends.

The scanner should not care whether inventory cells are driven by ViGEmBus,
Steam Input, keyboard hooks, or a future game-native shortcut.  This module
keeps that decision behind a small grid-navigation interface.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Callable, Protocol

from core.gamepad_input import GamepadUnavailable, VirtualXboxController
from core.input import move_cursor_to_screen
from core.logger import LOG_INPUT, get_logger

_log = get_logger(LOG_INPUT)


class InventoryInputUnavailable(RuntimeError):
    """Raised when an inventory input backend cannot be initialized."""


class InventoryGridInput(Protocol):
    backend_name: str

    def start(self) -> None:
        ...

    def close(self) -> None:
        ...

    def move_to_slot(self, slot_index: int) -> None:
        ...

    def confirm_slot(self) -> None:
        ...

    def advance_page(self) -> None:
        ...


@dataclass(frozen=True)
class InventoryGridShape:
    cols: int
    rows: int

    @property
    def slot_count(self) -> int:
        return max(0, self.cols * self.rows)


class VConInventoryGridInput:
    """Navigate an inventory grid with a virtual Xbox controller."""

    backend_name = "vcon"

    def __init__(
        self,
        shape: InventoryGridShape,
        *,
        button_duration: float = 0.24,
        move_settle: float = 0.34,
        row_settle: float = 0.48,
        confirm_settle: float = 0.62,
        cursor_toggle_settle: float = 1.00,
        assume_initial_slot_zero: bool = True,
        cursor_anchor_screen: tuple[int, int] | None = None,
        focus_anchor: Callable[[], bool] | None = None,
    ) -> None:
        if shape.cols <= 0 or shape.rows <= 0:
            raise InventoryInputUnavailable(f"invalid inventory grid shape: {shape}")
        self.shape = shape
        self.button_duration = button_duration
        self.move_settle = move_settle
        self.row_settle = row_settle
        self.confirm_settle = confirm_settle
        self.cursor_toggle_settle = cursor_toggle_settle
        self.assume_initial_slot_zero = assume_initial_slot_zero
        self.cursor_anchor_screen = cursor_anchor_screen
        self.focus_anchor = focus_anchor
        self._controller: VirtualXboxController | None = None
        self._row = 0
        self._col = 0
        self._started = False

    def start(self) -> None:
        if self._started:
            return
        try:
            self._controller = VirtualXboxController()
        except GamepadUnavailable as exc:
            raise InventoryInputUnavailable(str(exc)) from exc
        self._started = True
        _log.debug("inventory vcon start: cols=%d rows=%d", self.shape.cols, self.shape.rows)
        if self.cursor_anchor_screen is not None:
            sx, sy = self.cursor_anchor_screen
            move_cursor_to_screen(sx, sy)
            time.sleep(0.08)
        self._pulse("left_thumb", settle=self.cursor_toggle_settle)
        if self.focus_anchor is not None:
            ok = self.focus_anchor()
            _log.debug("inventory vcon focus anchor ok=%s", ok)
            time.sleep(0.12)
        if self.assume_initial_slot_zero:
            self._row = 0
            self._col = 0
        else:
            self._home_from_current_page()

    def close(self) -> None:
        controller = self._controller
        if controller is None:
            return
        try:
            if self._started:
                try:
                    self._pulse("left_thumb", settle=0.20)
                except Exception:
                    _log.debug("inventory vcon cursor restore failed", exc_info=True)
            controller.release_all_buttons()
            controller.reset_left_stick()
        finally:
            self._controller = None
            self._started = False

    def __del__(self) -> None:
        try:
            self.close()
        except Exception:
            pass

    def _require_controller(self) -> VirtualXboxController:
        if self._controller is None:
            raise InventoryInputUnavailable("inventory input backend is not started")
        return self._controller

    def _pulse(self, button: str, *, settle: float | None = None) -> None:
        controller = self._require_controller()
        controller.pulse_button(
            button,
            duration=self.button_duration,
            settle=self.move_settle if settle is None else settle,
        )
        _log.debug("inventory vcon button: %s", button)

    def _home_from_current_page(self) -> None:
        for _ in range(max(0, self.shape.rows - 1)):
            self._pulse("dpad_up", settle=self.row_settle)
        for _ in range(max(0, self.shape.cols - 1)):
            self._pulse("dpad_left")
        self._row = 0
        self._col = 0

    def move_to_slot(self, slot_index: int) -> None:
        if slot_index < 0 or slot_index >= self.shape.slot_count:
            raise ValueError(f"slot_index out of range: {slot_index}")
        target_row = slot_index // self.shape.cols
        target_col = slot_index % self.shape.cols
        if target_row > self._row and target_col < self._col:
            # Row wrap: move back across the current item row before going down.
            # At the right edge, Blue Archive can route dpad_down to header controls.
            self._move_axis("col", target_col)
            self._move_axis("row", target_row)
        else:
            self._move_axis("row", target_row)
            self._move_axis("col", target_col)

    def _move_axis(self, axis: str, target: int) -> None:
        if axis == "row":
            current = self._row
            forward = "dpad_down"
            backward = "dpad_up"
            settle = self.row_settle
        else:
            current = self._col
            forward = "dpad_right"
            backward = "dpad_left"
            settle = self.move_settle

        delta = target - current
        button = forward if delta > 0 else backward
        for _ in range(abs(delta)):
            self._pulse(button, settle=settle)

        if axis == "row":
            self._row = target
        else:
            self._col = target

    def confirm_slot(self) -> None:
        self._pulse("a", settle=self.confirm_settle)

    def advance_page(self) -> None:
        last_slot = self.shape.slot_count - 1
        if last_slot < 0:
            return
        self.move_to_slot(last_slot)
        self._pulse("dpad_down", settle=max(self.row_settle, 0.70))
        self._row = self.shape.rows - 1
        self._col = self.shape.cols - 1


def create_inventory_input_backend(
    backend: str,
    *,
    cols: int,
    rows: int,
    cursor_anchor_screen: tuple[int, int] | None = None,
    focus_anchor: Callable[[], bool] | None = None,
) -> InventoryGridInput:
    normalized = (backend or "").strip().lower()
    if normalized in ("vcon", "virtual_controller", "virtual-controller"):
        return VConInventoryGridInput(
            InventoryGridShape(cols=cols, rows=rows),
            cursor_anchor_screen=cursor_anchor_screen,
            focus_anchor=focus_anchor,
        )
    raise InventoryInputUnavailable(f"unknown inventory input backend: {backend!r}")

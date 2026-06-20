"""
Optional virtual gamepad input helpers.

Windows does not expose a SendInput-style API for Xbox controller state. This
module uses the optional `vgamepad` package, which requires the ViGEmBus driver.
It is intentionally imported lazily so normal mouse/keyboard scanning keeps
working when virtual gamepad support is not installed.
"""

from __future__ import annotations

import importlib
import time
from dataclasses import dataclass
from enum import Enum
from types import ModuleType

from core.logger import LOG_INPUT, get_logger

_log = get_logger(LOG_INPUT)


class GamepadUnavailable(RuntimeError):
    """Raised when virtual gamepad support is not installed or cannot start."""


@dataclass(frozen=True)
class StickVector:
    x: float = 0.0
    y: float = 0.0

    def clamped(self) -> "StickVector":
        return StickVector(
            x=max(-1.0, min(1.0, float(self.x))),
            y=max(-1.0, min(1.0, float(self.y))),
        )


class GamepadButton(str, Enum):
    DPAD_UP = "dpad_up"
    DPAD_DOWN = "dpad_down"
    DPAD_LEFT = "dpad_left"
    DPAD_RIGHT = "dpad_right"
    LEFT_THUMB = "left_thumb"
    A = "a"
    B = "b"
    X = "x"
    Y = "y"


def _load_vgamepad() -> ModuleType:
    try:
        return importlib.import_module("vgamepad")
    except ImportError as exc:
        raise GamepadUnavailable(
            "Virtual gamepad input requires the optional 'vgamepad' package "
            "and the ViGEmBus driver."
        ) from exc


class VirtualXboxController:
    """Small wrapper around vgamepad's virtual Xbox 360 controller."""

    def __init__(self, *, attach_retries: int = 5, retry_delay: float = 0.35) -> None:
        vg = _load_vgamepad()
        last_exc: Exception | None = None
        for attempt in range(max(1, int(attach_retries))):
            try:
                self._gamepad = vg.VX360Gamepad()
                break
            except Exception as exc:
                last_exc = exc
                if attempt + 1 >= max(1, int(attach_retries)):
                    raise GamepadUnavailable(
                        "Failed to create a virtual Xbox controller. Check that "
                        "ViGEmBus is installed and available."
                    ) from exc
                time.sleep(max(0.0, float(retry_delay)))
        else:
            raise GamepadUnavailable(
                "Failed to create a virtual Xbox controller. Check that "
                "ViGEmBus is installed and available."
            ) from last_exc
        try:
            self._buttons = {
                GamepadButton.DPAD_UP: vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP,
                GamepadButton.DPAD_DOWN: vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN,
                GamepadButton.DPAD_LEFT: vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT,
                GamepadButton.DPAD_RIGHT: vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT,
                GamepadButton.LEFT_THUMB: vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB,
                GamepadButton.A: vg.XUSB_BUTTON.XUSB_GAMEPAD_A,
                GamepadButton.B: vg.XUSB_BUTTON.XUSB_GAMEPAD_B,
                GamepadButton.X: vg.XUSB_BUTTON.XUSB_GAMEPAD_X,
                GamepadButton.Y: vg.XUSB_BUTTON.XUSB_GAMEPAD_Y,
            }
        except Exception as exc:
            raise GamepadUnavailable(
                "Failed to create a virtual Xbox controller. Check that "
                "ViGEmBus is installed and available."
            ) from exc

    def __enter__(self) -> "VirtualXboxController":
        return self

    def __exit__(self, _exc_type, _exc, _tb) -> None:
        self.release_all_buttons()
        self.reset_left_stick()

    def set_left_stick(self, x: float = 0.0, y: float = 0.0) -> None:
        vector = StickVector(x, y).clamped()
        self._gamepad.left_joystick_float(
            x_value_float=vector.x,
            y_value_float=vector.y,
        )
        self._gamepad.update()
        _log.debug("virtual gamepad left stick x=%.3f y=%.3f", vector.x, vector.y)

    def reset_left_stick(self) -> None:
        self.set_left_stick(0.0, 0.0)

    def pulse_left_stick(
        self,
        x: float = 0.0,
        y: float = 0.0,
        *,
        duration: float = 0.35,
        settle: float = 0.10,
    ) -> None:
        self.set_left_stick(x, y)
        time.sleep(max(0.0, float(duration)))
        self.reset_left_stick()
        if settle > 0:
            time.sleep(settle)

    def _button_value(self, button: GamepadButton | str):
        try:
            key = button if isinstance(button, GamepadButton) else GamepadButton(str(button).lower())
        except ValueError as exc:
            choices = ", ".join(item.value for item in GamepadButton)
            raise ValueError(f"unknown gamepad button: {button!r} (choices: {choices})") from exc
        return self._buttons[key]

    def press_button(self, button: GamepadButton | str) -> None:
        value = self._button_value(button)
        self._gamepad.press_button(button=value)
        self._gamepad.update()
        _log.debug("virtual gamepad button down: %s", button)

    def release_button(self, button: GamepadButton | str) -> None:
        value = self._button_value(button)
        self._gamepad.release_button(button=value)
        self._gamepad.update()
        _log.debug("virtual gamepad button up: %s", button)

    def release_all_buttons(self) -> None:
        for button in GamepadButton:
            try:
                self._gamepad.release_button(button=self._buttons[button])
            except Exception:
                pass
        self._gamepad.update()

    def pulse_button(
        self,
        button: GamepadButton | str,
        *,
        duration: float = 0.08,
        settle: float = 0.12,
    ) -> None:
        self.press_button(button)
        time.sleep(max(0.0, float(duration)))
        self.release_button(button)
        if settle > 0:
            time.sleep(settle)


def pulse_left_stick(
    x: float = 0.0,
    y: float = 0.0,
    *,
    duration: float = 0.35,
    settle: float = 0.10,
) -> None:
    """Create a virtual controller, pulse its left stick, then center it."""
    with VirtualXboxController() as controller:
        controller.pulse_left_stick(x, y, duration=duration, settle=settle)


def pulse_button(
    button: GamepadButton | str,
    *,
    duration: float = 0.08,
    settle: float = 0.12,
) -> None:
    """Create a virtual controller, pulse one button, then release it."""
    with VirtualXboxController() as controller:
        controller.pulse_button(button, duration=duration, settle=settle)

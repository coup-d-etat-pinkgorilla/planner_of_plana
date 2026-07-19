"""Live Qt Quick design tokens derived from the shared UI design specification."""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QFileSystemWatcher, QObject, Property, QTimer, Signal, Slot

from gui.quick.design_registry import build_quick_component_map
from gui.ui_design_spec import UI_DESIGN_SPEC_PATH, UIDesignSpec, load_ui_design_spec


def _hex_to_rgb(color: str) -> tuple[int, int, int]:
    value = color.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def _mix_hex(color_a: str, color_b: str, amount_from_b: float) -> str:
    amount = max(0.0, min(1.0, amount_from_b))
    first = _hex_to_rgb(color_a)
    second = _hex_to_rgb(color_b)
    mixed = (
        int(round(first[index] + (second[index] - first[index]) * amount))
        for index in range(3)
    )
    return "#" + "".join(f"{channel:02x}" for channel in mixed)


def build_quick_tokens(spec: UIDesignSpec) -> dict[str, object]:
    """Translate the persisted five-color palette into semantic QML tokens."""
    palette = spec.palette
    accent = palette["accent"]
    soft = palette["soft"]
    panel = palette["panel"]
    panel_alt = palette["panel_alt"]
    text = palette["text"]
    return {
        "background": _mix_hex(panel_alt, "#090b12", 0.30),
        "backgroundAlt": panel_alt,
        "backgroundDeep": _mix_hex(panel_alt, "#000000", 0.48),
        "panel": panel,
        "panelAlt": panel_alt,
        "panelRaised": _mix_hex(panel, "#ffffff", 0.06),
        "surfaceSelected": _mix_hex(accent, panel_alt, 0.72),
        "accent": accent,
        "accentStrong": _mix_hex(accent, "#ffffff", 0.14),
        "accentSoft": _mix_hex(accent, panel_alt, 0.58),
        "accentPale": _mix_hex(soft, panel_alt, 0.55),
        "text": text,
        "muted": _mix_hex(text, panel_alt, 0.38),
        "border": _mix_hex(soft, panel_alt, 0.72),
        "shadow": _mix_hex(panel_alt, "#000000", 0.35),
        "danger": "#ef6a78",
        "warning": "#f0bd67",
        "success": "#68d0a4",
        "fontCaption": int(spec.typography["font_caption"]),
        "fontBody": int(spec.typography["font_body"]),
        "fontSection": int(spec.typography["font_section"]),
        "fontTitle": int(spec.typography["font_title"]),
    }


class QuickThemeController(QObject):
    """Expose the design specification to QML and reload it after UCS saves."""

    tokensChanged = Signal()
    componentsChanged = Signal()

    def __init__(self, path: Path = UI_DESIGN_SPEC_PATH, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._path = Path(path).resolve()
        self._tokens: dict[str, object] = {}
        self._components: dict[str, dict[str, object]] = {}
        self._watcher = QFileSystemWatcher(self)
        self._reload_timer = QTimer(self)
        self._reload_timer.setSingleShot(True)
        self._reload_timer.setInterval(80)
        self._reload_timer.timeout.connect(self.reload)
        self._watcher.fileChanged.connect(self._schedule_reload)
        self._watcher.directoryChanged.connect(self._schedule_reload)
        self.reload()

    @Property("QVariantMap", notify=tokensChanged)
    def tokens(self) -> dict[str, object]:
        return dict(self._tokens)

    @Property("QVariantMap", notify=componentsChanged)
    def components(self) -> dict[str, dict[str, object]]:
        return {key: dict(value) for key, value in self._components.items()}

    @Property(str, constant=True)
    def sourcePath(self) -> str:
        return str(self._path)

    def _refresh_watch_paths(self) -> None:
        wanted = {str(self._path.parent)}
        if self._path.exists():
            wanted.add(str(self._path))
        current = set(self._watcher.files()) | set(self._watcher.directories())
        stale = list(current - wanted)
        if stale:
            self._watcher.removePaths(stale)
        missing = list(wanted - current)
        if missing:
            self._watcher.addPaths(missing)

    @Slot()
    def _schedule_reload(self, _path: str = "") -> None:
        self._reload_timer.start()

    @Slot()
    def reload(self) -> None:
        spec = load_ui_design_spec(self._path)
        tokens = build_quick_tokens(spec)
        components = build_quick_component_map(spec)
        self._refresh_watch_paths()
        if tokens != self._tokens:
            self._tokens = tokens
            self.tokensChanged.emit()
        if components != self._components:
            self._components = components
            self.componentsChanged.emit()

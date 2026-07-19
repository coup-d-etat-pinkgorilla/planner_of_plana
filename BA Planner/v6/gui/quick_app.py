"""Entry point for the Qt Quick BA Planner presentation."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from PySide6.QtCore import QTimer, QUrl, Qt
from PySide6.QtGui import QColor, QFont, QFontDatabase, QGuiApplication
from PySide6.QtQuick import QQuickView
from PySide6.QtQml import qmlRegisterType

from gui.quick.aspect_window import AspectQuickView, fit_inside
from gui.quick.home_menu_surface_item import HomeMenuSurfaceItem
from gui.quick.models import AppController
from gui.quick.panel_surface_item import PlannerSurfaceItem
from gui.quick.theme import QuickThemeController
from gui.quick.triangle_texture_item import TriangleTextureItem


QML_ROOT = Path(__file__).resolve().parent / "quick" / "qml"
MAIN_QML = QML_ROOT / "Main.qml"
UI_FONT_PATH = Path(__file__).resolve().parent / "font" / "경기천년제목_Medium.ttf"
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

_quick_font_family: str | None = None
_quick_types_registered = False
INITIAL_WINDOW_WIDTH = 1280
INITIAL_WINDOW_HEIGHT = 720


def _initial_window_size(available_width: int, available_height: int):
    """Return a normal window size instead of filling the monitor work area."""
    return fit_inside(
        min(int(available_width), INITIAL_WINDOW_WIDTH),
        min(int(available_height), INITIAL_WINDOW_HEIGHT),
    )


def _set_view_clear_color(view: QQuickView, theme: QuickThemeController) -> None:
    """Keep the native Quick surface from flashing its default color."""
    background = QColor(str(theme.tokens.get("background") or "#171c2b"))
    if not background.isValid():
        background = QColor("#171c2b")
    view.setColor(background)


def _show_after_first_frame(view: QQuickView) -> None:
    """Expose a fully rendered scene instead of the native window's empty frame."""
    revealed = False

    def reveal() -> None:
        nonlocal revealed
        if revealed:
            return
        revealed = True
        try:
            view.frameSwapped.disconnect(reveal)
        except (RuntimeError, TypeError):
            pass
        view.setOpacity(1.0)

    view.setOpacity(0.0)
    view.frameSwapped.connect(reveal)
    view.show()
    # Some remote/offscreen renderers do not emit frameSwapped reliably.
    QTimer.singleShot(250, reveal)


def register_quick_types() -> None:
    global _quick_types_registered
    if not _quick_types_registered:
        qmlRegisterType(TriangleTextureItem, "BAPlanner", 1, 0, "TriangleTexture")
        qmlRegisterType(PlannerSurfaceItem, "BAPlanner", 1, 0, "PlannerSurface")
        qmlRegisterType(HomeMenuSurfaceItem, "BAPlanner", 1, 0, "HomeMenuSurface")
        _quick_types_registered = True


def configure_quick_application(app: QGuiApplication) -> None:
    """Install the bundled Korean UI font without importing the QWidget viewer."""
    global _quick_font_family
    if _quick_font_family is None and UI_FONT_PATH.exists():
        font_id = QFontDatabase.addApplicationFont(str(UI_FONT_PATH))
        families = QFontDatabase.applicationFontFamilies(font_id) if font_id >= 0 else []
        _quick_font_family = families[0] if families else ""
    if _quick_font_family:
        font = QFont(app.font())
        font.setFamily(_quick_font_family)
        app.setFont(font)


def create_view(
    controller: AppController | None = None,
    theme_controller: QuickThemeController | None = None,
) -> tuple[AspectQuickView, AppController]:
    app = QGuiApplication.instance()
    if app is not None:
        configure_quick_application(app)
    register_quick_types()
    resolved_controller = controller or AppController()
    resolved_theme = theme_controller or QuickThemeController()
    view = AspectQuickView()
    view._app_controller = resolved_controller  # keep the context object alive for the view lifetime
    view._quick_theme_controller = resolved_theme
    view.setTitle("Blue Archive Planner · Qt Quick")
    view.closing.connect(resolved_controller.shutdown)
    view.rootContext().setContextProperty("appController", resolved_controller)
    view.rootContext().setContextProperty("quickTheme", resolved_theme)
    _set_view_clear_color(view, resolved_theme)
    view.setSource(QUrl.fromLocalFile(str(MAIN_QML)))
    if view.status() == QQuickView.Error:
        errors = "\n".join(error.toString() for error in view.errors())
        raise RuntimeError(f"Qt Quick UI를 불러오지 못했습니다.\n{errors}")
    return view, resolved_controller


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="BA Planner Qt Quick viewer")
    parser.add_argument("--smoke-test", action="store_true", help="load QML and exit without opening a persistent window")
    return parser.parse_args(argv[1:])


def main() -> int:
    args = _parse_args(sys.argv)
    app = QGuiApplication(sys.argv[:1])
    configure_quick_application(app)
    view, controller = create_view()
    screen = view.screen() or app.primaryScreen()
    if screen is not None:
        available = screen.availableGeometry()
        initial = _initial_window_size(available.width(), available.height())
        view.setWindowState(Qt.WindowState.WindowNoState)
        view.resize(initial.width, initial.height)
        view.setPosition(
            available.x() + max(0, (available.width() - initial.width) // 2),
            available.y() + max(0, (available.height() - initial.height) // 2),
        )
    _show_after_first_frame(view)
    if args.smoke_test:
        QTimer.singleShot(50, app.quit)
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())

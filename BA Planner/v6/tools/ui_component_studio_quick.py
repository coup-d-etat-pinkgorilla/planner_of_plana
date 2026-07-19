"""Qt Quick UI Component Studio entry point without a live Planner QWidget tree."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

from gui.quick.aspect_window import AspectQuickView, fit_inside
from gui.quick.models import AppController
from gui.quick.studio_models import QuickStudioController
from gui.quick.theme import QuickThemeController
from gui.quick_app import configure_quick_application, register_quick_types

QML_PATH = ROOT / "gui" / "quick" / "qml" / "studio" / "StudioMain.qml"
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")


def create_studio_view(controller: QuickStudioController | None = None) -> tuple[AspectQuickView, QuickStudioController]:
    app = QGuiApplication.instance()
    if app is not None:
        configure_quick_application(app)
    register_quick_types()
    resolved = controller or QuickStudioController()
    preview_controller = AppController(load_data=False)
    preview_theme = QuickThemeController(resolved.spec_path)
    view = AspectQuickView()
    view._studio_controller = resolved
    view._preview_controller = preview_controller
    view._preview_theme = preview_theme
    view.setTitle("BA Planner · UI Component Studio Quick")
    view.rootContext().setContextProperty("studioController", resolved)
    view.rootContext().setContextProperty("appController", preview_controller)
    view.rootContext().setContextProperty("quickTheme", preview_theme)
    view.closing.connect(preview_controller.shutdown)
    view.setSource(QUrl.fromLocalFile(str(QML_PATH)))
    if view.status() == QQuickView.Error:
        raise RuntimeError("\n".join(error.toString() for error in view.errors()))
    return view, resolved


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke-test", action="store_true")
    args = parser.parse_args()
    app = QGuiApplication(sys.argv[:1])
    configure_quick_application(app)
    view, _controller = create_studio_view()
    screen = view.screen() or app.primaryScreen()
    if screen:
        available = screen.availableGeometry()
        initial = fit_inside(available.width(), available.height())
        view.resize(initial.width, initial.height)
    view.show()
    if args.smoke_test:
        QTimer.singleShot(50, app.quit)
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())

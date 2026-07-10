"""Public viewer façade assembled from feature components."""

from __future__ import annotations

import types

from gui import viewer_shared as _viewer_shared

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})

for _shared_value in vars(_viewer_shared).values():
    if isinstance(_shared_value, type) and _shared_value.__module__ == _viewer_shared.__name__:
        _shared_value.__module__ = __name__


def _rebind_viewer_function(function):
    rebound = types.FunctionType(
        function.__code__,
        globals(),
        function.__name__,
        function.__defaults__,
        function.__closure__,
    )
    rebound.__kwdefaults__ = function.__kwdefaults__
    rebound.__annotations__ = dict(function.__annotations__)
    rebound.__dict__.update(function.__dict__)
    rebound.__doc__ = function.__doc__
    rebound.__module__ = __name__
    rebound.__qualname__ = function.__qualname__
    return rebound


for _shared_name, _shared_value in vars(_viewer_shared).items():
    if isinstance(_shared_value, types.FunctionType) and _shared_value.__module__ == _viewer_shared.__name__:
        globals()[_shared_name] = _rebind_viewer_function(_shared_value)


from gui.viewer_components.window import ViewerWindowComponent
from gui.viewer_components.scan import ScanTabComponent
from gui.viewer_components.students import StudentsTabComponent
from gui.viewer_components.resources import ResourcesTabComponent
from gui.viewer_components.inventory import InventoryTabComponent
from gui.viewer_components.raid import RaidGuideTabComponent
from gui.viewer_components.tactical import TacticalTabComponent
from gui.viewer_components.statistics import StatisticsTabComponent
from gui.viewer_components.planner import PlannerTabComponent


class StudentViewerWindow(
        ViewerWindowComponent,
        ScanTabComponent,
        StudentsTabComponent,
        ResourcesTabComponent,
        InventoryTabComponent,
        RaidGuideTabComponent,
        TacticalTabComponent,
        StatisticsTabComponent,
        PlannerTabComponent,
        QMainWindow,
):
    """Compatibility façade composed from feature-specific viewer components."""

    pass


for _component_type in (
    ViewerWindowComponent,
    ScanTabComponent,
    StudentsTabComponent,
    ResourcesTabComponent,
    InventoryTabComponent,
    RaidGuideTabComponent,
    TacticalTabComponent,
    StatisticsTabComponent,
    PlannerTabComponent,
):
    # A few legacy static helpers refer to StudentViewerWindow by name. Publish
    # the composed façade into each component namespace after the class exists.
    sys.modules[_component_type.__module__].StudentViewerWindow = StudentViewerWindow



_QT_MESSAGE_HANDLER = None


def _install_qt_message_filter() -> None:
    global _QT_MESSAGE_HANDLER
    if _QT_MESSAGE_HANDLER is not None:
        return

    def _handler(mode: QtMsgType, context, message: str) -> None:
        if "QFont::setPointSize: Point size <= 0" in str(message or ""):
            return
        sys.stderr.write(str(message) + "\n")

    _QT_MESSAGE_HANDLER = _handler
    qInstallMessageHandler(_QT_MESSAGE_HANDLER)


_install_qt_message_filter()


def _parse_viewer_args(argv: list[str]) -> tuple[argparse.Namespace, list[str]]:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument(
        *sorted(VIEWER_STUDENT_SCAN_DEBUG_FLAGS),
        dest="student_scan_debug",
        action="store_true",
    )
    args, remaining = parser.parse_known_args(argv[1:])
    return args, [argv[0], *remaining]


def main() -> int:
    args, qt_argv = _parse_viewer_args(sys.argv)
    app = QApplication(qt_argv)
    _apply_ui_font(app)
    startup_screen = app.screenAt(QCursor.pos()) or app.primaryScreen()
    startup_geometry = startup_screen.availableGeometry() if startup_screen is not None else None
    startup_screen_geometry = startup_screen.geometry() if startup_screen is not None else None
    window = StudentViewerWindow(
        get_qt_ui_scale(app, base_width=PLANNER_BASE_WIDTH, base_height=PLANNER_BASE_HEIGHT),
        startup_geometry=startup_geometry,
        startup_screen_geometry=startup_screen_geometry,
        student_scan_debug=args.student_scan_debug,
    )
    window.show()
    return app.exec()

if __name__ == "__main__":
    raise SystemExit(main())


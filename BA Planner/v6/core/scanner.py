"""Public Scanner façade assembled from focused scan components."""

from __future__ import annotations

from core import scanner_shared as _scanner_shared

globals().update({name: value for name, value in vars(_scanner_shared).items() if not name.startswith("__")})

for _shared_value in vars(_scanner_shared).values():
    if isinstance(_shared_value, type) and _shared_value.__module__ == _scanner_shared.__name__:
        _shared_value.__module__ = __name__


from core.scanner_components.runtime import ScannerRuntimeComponent as _ScannerRuntimeComponentSource
from core.scanner_components.inventory import InventoryScannerComponent as _InventoryScannerComponentSource
from core.scanner_components.student import StudentScannerComponent as _StudentScannerComponentSource


def _rebind_scanner_function(function):
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


for _shared_name, _shared_value in vars(_scanner_shared).items():
    if isinstance(_shared_value, types.FunctionType) and _shared_value.__module__ == _scanner_shared.__name__:
        globals()[_shared_name] = _rebind_scanner_function(_shared_value)


def _bind_scanner_component(source_class):
    namespace = {}
    for name, value in vars(source_class).items():
        if name.startswith("__") and name not in {"__doc__", "__init__"}:
            continue
        if isinstance(value, staticmethod):
            namespace[name] = staticmethod(_rebind_scanner_function(value.__func__))
        elif isinstance(value, classmethod):
            namespace[name] = classmethod(_rebind_scanner_function(value.__func__))
        elif isinstance(value, property):
            namespace[name] = property(
                _rebind_scanner_function(value.fget) if value.fget else None,
                _rebind_scanner_function(value.fset) if value.fset else None,
                _rebind_scanner_function(value.fdel) if value.fdel else None,
                value.__doc__,
            )
        elif isinstance(value, types.FunctionType):
            if name == "_perf_step" and hasattr(value, "__wrapped__"):
                namespace[name] = contextmanager(_rebind_scanner_function(value.__wrapped__))
            else:
                namespace[name] = _rebind_scanner_function(value)
        else:
            namespace[name] = value
    return type(source_class.__name__, (), namespace)


ScannerRuntimeComponent = _bind_scanner_component(_ScannerRuntimeComponentSource)
InventoryScannerComponent = _bind_scanner_component(_InventoryScannerComponentSource)
StudentScannerComponent = _bind_scanner_component(_StudentScannerComponentSource)


class Scanner(ScannerRuntimeComponent, InventoryScannerComponent, StudentScannerComponent):
    """Compatibility façade composed from focused scanner components."""

    pass

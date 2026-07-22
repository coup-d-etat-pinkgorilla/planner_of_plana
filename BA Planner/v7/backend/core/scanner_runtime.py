from __future__ import annotations

from pathlib import Path

from core.recognition_assets import RecognitionAssetCatalog
from core.repository_store import JsonRepository
from core.scanner_matchers import InventoryMatcherAdapter, StudentMatcherAdapter
from core.scanner_session import ScannerSessionService
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def build_scanner_service(storage_root: Path) -> ScannerSessionService:
    catalog = RecognitionAssetCatalog()
    catalog.verify()
    windows = WindowsCaptureInputAdapter()
    return ScannerSessionService(
        target_provider=windows,
        student_matcher=StudentMatcherAdapter(windows, catalog),
        inventory_matcher=InventoryMatcherAdapter(windows, catalog),
        repository=JsonRepository(storage_root),
        asset_status=catalog.verify,
    )

from __future__ import annotations

from pathlib import Path

from core.recognition_assets import RecognitionAssetCatalog
from core.repository_store import JsonRepository
from core.scanner_matchers import InventoryMatcherAdapter, StudentMatcherAdapter
from core.scanner_session import ScannerSessionService
from core.tactical_lobby_scanner import TacticalLobbyMatcherAdapter
from core.tactical_v2 import TacticalV2Store
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def build_scanner_service(storage_root: Path) -> ScannerSessionService:
    catalog = RecognitionAssetCatalog()
    catalog.verify()
    windows = WindowsCaptureInputAdapter()
    repository = JsonRepository(storage_root)
    tactical = TacticalV2Store(storage_root, repository)
    return ScannerSessionService(
        target_provider=windows,
        student_matcher=StudentMatcherAdapter(windows, catalog),
        inventory_matcher=InventoryMatcherAdapter(windows, catalog),
        tactical_lobby_matcher=TacticalLobbyMatcherAdapter(windows, catalog),
        tactical_lobby_committer=lambda profile_id, payload, revision, key: tactical.commit_lobby(
            profile_id, payload, "", "", [], revision, key
        ),
        repository=repository,
        asset_status=catalog.verify,
    )

from __future__ import annotations

import sys
from core.application_protocol_v1 import ApplicationProtocolV1
from core.asset_preparation import AssetPreparationService, OperationGate, PreparationGuardedScanner
from core.runtime_paths import BACKEND_DIR, resolve_repository_root, resolve_extracted_asset_root
from core.scanner_runtime import build_scanner_service
from core.stdio_server import serve


def main() -> None:
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    storage_root = resolve_repository_root()
    gate = OperationGate()
    preparation = AssetPreparationService(
        storage_root=storage_root, cache_root=resolve_extracted_asset_root(), gate=gate,
        rarity_path=BACKEND_DIR/'assets/recognition/spec/item-rarity-v1.json',
        snapshot_path=BACKEND_DIR.parent/'.ba_planner_data_snapshot.json',
    )
    serve(protocol=ApplicationProtocolV1(
        storage_root=storage_root,
        scanner_service=PreparationGuardedScanner(
            build_scanner_service(storage_root, prepared_assets_loader=preparation.prepared_assets), gate),
        preparation_service=preparation,
    ))


if __name__ == "__main__":
    main()

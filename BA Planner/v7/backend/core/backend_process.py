from __future__ import annotations

import sys


def build_scanner_service(*args, **kwargs):
    # Kept as a replaceable factory for existing startup diagnostics.
    from core.scanner_runtime import build_scanner_service as build
    return build(*args, **kwargs)


def main() -> None:
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    # Complete the original-preserving copy before metadata/asset paths are bound.
    from core.user_state_migration import (
        ensure_default_user_root, UserStateMigrationError, MigrationBlockedProtocol,
    )
    try:
        ensure_default_user_root()
    except (OSError, UserStateMigrationError) as error:
        from core.stdio_server import serve
        blocked = MigrationBlockedProtocol(error)
        print('User data migration blocked: ' + blocked.details['reason'], file=sys.stderr, flush=True)
        serve(protocol=blocked)
        return
    from core.application_protocol_v1 import ApplicationProtocolV1
    from core.asset_preparation import AssetPreparationService, OperationGate, PreparationGuardedScanner
    from core.runtime_paths import BACKEND_DIR, resolve_repository_root, resolve_extracted_asset_root
    from core.stdio_server import serve
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

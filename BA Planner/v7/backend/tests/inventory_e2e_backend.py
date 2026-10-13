"""Test-only JSONL inventory matcher; no window, capture or recognition runtime."""
from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tempfile

MARKER = '.inventory-e2e-fixture.v1.json'
OWNER = {'version': 1, 'owner': 'BA Planner synthetic inventory E2E', 'case': 'fb10b-v1'}


def fixture_root(value: str | None) -> Path:
    if not value:
        raise ValueError('BA_PLANNER_STORAGE_ROOT must explicitly name a disposable ba_planner_ temporary directory')
    raw = Path(value)
    root = raw.resolve()
    if raw.is_symlink() or not root.is_relative_to(Path(tempfile.gettempdir()).resolve()) or not root.name.startswith('ba_planner_'):
        raise ValueError('Synthetic fixture storage must be a ba_planner_ directory under system Temp')
    root.mkdir(parents=True, exist_ok=True)
    marker = root / MARKER
    if marker.is_file():
        stored = json.loads(marker.read_text(encoding='utf-8'))
        if marker.is_symlink() or not isinstance(stored, dict) or type(stored.get('version')) is not int or stored != OWNER:
            raise ValueError('Fixture root marker is invalid; leave existing files intact')
    else:
        if any(root.iterdir()):
            raise ValueError('Refusing an unmarked nonempty directory; leave existing files intact')
        with marker.open('x', encoding='utf-8') as stream:
            json.dump(OWNER, stream)
    return root


def build_fixture_application(root: Path):
    root = fixture_root(str(root))
    # Import production classes only after storage has passed the fixture guard.
    from core.application_protocol_v1 import ApplicationProtocolV1
    from core.inventory_catalog import CATALOG_REVISION
    from core.repository_store import JsonRepository
    from core.scanner_session import ScannerSessionService
    fixture_path = Path(__file__).parent / 'fixtures/inventory_process_fb10b_v1.json'
    fixture = json.loads(fixture_path.read_text(encoding='utf-8'))
    if type(fixture.get('version')) is not int or fixture['version'] != 1 or fixture.get('synthetic') is not True:
        raise ValueError('Expected the pinned synthetic inventory fixture')

    def matcher(_target, _cancel, progress):
        progress(1, 1, 'fb10b_e2e_fixture')
        return [{'candidate_id': 'fb10b-e2e-candidate',
                 'payload': {'version': 1, 'catalog_revision': CATALOG_REVISION,
                             'entries': [dict(row) for row in fixture['candidate_entries']]},
                 'evidence': [], 'review_required': False}]

    scanner = ScannerSessionService(
        target_provider=lambda: [{'target_id': 'fb10b-e2e-target', 'title': 'FB10b E2E Fixture',
                                  'status': 'ready', 'foreground': False}],
        student_matcher=lambda *_: [], inventory_matcher=matcher,
        repository=JsonRepository(root),
        asset_status=lambda: {'ready': True, 'manifest_version': 1, 'asset_count': 16,
                              'missing': [], 'corrupt': []},
    )
    return ApplicationProtocolV1(storage_root=root, scanner_service=scanner, v6_root=root / 'absent-v6')


class InventoryFixtureProtocol:
    """Limit this test entry to repository/scanner; no metadata/tool side effects."""
    def __init__(self, application):
        self.application = application

    def bind_event_sink(self, sink):
        self.application.bind_event_sink(sink)

    def handle(self, message):
        from core.protocol_v1 import PlanningProtocolV1
        trusted = PlanningProtocolV1._trusted_request(message)
        if trusted is None:
            return None
        method = trusted['method']
        if not method.startswith(('repository.', 'scanner.')) or method.startswith('repository.migration.'):
            return {'protocol': 1, 'id': trusted['id'], 'type': 'response', 'method': method,
                    'payload': {'error': {'code': 'unknown_method', 'message': 'Method is outside the inventory test fixture', 'retryable': False}}}
        return self.application.handle(message)

    def close(self):
        self.application.close()


def main() -> None:
    sys.stdin.reconfigure(encoding='utf-8')
    sys.stdout.reconfigure(encoding='utf-8')
    try:
        root = fixture_root(os.environ.get('BA_PLANNER_STORAGE_ROOT'))
        application = build_fixture_application(root)
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(f'Inventory fixture refused: {error}', file=sys.stderr)
        raise SystemExit(2) from error
    from core.stdio_server import serve
    serve(protocol=InventoryFixtureProtocol(application))


if __name__ == '__main__':
    main()
